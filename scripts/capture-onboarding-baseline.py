#!/usr/bin/env python3
"""Capture mounted Onboarding on an explicitly selected dedicated simulator."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
from urllib.request import urlopen

from runtime_ios_fixture import demo_firebase_plist


def validate_capture(data):
    """Reject partial journeys or mismatched fixture/transport measurements."""
    method = data.get('method', {})
    manifest = method.get('manifest', {})
    samples = data.get('samples', [])
    if (not data.get('complete') or method.get('suite') != 'onboarding'
            or manifest.get('database') != 'flixie_runtime_fixture'
            or manifest.get('search', {}).get('entries', 0) < 1000):
        raise ValueError('Incomplete capture or incorrect populated fixture')
    if [sample.get('run') for sample in samples] != list(range(1, 6)):
        raise ValueError('Expected five distinct ordered visits')
    for sample in samples:
        if (sample.get('requests') != {'GET /search': 4}
                or sample.get('responses') != {'GET /search': {'200': 4}}):
            raise ValueError('Catalogue request/response budget mismatch')
        if (sample.get('saved_taste') != ['movie:348', 'show:157239']
                or sample.get('watchlist_adds') != 1):
            raise ValueError('Missing saved taste or watchlist outcome')
        if not sample.get('frame_build_us') or not sample.get('frame_raster_us'):
            raise ValueError('Missing frame observations')
    return {'complete': True, 'samples': 5, 'http_200': 20}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--device', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    devices = json.loads(subprocess.check_output(
        ['xcrun', 'simctl', 'list', 'devices', '--json']))
    device = next((device for group in devices['devices'].values()
                   for device in group if device['udid'] == args.device), None)
    if not device or not any(word in device['name'].lower()
                             for word in ('patrol', 'memory')):
        raise SystemExit('Use a dedicated Patrol/Memory simulator; its app is reinstalled.')
    manifest = json.load(urlopen('http://127.0.0.1:3007/benchmark/manifest', timeout=5))
    if manifest.get('database') != 'flixie_runtime_fixture':
        raise SystemExit('Refusing a database other than the isolated fixture.')
    args.output.mkdir(parents=True, exist_ok=False)
    paths = list((root / 'lib').rglob('*.dart')) + [
        root / 'patrol_test/onboarding_baseline_test.dart',
        root / 'test/setup_flow_test.dart',
        root / 'patrol_test/support/runtime_database_fixture.dart',
        Path(__file__).resolve(),
    ]
    hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
    (args.output / 'source.json').write_text(json.dumps(hashes, indent=2) + '\n')
    with demo_firebase_plist(root), (args.output / 'patrol.log').open('w') as log:
        result = subprocess.run([
            str(root / 'scripts/test-patrol.sh'), '-d', args.device,
            '-t', 'patrol_test/onboarding_baseline_test.dart',
            '--dart-define=API_BASE_URL=http://127.0.0.1:3007',
        ], cwd=root, stdout=log, stderr=subprocess.STDOUT)
    log = re.sub(r'\x1b\[[0-9;]*m', '', (args.output / 'patrol.log').read_text())
    if (result.returncode or not re.search(r'Successful:\s*1', log)
            or not re.search(r'Failed:\s*0', log)):
        raise SystemExit('Native capture failed; log preserved.')
    data = json.load(urlopen('http://127.0.0.1:3007/benchmark/results', timeout=10))
    (args.output / 'runtime.json').write_text(json.dumps(data, indent=2) + '\n')
    checks = validate_capture(data)
    if data['method']['manifest'] != manifest:
        raise SystemExit('Fixture manifest changed during capture.')
    checks['source_unchanged'] = all(
        hashlib.sha256(Path(path).read_bytes()).hexdigest() == digest
        for path, digest in hashes.items())
    if not checks['source_unchanged']:
        raise SystemExit('Source changed during capture; results preserved.')
    (args.output / 'audit.json').write_text(json.dumps(checks, indent=2) + '\n')
    print(json.dumps(checks, indent=2))


if __name__ == '__main__':
    main()
