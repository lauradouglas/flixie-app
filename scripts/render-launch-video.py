#!/usr/bin/env python3
"""Compose real Patrol clips into a portrait launch campaign video."""
import json, subprocess, math, wave, array, sys, random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'build/launch-campaign';FF=imageio_ffmpeg.get_ffmpeg_exe()
FONT=str(ROOT/'assets/fonts/Manrope-VariableFont_wght.ttf')
def font(size):
 f=ImageFont.truetype(FONT,size)
 try:f.set_variation_by_name('ExtraBold')
 except Exception:pass
 return f
def center(draw,text,y,size,fill='#F7F4FF'):
 f=font(size);box=draw.textbbox((0,0),text,font=f);draw.text(((1080-(box[2]-box[0]))/2,y),text,font=f,fill=fill)
def brand(draw,y,size):
 f=ImageFont.truetype('/System/Library/Fonts/SFNS.ttf',size)
 f.set_variation_by_name('Heavy')
 spacing=-.5*size/24
 widths=[draw.textlength(c,font=f)+spacing for c in 'flixie'];x=(1080-sum(widths))/2
 for i,c in enumerate('flixie'):
  draw.text((x,y),c,font=f,fill='white' if i<4 else '#7C4DFF');x+=widths[i]
def background(index,headline,sub,closing=False):
 im=Image.new('RGB',(1080,1920));pix=im.load()
 for y in range(1920):
  glow=max(0,1-abs(y-740)/1100)
  for x in range(1080):
   g=glow*max(0,1-abs(x-540)/850);pix[x,y]=(int(15+12*g),int(8+7*g),int(30+27*g))
 d=ImageDraw.Draw(im);brand(d,72,68)
 if closing:
  brand(d,530,154)
  for j,line in enumerate(headline.split('\n')):center(d,line,820+j*100,76)
  center(d,'Download Flixie',1105,46)
  for name,y in [('app-store.png',1230),('google-play.png',1450)]:
   badge=Image.open(ROOT/'assets/marketing'/name).convert('RGBA')
   badge=badge.crop(badge.getbbox())
   badge=badge.resize((round(badge.width*160/badge.height),160),Image.Resampling.LANCZOS)
   im.paste(badge,((1080-badge.width)//2,y),badge)
 else:
  for j,line in enumerate(headline.split('\n')):center(d,line,192+j*83,70)
  center(d,sub,367,29,fill='#C8BADF')
  d.rounded_rectangle((225,450,855,1810),radius=55,fill='#100B1C',outline='#694291',width=3)
  center(d,'FLIXIE  /  '+str(index).zfill(2),1840,24,fill='#BCABD5')
  center(d,'Demo accounts and sample activity',1882,18,fill='#9586AF')
 p=OUT/f'card-{index}.png';im.save(p);return p
scenes=[
 ('01-home','Your next favourite\nstarts here.','Discover films worth saving.',4),
 ('06-interstellar','Big films.\nYour kind of story.','Explore Interstellar and more.',4),
 ('09-reviews','Find your people.\nHear their picks.','Movie reviews from your circle.',5),
 ('07-the-newsroom','One more episode?\nKeep your place.','Track the shows you love.',5),
 ('03-watchlist','Save it now.\nWatch it later.','Build a watchlist that feels like you.',4),
 ('04-watch-plan','Make a night of it.','Turn a film into a plan with friends.',4),
 ('02-profile','Your films.\nYour collection.','Keep your favourites close.',3),
]
clips=[]
for i,(name,headline,sub,duration) in enumerate(scenes,1):
 src=OUT/(name+'.mov')
 if not src.exists() and '--prepare' in sys.argv:continue
 assert src.exists(),src
 target=OUT/f'edit-{i}.mp4'
 if target.exists() and '--reuse-scenes' in sys.argv and target.stat().st_mtime > src.stat().st_mtime:
  clips.append(target);continue
 bg=background(i,headline,sub)
 subprocess.run([FF,'-y','-loglevel','error','-loop','1','-i',str(bg),'-i',str(src),'-filter_complex','[1:v]fps=30,scale=608:1320:force_original_aspect_ratio=decrease,pad=608:1320:(ow-iw)/2:(oh-ih)/2:color=0x100B1C,tpad=stop_mode=clone:stop_duration=5[v];[0:v][v]overlay=236:466:shortest=1,format=yuv420p[out]','-map','[out]','-t',str(duration),'-r','30','-c:v','libx264','-preset','fast','-crf','19','-threads','2',str(target)],check=True)
 clips.append(target)
bg=background(8,'Find. Save. Watch.\nTogether.','',True);target=OUT/'edit-8.mp4'
subprocess.run([FF,'-y','-loglevel','error','-loop','1','-i',str(bg),'-t','4','-r','30','-c:v','libx264','-pix_fmt','yuv420p','-threads','2',str(target)],check=True);clips.append(target)
if '--prepare' in sys.argv:
 print('Available scenes rendered');sys.exit(0)
listing=OUT/'concat.txt';listing.write_text(''.join("file '"+str(p)+"'\n" for p in clips))
# Original light major-key plucks and a soft rhythm, without sustained low pads.
sample_rate=44100;duration=sum(s[3] for s in scenes)+4;audio=array.array('h')
beat=60/112;chords=[(261.63,329.63,392.00),(392.00,493.88,587.33),(349.23,440.00,523.25),(261.63,329.63,392.00)]
rng=random.Random(42)
for n in range(int(duration*sample_rate)):
 t=n/sample_rate;chord=chords[int(t/(4*beat))%4];step=int(t/(beat/2));age=t%(beat/2)
 f=chord[[0,1,2,1,0,2,1,2][step%8]]
 pluck=(math.sin(2*math.pi*f*age)+.22*math.sin(4*math.pi*f*age))*math.exp(-age*14)*min(1,age/.008)
 bass_age=t%beat;bass=math.sin(2*math.pi*(chord[0]/2)*bass_age)*math.exp(-bass_age*12)*min(1,bass_age/.01)
 hat_age=(t+beat/2)%beat;hat=rng.uniform(-1,1)*math.exp(-hat_age*85)*.013
 value=.15*pluck+.065*bass+hat
 fade=min(1,t/.4,max(0,(duration-t)/1.6))
 audio.append(int(max(-1,min(1,value*fade))*32767))
with wave.open(str(OUT/'original-bed.wav'),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(sample_rate);w.writeframes(audio.tobytes())
subprocess.run([FF,'-y','-loglevel','error','-f','concat','-safe','0','-i',str(listing),'-i',str(OUT/'original-bed.wav'),'-c:v','copy','-c:a','aac','-b:a','128k','-shortest','-movflags','+faststart',str(OUT/'flixie-launch-v2.mp4')],check=True)
print(OUT/'flixie-launch-v2.mp4')
