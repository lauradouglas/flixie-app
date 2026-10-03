#!/usr/bin/env python3
"""Compose and validate store headlines while preserving native originals."""
import argparse
import hashlib
import html
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('capture', Path(__file__).with_name('store-screenshots.py'))
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def configuration():
    path = ROOT / 'fastlane/ScreenshotPresentation.json'
    config = json.loads(path.read_text())
    scenes = [entry['scene'] for entry in config['screens']]
    if len(scenes) != 8 or set(scenes) != set(capture.SCENES):
        raise ValueError('Presentation must contain each of the eight captured scenes exactly once')
    if config['locale'] != 'en-GB':
        raise ValueError('Only the English UK copy has been prepared')
    for entry in config['screens']:
        if any(len(value.splitlines()) != 2 for key, value in entry.items() if key in ('headline', 'android_headline')):
            raise ValueError('Each headline must have two lines')
    return config


def headline(screen, platform):
    return screen.get(f'{platform}_headline', screen['headline'])


def inputs(config):
    paths = [ROOT / 'fastlane/ScreenshotPresentation.json',
             ROOT / 'scripts/render-store-screenshots.swift', ROOT / config['font']]
    return {str(path.relative_to(ROOT)): digest(path) for path in paths}


def capture_manifests(platform="ios"):
    return sorted((ROOT / 'fastlane/screenshot-manifests' / platform).rglob('*.json'))


def output_directory(platform):
    return ROOT / ('fastlane/store-presentation' if platform == 'ios' else 'fastlane/store-presentation-android')


def image_directory(base, platform, locale, screenshot_type='phoneScreenshots'):
    return base / locale if platform == 'ios' else base / locale / 'images' / screenshot_type


def raw_directory(platform, locale, screenshot_type='phoneScreenshots'):
    return capture.image_directory(platform, locale, screenshot_type)


def validate(platform="ios"):
    config = configuration()
    capture.validate(platform, config['locale'])
    output = output_directory(platform)
    images_dir = image_directory(output, platform, config['locale'])
    manifest = json.loads((output / 'manifest.json').read_text())
    if manifest['inputs'] != inputs(config):
        raise ValueError(f'Presentation design changed; run {platform} prepare_screenshots again')
    expected = set()
    sources = set()
    for entry in manifest['images']:
        source = ROOT / entry['source']
        image = image_directory(output, platform, config['locale'], entry.get('screenshot_type', 'phoneScreenshots')) / entry['file']
        if Path(entry['file']).name != entry['file'] or Path(entry['source']).is_absolute():
            raise ValueError('Invalid presentation manifest path')
        if digest(source) != entry['source_sha256']:
            raise ValueError(f'Capture changed; regenerate the presentation: {source.name}')
        if digest(image) != entry['sha256']:
            raise ValueError(f'Presentation changed after generation: {image.name}')
        if capture.png_size(image) != capture.png_size(source):
            raise ValueError(f'Presentation must retain native store dimensions: {image.name}')
        if image.read_bytes()[24:29] != bytes([8, 2, 0, 0, 0]):
            raise ValueError(f'Presentation must be opaque 24-bit RGB: {image.name}')
        expected.add(str(image.relative_to(output)))
        sources.add(str(source.relative_to(ROOT)))
    native = set()
    for path in capture_manifests(platform):
        raw_manifest = json.loads(path.read_text())
        directory = raw_directory(platform, config['locale'], raw_manifest.get('screenshot_type', 'phoneScreenshots'))
        native.update(str((directory / entry['file']).relative_to(ROOT)) for entry in raw_manifest['screenshots'])
    if sources != native or len(expected) != len(native):
        raise ValueError('Presentation is incomplete or contains a stale device set')
    if expected != {str(p.relative_to(output)) for p in (output / config['locale']).rglob('*.png')}:
        raise ValueError('Presentation contains missing or unexpected PNGs')
    print(f'Validated {len(expected)} framed screenshots with current source hashes')


