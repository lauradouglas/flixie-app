#!/usr/bin/env python3
"""Decode the final video and create a contact sheet for editorial inspection."""
from pathlib import Path
import subprocess
import imageio_ffmpeg
from PIL import Image, ImageDraw

out = Path(__file__).resolve().parents[1] / 'build/launch-campaign'
video = out / 'flixie-launch.mp4'
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
subprocess.run([ffmpeg, '-v', 'error', '-i', str(video), '-f', 'null', '-'], check=True)
sheet = Image.new('RGB', (1080, 1010), '#10081e')
for index, second in enumerate([2, 6, 10, 15, 20, 24, 27, 31]):
    target = out / f'check-{second:02}.png'
    subprocess.run([ffmpeg, '-y', '-v', 'error', '-ss', str(second), '-i', str(video),
                    '-frames:v', '1', '-vf', 'scale=270:480', str(target)], check=True)
    x, y = index % 4 * 270, index // 4 * 505
    sheet.paste(Image.open(target), (x, y))
    ImageDraw.Draw(sheet).text((x + 10, y + 485), f'{second}s', fill='white')
sheet.save(out / 'contact-sheet.jpg', quality=94)
print(out / 'contact-sheet.jpg')
