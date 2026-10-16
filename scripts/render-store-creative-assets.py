#!/usr/bin/env python3
"""Compose Apple creative assets from approved Pip art and real native captures."""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'design/app-store/creative-assets'
FONT = ROOT / 'assets/fonts/Manrope-VariableFont_wght.ttf'
PIP = ROOT / 'design/merch/pip/future-variants/pip-flixie-hoodie-perched-looking-down.png'
WATCHLIST = ROOT / 'fastlane/screenshots/en-GB/iPhone-17-Pro-Max-03-watchlist.png'
TV = ROOT / 'fastlane/screenshots/en-GB/iPhone-17-Pro-Max-07-the-newsroom.png'
BG = '#120A24'
ACCENT = '#B9A0FF'


def font(size):
    result = ImageFont.truetype(str(FONT), size)
    result.set_variation_by_axes([800])
    return result


def wordmark(canvas, x, y, size):
    draw = ImageDraw.Draw(canvas)
    face = font(size)
    draw.text((x, y), 'flix', font=face, fill='white', anchor='lt')
    draw.text((x + draw.textlength('flix', font=face), y), 'ie', font=face,
              fill='#7C4DFF', anchor='lt')


def pip(canvas, box):
    art = Image.open(PIP).convert('RGBA')
    # Crop transparent margins, preserving the original source asset.
    art = art.crop(art.getbbox())
    art.thumbnail((box[2], box[3]), Image.Resampling.LANCZOS)
    canvas.paste(art, (box[0], box[1] + box[3] - art.height), art)


def preview(canvas, source, crop, box):
    art = Image.open(source).convert('RGB').crop(crop)
    art.thumbnail((box[2], box[3]), Image.Resampling.LANCZOS)
    mask = Image.new('L', art.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, art.width - 1, art.height - 1),
                                           radius=24, fill=255)
    canvas.paste(art, (box[0], box[1]), mask)
    ImageDraw.Draw(canvas).rounded_rectangle(
        (box[0], box[1], box[0] + art.width, box[1] + art.height),
        radius=24, outline='#66517F', width=3)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--larger', action='store_true', help='Render a tighter candidate without overwriting submitted artwork')
    args = parser.parse_args()
    out = OUT / 'larger-candidate' if args.larger else OUT
    out.mkdir(parents=True, exist_ok=True)
    search = Image.new('RGB', (3840, 2560), BG)
    draw = ImageDraw.Draw(search)
    wordmark(search, 850, 720, 72)
    draw.text((850, 845), 'Find your next watch.', font=font(112), fill='white', anchor='lt')
    draw.text((850, 1000), 'Track every episode.', font=font(112), fill=ACCENT, anchor='lt')
    preview(search, WATCHLIST, (0, 190, 1320, 1990), (850, 1210, 460, 630))
    # Real Continue watching section, without fabricated UI or changed text.
    preview(search, TV, (20, 1720, 1300, 2550), (1350, 1340, 650, 420))
    pip(search, (2290, 1120, 700, 780))
    if args.larger:
        # Enlarge the whole approved composition, preserving copy and real UI.
        search = search.crop((510, 340, 3330, 2220)).resize((3840, 2560), Image.Resampling.LANCZOS)
    search.save(out / 'search-results.png')

    header = Image.new('RGB', (3840, 1646), BG)
    draw = ImageDraw.Draw(header)
    wordmark(header, 1120, 575, 86)
    draw.text((1120, 735), 'Movies, TV', font=font(126), fill='white', anchor='lt')
    draw.text((1120, 910), '& friends.', font=font(126), fill=ACCENT, anchor='lt')
    pip(header, (2170, 470, 560, 690))
    if args.larger:
        header = header.crop((760, 250, 3070, 1240)).resize((3840, 1646), Image.Resampling.LANCZOS)
    header.save(out / 'product-page-header.png')

    inputs = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in [FONT, PIP, WATCHLIST, TV, Path(__file__)]}
    images = []
    for name, size in [('search-results.png', (3840, 2560)), ('product-page-header.png', (3840, 1646))]:
        path = out / name
        with Image.open(path) as image:
            assert image.size == size and image.mode == 'RGB'
        images.append({'file': name, 'width': size[0], 'height': size[1],
                       'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    (out / 'manifest.json').write_text(json.dumps({'variant': 'larger-candidate' if args.larger else 'original', 'inputs': inputs, 'images': images}, indent=2) + '\n')
    (out / 'review.html').write_text('''<!doctype html><html lang="en-GB"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Flixie Apple creative assets</title><style>body{margin:32px;background:#120a24;color:white;font:18px system-ui}img{display:block;width:100%;max-width:1200px}a{color:#b9a0ff}h2{margin-top:48px}</style><h1>Flixie · Apple creative assets</h1><p>Real app previews with fictional accounts. Click an asset for full resolution.</p><h2>Search results · 3840 × 2560</h2><a href="search-results.png"><img src="search-results.png" alt="Find your next watch. Track every episode."></a><h2>Product page header · 3840 × 1646</h2><a href="product-page-header.png"><img src="product-page-header.png" alt="Movies, TV and friends with hoodie Pip"></a></html>''')
    print('Rendered and verified both opaque RGB Apple creative assets')

if __name__ == '__main__':
    main()
