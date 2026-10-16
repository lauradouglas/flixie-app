#!/usr/bin/env python3
"""Capture the shared-viewing Patrol states as real native iPhone screenshots."""
import http.server
import json
from pathlib import Path
import secrets
import subprocess
import threading

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/shared-viewing-screenshots'
DEVICE = '0D0ADEE4-62DA-42C4-96AD-FD3699F9980E'
SCENES = ['01-select-three', '02-watch-editor', '03-one-rating-card',
          '04-one-rating-detail', '05-one-rating-people',
          '06-everyone-rated', '07-everyone-rated-people',
          '08-wasnt-there-choice', '09-missed-complete', '10-missed-people']

def main():
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json']))
    device = next(d for values in devices['devices'].values() for d in values if d['udid'] == DEVICE)
    if device['name'] != 'Flixie Companion iPhone':
        raise RuntimeError('Refusing to reinstall a non-test simulator')
    if device['state'] != 'Booted':
        subprocess.run(['xcrun', 'simctl', 'boot', DEVICE], check=True)
    subprocess.run(['xcrun', 'simctl', 'bootstatus', DEVICE, '-b'], check=True, timeout=180)
    OUT.mkdir(parents=True, exist_ok=True)
    token = secrets.token_urlsafe(24)
    captured = []
    class Handler(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            name = self.path.removeprefix('/capture/')
            if self.headers.get('X-Flixie-Capture-Token') != token or name not in SCENES:
                self.send_error(403); return
            try:
                if name != SCENES[len(captured)]:
                    raise ValueError('Unexpected screenshot order')
                subprocess.run(['xcrun', 'simctl', 'io', DEVICE, 'screenshot', str(OUT / f'{name}.png')],
                               check=True, capture_output=True, timeout=45)
                captured.append(name)
                print(f'Captured {name}', flush=True)
                self.send_response(200); self.end_headers(); self.wfile.write(b'Captured')
            except Exception as error:
                self.send_error(500, str(error))
        def log_message(self, *_):
            pass
    server = http.server.HTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    command = [str(ROOT / 'scripts/test-patrol.sh'), '-d', DEVICE,
               '-t', 'patrol_test/shared_viewing_screenshots_test.dart', '--no-label',
               f'--dart-define=SCREENSHOT_HOST=http://127.0.0.1:{server.server_port}',
               f'--dart-define=SCREENSHOT_TOKEN={token}']
    try:
        with (OUT / 'patrol.log').open('w') as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=900)
        if result.returncode or captured != SCENES:
            print((OUT / 'patrol.log').read_text().replace(token, '<capture-token>')[-12000:])
            raise RuntimeError('Native screenshot journey failed')
        (OUT / 'manifest.json').write_text(json.dumps({'device': DEVICE, 'scenes': captured,
            'source': 'Native iPhone Simulator; real Flutter pages with fictional API fixtures',
            'participants': 'You plus Robin, Ellis and Sophie'}, indent=2))
        print(f'Saved all {len(captured)} screenshots to {OUT}')
    finally:
        server.shutdown(); server.server_close()

if __name__ == '__main__':
    main()