def prepare(platform="ios"):
    config = configuration()
    capture.validate(platform, config['locale'])
    destination = output_directory(platform)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='flixie-presentation-', dir=destination.parent) as temp:
        staging = Path(temp)
        images_dir = image_directory(staging, platform, config['locale'])
        images_dir.mkdir(parents=True)
        jobs, entries = [], []
        for manifest_path in capture_manifests(platform):
            manifest = json.loads(manifest_path.read_text())
            screenshot_type = manifest.get('screenshot_type', 'phoneScreenshots')
            images_dir = image_directory(staging, platform, config['locale'], screenshot_type)
            images_dir.mkdir(parents=True, exist_ok=True)
            scenes = {entry['scene']: entry for entry in manifest['screenshots']}
            for position, screen in enumerate(config['screens'], 1):
                entry = scenes[screen['scene']]
                source = raw_directory(platform, config['locale'], screenshot_type) / entry['file']
                filename = f"{manifest['device']}-{position:02}-{screen['scene'][3:]}.png"
                jobs.append(dict(source=str(source), output=str(images_dir / filename),
                                 headline=headline(screen, platform), width=entry['width'], height=entry['height']))
                entries.append(dict(source=str(source.relative_to(ROOT)), source_sha256=digest(source),
                                    file=filename, headline=headline(screen, platform), device=manifest['device'], screenshot_type=screenshot_type))
        plan = staging / 'render.json'
        plan.write_text(json.dumps(dict(config, font=str(ROOT / config['font']), jobs=jobs)))
        # Swift's module cache stays in build/, avoiding global development caches.
        cache = ROOT / 'build/store-screenshots/swift-cache'
        cache.mkdir(parents=True, exist_ok=True)
        subprocess.run(['xcrun', 'swift', '-module-cache-path', str(cache),
                        str(ROOT / 'scripts/render-store-screenshots.swift'), str(plan)],
                       check=True, env=dict(os.environ, CLANG_MODULE_CACHE_PATH=str(cache)))
        for entry in entries:
            image = image_directory(staging, platform, config['locale'], entry['screenshot_type']) / entry['file']
            capture.opaque_rgb_png(image)
            if capture.png_size(image) != capture.png_size(ROOT / entry['source']):
                raise ValueError('Renderer changed the canvas dimensions')
            entry['sha256'] = digest(image)
        (staging / 'manifest.json').write_text(json.dumps(dict(inputs=inputs(config), images=entries), indent=2) + '\n')
        plan.unlink()
        # Replace only generated output; original captures remain untouched.
        if destination.exists():
            shutil.rmtree(destination)
        staging.rename(destination)
    write_review(destination, config, entries, platform)
    validate(platform)


def write_review(destination, config, entries, platform):
    sections = []
    for device, screenshot_type in sorted({(entry['device'], entry.get('screenshot_type', 'phoneScreenshots')) for entry in entries}):
        figures = []
        for entry in entries:
            if entry['device'] != device or entry.get('screenshot_type', 'phoneScreenshots') != screenshot_type:
                continue
            image = str((image_directory(destination, platform, config["locale"], entry.get('screenshot_type', 'phoneScreenshots')) / entry["file"]).relative_to(destination))
            caption = html.escape(entry['headline'].replace('\n', ' '))
            figures.append(f'<figure><a href="{image}"><img src="{image}" alt="{caption}"></a><figcaption>{caption}</figcaption></figure>')
        sections.append(f'<h2>{html.escape(device + " · " + screenshot_type if platform == "android" else device)}</h2><div class="grid">{"".join(figures)}</div>')
    (destination / 'review.html').write_text('''<!doctype html><html lang="en-GB"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Flixie store presentation</title>
<style>body{margin:32px;background:#120a24;color:#fff;font-family:system-ui}h1 span{color:#7c4dff}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:24px}figure{margin:0}img{width:100%;display:block}figcaption{padding:12px 0;color:#c8bce0}a:focus-visible{outline:3px solid #b9a0ff}p{max-width:65ch;line-height:1.6}</style>
<h1>flix<span>ie</span> · Store screenshots</h1><p>Final upload order. Real app captures with fictional accounts and example activity. Click an image to inspect it at full resolution.</p>
''' + ''.join(sections) + '</html>')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=('ios', 'android'), nargs='?', default='ios')
    parser.add_argument('--validate', action='store_true')
    args = parser.parse_args()
    validate(args.platform) if args.validate else prepare(args.platform)
