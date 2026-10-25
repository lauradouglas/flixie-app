#!/usr/bin/env python3
"""Serve the review gallery and authenticated native screenshot handoff locally.

Run from any directory; launch the opt-in Patrol capture with the URL/token in
/tmp/flixie-signup-capture-config.json. The active-device file selects the actual
simulator for serial phone/tablet runs of the same compiled capture target.
"""
import http.server,json,secrets,subprocess,os,re,threading
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]/'output/signup-screen-review'
DEVICES={'phone':'3A372E2A-A991-4C81-BD29-E007555B5A01','tablet':'7F560127-76D5-4F86-9288-D847E0D9EADB'}
CONFIG_PATH=Path('/tmp/flixie-signup-capture-config.json')
CONFIG=json.loads(CONFIG_PATH.read_text()) if CONFIG_PATH.exists() else {'url':'http://127.0.0.1:0','token':secrets.token_urlsafe(24)}
TOKEN=CONFIG['token']
inventory=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','-j'],text=True))
for kind,uid in DEVICES.items():
 if not any(d['udid']==uid and 'Patrol' in d['name'] for ds in inventory['devices'].values() for d in ds):
  raise SystemExit('Use dedicated Patrol simulators only: '+kind)
manifest=json.loads((ROOT/'manifest.json').read_text()) if (ROOT/'manifest.json').exists() else []
manifest_lock=threading.Lock()
class Handler(http.server.SimpleHTTPRequestHandler):
 def __init__(self,*a,**kw):super().__init__(*a,directory=str(ROOT),**kw)
 def do_POST(self):
  if self.path!='/capture' or self.headers.get('X-Capture-Token')!=TOKEN:self.send_error(403);return
  if self.headers.get('Transfer-Encoding')=='chunked':
   body=b''
   while True:
    n=int(self.rfile.readline().strip(),16)
    if n==0:self.rfile.readline();break
    body+=self.rfile.read(n);self.rfile.read(2)
  else:body=self.rfile.read(int(self.headers['Content-Length']))
  data=json.loads(body)
  active=Path('/tmp/flixie-signup-active-device')
  if active.exists():data['device']=active.read_text().strip()
  if data['device'] not in DEVICES or not re.fullmatch(r'[a-z0-9-]+',data['name']):self.send_error(400);return
  dest=ROOT/data['device']/(data['name']+'.png');dest.parent.mkdir(parents=True,exist_ok=True)
  subprocess.run(['xcrun','simctl','io',DEVICES[data['device']],'screenshot',str(dest)],check=True,capture_output=True)
  data['src']=str(dest.relative_to(ROOT))
  with manifest_lock:
   manifest[:]=[m for m in manifest if (m['device'],m['name']) != (data['device'],data['name'])]
   manifest.append(data)
   (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2))
  self.send_response(200);self.end_headers();self.wfile.write(b'Captured')
  print(data['src'],flush=True)
 def log_message(self,*a):pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',int(CONFIG['url'].rsplit(':',1)[1])),Handler)
Path('/tmp/flixie-signup-capture-config.json').write_text(json.dumps({'url':'http://127.0.0.1:'+str(server.server_port),'token':TOKEN}))
print('http://127.0.0.1:'+str(server.server_port),flush=True)
server.serve_forever()
