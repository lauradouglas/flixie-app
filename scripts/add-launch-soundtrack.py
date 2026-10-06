#!/usr/bin/env python3
"""Add the user-supplied Bensound track and visible end-card music credit."""
import subprocess
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg

root = Path(__file__).resolve().parents[1]
out = root / 'build/launch-campaign'
music = Path(sys.argv[1]).resolve()
assert music.is_file(), music
credit = Image.new('RGBA', (1080, 1920), (0, 0, 0, 0))
draw = ImageDraw.Draw(credit)
font = ImageFont.truetype(str(root / 'assets/fonts/Manrope-VariableFont_wght.ttf'), 18)
for text, y in [('Music: All That — Benjamin Tissot', 1685), ('Bensound.com', 1714)]:
    width = draw.textlength(text, font=font)
    draw.text(((1080-width)/2, y), text, font=font, fill='#C8BADF')
credit.save(out / 'music-credit.png')
ff = imageio_ffmpeg.get_ffmpeg_exe()
video = out / 'flixie-launch-all-that.mp4'
subprocess.run([
    ff, '-y', '-v', 'error', '-i', str(out / 'flixie-launch-v2-silent.mp4'),
    '-i', str(music), '-loop', '1', '-i', str(out / 'music-credit.png'),
    '-filter_complex', "[0:v][2:v]overlay=0:0:enable='gte(t,29)'[v];"
    '[1:a]atrim=duration=33,asetpts=PTS-STARTPTS,loudnorm=I=-18:TP=-1.5:LRA=9,'
    'afade=t=in:d=0.25,afade=t=out:st=31.5:d=1.5[a]',
    '-map', '[v]', '-map', '[a]', '-t', '33', '-r', '30',
    '-c:v', 'libx264', '-preset', 'fast', '-crf', '19', '-threads', '2',
    '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '192k', '-ar', '48000',
    '-metadata', 'comment=Music: All That by Benjamin Tissot / Bensound.com. See accompanying attribution file.',
    '-movflags', '+faststart', str(video)
], check=True)
subprocess.run([ff, '-v', 'error', '-i', str(video), '-f', 'null', '-'], check=True)
subprocess.run([ff, '-y', '-v', 'error', '-ss', '31', '-i', str(video),
                '-frames:v', '1', str(out / 'all-that-endcard.png')], check=True)
print(video)
