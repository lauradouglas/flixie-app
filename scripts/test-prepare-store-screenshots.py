#!/usr/bin/env python3
"""Verify that stale/edited presentations cannot reach the upload lane."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

presentation = load('presentation', 'prepare-store-screenshots.py')
runner_tests = load('capture_tests', 'test-store-screenshots.py')


class PresentationTest(unittest.TestCase):
    platform = "ios"
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.old_root = presentation.ROOT
        self.old_capture_root = presentation.capture.ROOT
        presentation.ROOT = presentation.capture.ROOT = self.root = Path(self.temp.name)
        self.raw = presentation.raw_directory(self.platform, 'en-GB')
        self.output = presentation.output_directory(self.platform)
        self.images = presentation.image_directory(self.output, self.platform, 'en-GB')
        self.raw.mkdir(parents=True)
        self.images.mkdir(parents=True)
        (self.root / 'scripts').mkdir()
        (self.root / 'font.ttf').write_bytes(b'font')
        (self.root / 'scripts/render-store-screenshots.swift').write_text('renderer')
        self.config = {'locale': 'en-GB', 'font': 'font.ttf', 'screens': [
            {'scene': scene, 'headline': 'A headline\nA benefit'} for scene in presentation.capture.SCENES]}
        (self.root / 'fastlane/ScreenshotPresentation.json').write_text(json.dumps(self.config))
        images, captures = [], []
        for scene in presentation.capture.SCENES:
            name = f'iPhone-{scene}.png'
            source, target = self.raw / name, self.images / name
            source.write_bytes(self.png())
            target.write_bytes(self.png())
            captures.append(dict(scene=scene, file=name, width=320 if self.platform == "android" else 2, height=480 if self.platform == "android" else 3))
            images.append(dict(source=str(source.relative_to(self.root)), source_sha256=presentation.digest(source),
                               file=name, sha256=presentation.digest(target)))
        folder = self.root / 'fastlane/screenshot-manifests' / self.platform
        folder.mkdir(parents=True)
        (folder / 'iPhone.json').write_text(json.dumps(dict(platform=self.platform, locale='en-GB', device='iPhone', screenshots=captures)))
        (self.output / 'manifest.json').write_text(json.dumps(dict(inputs=presentation.inputs(self.config), images=images)))

    def png(self):
        return runner_tests.png(320, 480) if self.platform == "android" else runner_tests.png()

    def tearDown(self):
        presentation.ROOT, presentation.capture.ROOT = self.old_root, self.old_capture_root
        self.temp.cleanup()

    def validate(self):
        with contextlib.redirect_stdout(io.StringIO()):
            presentation.validate(self.platform)

    def test_android_copy_does_not_change_apple_copy(self):
        screen = {'headline': 'Apple\nCopy', 'android_headline': 'Android\nCopy'}
        self.assertEqual(presentation.headline(screen, 'ios'), 'Apple\nCopy')
        self.assertEqual(presentation.headline(screen, 'android'), 'Android\nCopy')

    def test_current_complete_presentation_is_uploadable(self):
        self.validate()

    def test_recapture_requires_regenerating_presentation(self):
        next(self.raw.glob('*.png')).write_bytes(self.png() + b'changed')
        with self.assertRaisesRegex(ValueError, 'Capture changed'):
            self.validate()

    def test_edited_output_is_rejected(self):
        next(self.images.glob('*.png')).write_bytes(b'edited')
        with self.assertRaisesRegex(ValueError, 'Presentation changed'):
            self.validate()

    def test_changed_headline_requires_regeneration(self):
        self.config['screens'][0]['headline'] = 'New headline\nNew benefit'
        (self.root / 'fastlane/ScreenshotPresentation.json').write_text(json.dumps(self.config))
        with self.assertRaisesRegex(ValueError, 'design changed'):
            self.validate()

    def test_duplicate_scene_is_rejected(self):
        self.config['screens'][-1] = self.config['screens'][0]
        (self.root / 'fastlane/ScreenshotPresentation.json').write_text(json.dumps(self.config))
        with self.assertRaisesRegex(ValueError, 'exactly once'):
            self.validate()

    def test_extra_output_cannot_be_accidentally_uploaded(self):
        (self.images / 'old.png').write_bytes(self.png())
        with self.assertRaisesRegex(ValueError, 'unexpected PNGs'):
            self.validate()


class AndroidPresentationTest(PresentationTest):
    platform = "android"

    def test_tablet_capture_requires_its_own_presentation(self):
        import shutil
        category = 'sevenInchScreenshots'
        tablet_raw = presentation.raw_directory('android', 'en-GB', category)
        shutil.copytree(self.raw, tablet_raw)
        folder = self.root / 'fastlane/screenshot-manifests/android'
        raw_manifest = json.loads((folder / 'iPhone.json').read_text())
        raw_manifest['screenshot_type'] = category
        (folder / category).mkdir()
        (folder / category / 'tablet.json').write_text(json.dumps(raw_manifest))
        with self.assertRaisesRegex(ValueError, 'incomplete'):
            self.validate()
        tablet_output = presentation.image_directory(self.output, 'android', 'en-GB', category)
        shutil.copytree(self.images, tablet_output)
        manifest_path = self.output / 'manifest.json'
        manifest = json.loads(manifest_path.read_text())
        tablet_images = []
        for entry in manifest['images']:
            copied = dict(entry, screenshot_type=category)
            copied['source'] = str((tablet_raw / entry['file']).relative_to(self.root))
            tablet_images.append(copied)
        manifest['images'].extend(tablet_images)
        manifest_path.write_text(json.dumps(manifest))
        self.validate()
        next(tablet_output.glob('*.png')).write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'Presentation changed'):
            self.validate()


if __name__ == '__main__':
    unittest.main()
