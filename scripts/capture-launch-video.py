#!/usr/bin/env python3
"""Capture isolated production UI through Patrol and native simulator recording."""
import os, importlib.util, json, secrets, threading, http.server, subprocess, signal, time
from pathlib import Path
spec=importlib.util.spec_from_file_location('screens',Path(__file__).with_name('store-screenshots.py'))
screens=importlib.util.module_from_spec(spec);spec.loader.exec_module(screens)
ROOT=screens.ROOT
OUT=ROOT/'build/launch-campaign';OUT.mkdir(parents=True,exist_ok=True)
config=json.loads((ROOT/'fastlane/ScreenshotConfig.json').read_text())
device,label=screens.ios_device(config['ios'][0])
scenes=os.environ.get('FLIXIE_VIDEO_SCENES','01-home|02-profile|03-watchlist|04-watch-plan').split('|')
token=secrets.token_urlsafe(32);active={};completed=[]
class Handler(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args): pass
 def do_POST(self):
  parts=self.path.strip('/').split('/')
  if self.headers.get('X-Flixie-Capture-Token')!=token or len(parts)!=2 or parts[1] not in scenes:
   self.send_error(403);return
  phase,name=parts
  try:
   if phase=='start':
    if active or name!=scenes[len(completed)]: raise ValueError('Unexpected scene')
    log=(OUT/(name+'.record.log')).open('w')
    p=subprocess.Popen(['xcrun','simctl','io',device,'recordVideo','--codec=h264','--force',str(OUT/(name+'.mov'))],stdout=log,stderr=log)
    active.update(process=p,log=log,name=name)
    deadline=time.monotonic()+15
    while 'Recording started' not in (OUT/(name+'.record.log')).read_text():
     if p.poll() is not None or time.monotonic()>deadline: raise RuntimeError('Recorder failed to start')
     time.sleep(.1)
   elif phase=='finish':
    if active.get('name')!=name: raise ValueError('Scene mismatch')
    p=active['process'];p.send_signal(signal.SIGINT);p.wait(timeout=20);active['log'].close();active.clear()
    screens.capture('ios',device,OUT/(name+'.png'));completed.append(name);print('Recorded '+name,flush=True)
   else: raise ValueError('Invalid phase')
   self.send_response(200);self.end_headers();self.wfile.write(b'OK')
  except Exception as e:self.send_error(500,str(e))
server=http.server.HTTPServer(('127.0.0.1',0),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 command=[str(ROOT/'scripts/test-patrol.sh'),'-d',device,'-t',os.environ.get('FLIXIE_VIDEO_TEST','patrol_test/launch_video_test.dart'),'--no-label',f'--dart-define=SCREENSHOT_HOST=http://127.0.0.1:{server.server_port}',f'--dart-define=SCREENSHOT_TOKEN={token}',f'--dart-define=SCREENSHOT_SCENES={"|".join(scenes)}']
 with (OUT/'patrol.log').open('w') as log:subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1800)
 if completed!=scenes:raise RuntimeError('Incomplete recording')
 (OUT/'capture.json').write_text(json.dumps({'device':device,'scenes':completed,'fixture':'fictional accounts; real UI'},indent=2))
finally:
 if active:
  active['process'].send_signal(signal.SIGINT);active['process'].wait(timeout=20);active['log'].close()
 server.shutdown();screens.cleanup('xcrun','simctl','status_bar',device,'clear')
