from pathlib import Path
import subprocess, os, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parent
FF='/private/tmp/flixie-video-deps/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1'
FONT=ROOT.parents[2]/'assets/fonts/Manrope-VariableFont_wght.ttf'
# Project path is three levels above video.
FONT=Path.cwd()/'assets/fonts/Manrope-VariableFont_wght.ttf'
W,H=1080,1920
A=ROOT/'assets';A.mkdir(exist_ok=True)
def font(size,bold=False):
 f=ImageFont.truetype(str(FONT),size)
 f.set_variation_by_axes([750 if bold else 500])
 return f
def bg():
 yy,xx=np.mgrid[0:H,0:W];glow=np.exp(-((xx-900)**2/(720**2)+(yy-1150)**2/(1150**2)))
 arr=np.zeros((H,W,3),dtype=np.uint8)
 for i,(v,g) in enumerate([(13,24),(7,12),(25,49)]):arr[:,:,i]=v+glow*g
 return Image.fromarray(arr).convert('RGBA')
logo=Image.open('/Users/lauradouglas/Documents/FLIXIE/text-logos/white.png').convert('RGBA')
logo=logo.crop(logo.getbbox())
def addlogo(im,x,y,width):
 l=logo.resize((width,round(width*logo.height/logo.width)),Image.Resampling.LANCZOS);im.alpha_composite(l,(x,y))
def text(im,lines,x,y,size=82,fill='#FFF7ED',bold=True,gap=6):
 d=ImageDraw.Draw(im);f=font(size,bold)
 for line in lines.split('\n'):d.text((x,y),line,font=f,fill=fill);y+=size+gap

def card(name,headline,sub,step):
 im=bg();addlogo(im,90,65,190);text(im,headline,90,155,size=78)
 text(im,sub,92,332,size=30,fill='#BEB0D4',bold=False)
 d=ImageDraw.Draw(im)
 d.rounded_rectangle((198,378,882,1834),radius=85,fill='#08060F',outline='#57466E',width=3)
 for j in range(3):d.rounded_rectangle((420+j*85,1865,480+j*85,1870),radius=2,fill='#BFA0FF' if j==step else '#39264F')
 im.save(A/f'{name}.png')
card('discover','Find your next\nfavourite.','Discover movies and shows.',0)
card('providers','Know where\nto watch.','Stream, rent or buy. All easy to find.',1)
card('plan','Make a night\nof it.','Plan what to watch with your people.',2)
mask=Image.new('L',(660,1434));ImageDraw.Draw(mask).rounded_rectangle((0,0,659,1433),radius=72,fill=255);mask.save(A/'mask.png')
im=bg();addlogo(im,90,90,260);text(im,'What are we\nwatching\ntonight?',90,480,size=108);text(im,'Less deciding. More movie night.',95,990,size=34,fill='#C2ACED',bold=False)
ImageDraw.Draw(im).rounded_rectangle((94,1170,274,1178),radius=4,fill='#A26BFF');text(im,'Movies. Shows. Your people.',95,1690,size=30,fill='#C2ACED',bold=False);im.save(A/'intro.png')
im=bg();addlogo(im,190,510,700);text(im,'Movies. Shows.\nYour people.',120,890,size=89);text(im,'Find your next watch with Flixie.',123,1150,size=33,fill='#C2ACED',bold=False);im.save(A/'outro.png')
# Original instrumental: soft arpeggio, warm chords and a restrained pulse.
SR=44100;duration=22.8;t=np.arange(round(duration*SR))/SR;audio=np.zeros_like(t)
chords=[[220,261.63,329.63],[174.61,220,261.63],[196,246.94,293.66],[164.81,196,246.94]]
for k,start in enumerate(np.arange(0,duration,2.4)):
 tt=t-start;env=np.where(tt>=0,(1-np.exp(-np.maximum(tt,0)*3))*np.exp(-np.maximum(tt,0)/2.1),0)
 for hz in chords[k%4]:audio+=.038*env*np.sin(2*np.pi*hz*t)
for k,start in enumerate(np.arange(0,duration,.3)):
 tt=t-start;hz=chords[(k//8)%4][k%3]*2;env=np.where(tt>=0,np.exp(-np.maximum(tt,0)*6)*(1-np.exp(-np.maximum(tt,0)*80)),0)
 audio+=.075*env*(np.sin(2*np.pi*hz*tt)+.25*np.sin(2*np.pi*hz*2*tt))
for start in np.arange(0,duration,.6):
 tt=t-start;v=np.maximum(tt,0);env=np.where(tt>=0,np.exp(-v*19),0);audio+=.075*env*np.sin(2*np.pi*(52*v+2*(1-np.exp(-v*32))))
audio*=np.minimum(t/1,1)*np.minimum((duration-t)/1.5,1)
stereo=np.stack([audio,np.roll(audio,220)],axis=1)
with wave.open(str(A/'original-score.wav'),'wb') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(SR);f.writeframes((np.clip(stereo,-1,1)*32767).astype('<i2').tobytes())
def run(args):subprocess.run([FF,'-hide_banner','-loglevel','error','-y',*args],check=True)
def encode(args,out,dur):run([*args,'-t',str(dur),'-r','30','-c:v','libx264','-preset','veryfast','-crf','19','-pix_fmt','yuv420p','-an',str(ROOT/out)])
for name,dur in [('intro',2.8),('outro',3.5)]:
 encode(['-loop','1','-i',str(A/f'{name}.png'),'-vf',"scale=1124:1998,crop=1080:1920:x='22+8*sin(t)':y='39-10*sin(t)'"],f'{name}.mp4',dur);print(name,flush=True)
# Normalize variable-rate simulator captures before trimming.
for name,start,end in [('discover',28,34),('providers',19.8,24.8),('plan',25.4,30.9)]:
 filters=f'[1:v]fps=30,trim=start={start}:end={end},setpts=PTS-STARTPTS,scale=660:1434,setsar=1,format=rgb24[v];[2:v]format=gray[m];[v][m]alphamerge[phone];[0:v][phone]overlay=210:390:shortest=1,format=yuv420p[out]'
 encode(['-loop','1','-i',str(A/f'{name}.png'),'-i',str(ROOT/'raw'/f'{name}.mov'),'-loop','1','-i',str(A/'mask.png'),'-filter_complex',filters,'-map','[out]'],f'{name}.mp4',end-start);print(name,flush=True)
# Deliberate cuts on the score, with soft opening and closing fades.
files=['intro','discover','providers','plan','outro']
(ROOT/'timeline.txt').write_text(''.join(f"file '{name}.mp4'\n" for name in files))
run(['-f','concat','-safe','0','-i',str(ROOT/'timeline.txt'),'-i',str(A/'original-score.wav'),'-vf','fade=t=in:st=0:d=0.3,fade=t=out:st=22.2:d=0.6','-c:v','libx264','-preset','veryfast','-crf','19','-pix_fmt','yuv420p','-af','volume=5dB','-c:a','aac','-b:a','192k','-shortest','-movflags','+faststart',str(ROOT/'flixie-promo-vertical.mp4')]);print('finished',flush=True)
