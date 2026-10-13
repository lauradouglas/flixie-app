#!/usr/bin/env python3
"""Native review captures on dedicated Flixie test simulators only."""
import argparse
import http.server
import json
from pathlib import Path
import secrets
import subprocess
import threading

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--kind', choices=['tablet', 'phone'], default='tablet')
    parser.add_argument('--regressions', action='store_true',
                        help='Also run focused watchlist paging and favourites device tests.')
    parser.add_argument('--landscape-only', action='store_true',
                        help='Capture five tablet pages without the manual portrait rotation check.')
    args = parser.parse_args()
    inventory = json.loads(subprocess.check_output(
        ['xcrun', 'simctl', 'list', 'devices', '--json'], text=True))
    device = next((d for devices in inventory['devices'].values() for d in devices
                   if d['udid'] == args.device), None)
    if device is None or not device['name'].startswith('Flixie ') or 'Patrol' not in device['name']:
        raise SystemExit('Use a dedicated Flixie Patrol simulator: the runner reinstalls the app.')
    if device['state'] != 'Booted':
        raise SystemExit('Boot the dedicated simulator first.')
    output = ROOT / 'output/tablet-mockups/implemented' / args.kind
    output.mkdir(parents=True, exist_ok=True)
    token = secrets.token_urlsafe(32)
    scenes = ({f'landscape-{name}' for name in ['home', 'profile', 'watchlist', 'social', 'detail']}
              | (set() if args.landscape_only else {'portrait-detail', 'portrait-favourites'}) if args.kind == 'tablet'
              else {f'phone-{name}' for name in ['home', 'profile', 'watchlist', 'social', 'detail']})
    captured = set()

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            scene = self.path.removeprefix('/capture/')
            if scene not in scenes or self.headers.get('X-Flixie-Capture-Token') != token:
                self.send_error(403)
                return
            try:
                subprocess.run(['xcrun', 'simctl', 'io', args.device, 'screenshot',
                                str(output / f'{scene}.png')], check=True,
                               capture_output=True, timeout=30)
                captured.add(scene)
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'Captured')
                print(f'Captured {scene}', flush=True)
            except Exception as error:
                self.send_error(500, str(error))

        def log_message(self, *_):
            pass

    server = http.server.HTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    command = [str(ROOT / 'scripts/test-patrol.sh'), '-d', args.device,
               '-t', 'patrol_test/tablet_layout_test.dart', '--no-label',
               f'--dart-define=TABLET_CAPTURE_HOST=http://127.0.0.1:{server.server_port}',
               f'--dart-define=TABLET_CAPTURE_TOKEN={token}',
               f'--dart-define=TABLET_DEVICE={str(args.kind == "tablet").lower()}',
               f'--dart-define=TABLET_ROTATION_REVIEW={str(not args.landscape_only).lower()}']
    if args.regressions:
        command.extend(['-t', 'patrol_test/watchlist_paging_test.dart',
                        '-t', 'patrol_test/profile_gallery_test.dart'])
    try:
        with (output / 'patrol.log').open('w') as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                    timeout=1800)
        log_path = output / 'patrol.log'
        log_path.write_text(log_path.read_text().replace(token, '<capture-token>'))
        if result.returncode or captured != scenes:
            raise SystemExit(f'Native review failed; inspect {log_path}')
        print(f'Native review passed. Saved {len(captured)} captures to {output}', flush=True)
    finally:
        server.shutdown()
        server.server_close()


if __name__ == '__main__':
    main()
