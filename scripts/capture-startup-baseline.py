#!/usr/bin/env python3
"""Observe genuine fresh simulator processes with an autonomous demo startup target.

This uses real FlixieApp/AuthProvider and persisted native Firebase emulator
sessions, but excludes production App Check, push registration and analytics.
Never install this target on a daily development device or distribute it.
"""
import argparse
from collections import defaultdict
import datetime
import hashlib
import json
import math
import os
import platform
from pathlib import Path
import plistlib
import statistics
import subprocess
import sys
import time
import tempfile
from urllib.error import HTTPError
from urllib.request import Request, urlopen
import uuid
from runtime_ios_fixture import demo_firebase_plist

ROOT = Path(__file__).resolve().parent.parent
BASE = 'http://127.0.0.1:3007'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '--json'], text=True))
    device = next(({**item, 'runtime': runtime} for runtime, items in devices['devices'].items()
                   for item in items if item['udid'] == args.device), None)
    if device is None or device['state'] != 'Booted':
        raise SystemExit('Choose a booted dedicated iOS simulator.')
    manifest = json.load(urlopen(BASE + '/benchmark/manifest', timeout=5))
    if manifest.get('database') != 'flixie_runtime_fixture':
        raise SystemExit('Refusing a backend other than the isolated fixture.')
    subprocess.run(['node', 'scripts/seed-runtime-auth.cjs'], cwd=ROOT.parent / 'FlixieBE', check=True)
    subprocess.run(['node', 'scripts/test-runtime-auth.cjs'], cwd=ROOT.parent / 'FlixieBE', check=True)
    subprocess.run(['node', 'scripts/test-runtime-startup-config.cjs'], cwd=ROOT.parent / 'FlixieBE', check=True)
    args.output.mkdir(parents=True, exist_ok=False)
    started = datetime.datetime.now(datetime.timezone.utc)
    subprocess.run([sys.executable, str(ROOT / 'scripts/repo-baseline.py'),
                    str(args.output / 'repository.json')], check=True)
    files = [ROOT / 'tool/runtime_startup.dart', ROOT / 'scripts/capture-startup-baseline.py',
             ROOT / 'scripts/runtime_ios_fixture.py', ROOT.parent / 'FlixieBE/scripts/runtime-benchmark.ts']
    (args.output / 'harness-source.json').write_text(json.dumps(
        {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}, indent=2) + '\n')
    with demo_firebase_plist(ROOT), tempfile.TemporaryDirectory(prefix='flixie-startup-') as temp, (args.output / 'build.log').open('w') as log:
        config = Path(temp) / 'simulator.xcconfig'
        config.write_text('ARCHS[sdk=iphonesimulator*] = ' + platform.machine() + '\n')
        build_env = dict(os.environ, XCODE_XCCONFIG_FILE=str(config))
        subprocess.run(['/opt/homebrew/bin/flutter', 'build', 'ios', '--simulator', '--debug',
            '-t', 'tool/runtime_startup.dart', '--dart-define=API_BASE_URL=http://127.0.0.1:3007'],
            cwd=ROOT, env=build_env, stdout=log, stderr=subprocess.STDOUT, check=True)
    bundle = ROOT / 'build/ios/iphonesimulator/Runner.app'
    native_info = plistlib.loads((bundle / 'Info.plist').read_bytes())
    bundle_id = native_info['CFBundleIdentifier']
    native_config = plistlib.loads((bundle / 'GoogleService-Info.plist').read_bytes())
    if native_config['PROJECT_ID'] != 'demo-flixie-review' or native_config['IS_ANALYTICS_ENABLED']:
        raise SystemExit('Built bundle is not the isolated demo configuration.')
    if not native_info.get('FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED') or native_info.get('FirebaseMessagingAutoInitEnabled') is not False:
        raise SystemExit('Native analytics/FCM auto-init must be disabled in the fixture bundle.')
    subprocess.run(['xcrun', 'simctl', 'install', args.device, str(bundle)], check=True)
    samples = []
    launch_log = args.output / 'launch.log'

    def launch(mode, size):
        nonce = str(uuid.uuid4())
        configuration = Request(BASE + '/benchmark/startup-config',
            data=json.dumps({'capture_id': nonce, 'mode': mode, 'library_size': size}).encode(),
            headers={'content-type': 'application/json', 'authorization': 'Bearer runtime-fixture-0'})
        with urlopen(configuration, timeout=5) as response:
            if response.status != 200:
                raise RuntimeError('Startup configuration rejected')
        # Each observation starts before the OS launch request, after termination.
        subprocess.run(['xcrun', 'simctl', 'terminate', args.device, bundle_id],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        begin = time.monotonic_ns()
        with launch_log.open('a') as log:
            subprocess.run(['xcrun', 'simctl', 'launch', args.device, bundle_id],
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        launch_return_us = (time.monotonic_ns() - begin) // 1000
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            try:
                capture = json.load(urlopen(BASE + '/benchmark/results', timeout=3))
                if capture.get('method', {}).get('capture_id') == nonce:
                    if not capture.get('complete') or len(capture.get('samples', [])) != 1:
                        raise RuntimeError('Invalid process capture')
                    sample = capture['samples'][0]
                    return {**sample, 'capture_id': nonce,
                            'host_launch_to_content_observed_us': (time.monotonic_ns() - begin) // 1000,
                            'simctl_launch_return_us': launch_return_us}
            except HTTPError as error:
                if error.code != 404:
                    raise
            time.sleep(.05)
        raise RuntimeError(f'No ready marker after fresh process launch ({mode}, {size}). Inspect simulator and {launch_log}.')

    try:
        for mode, size in [('signed_out', 20), ('signed_in', 20), ('signed_in', 400)]:
            preparation = launch('prepare_' + mode, size)
            if not preparation.get('prepared'):
                raise RuntimeError('Preparation did not complete')
            for repetition in range(1, 6):
                sample = launch(mode, size)
                if sample.get('scenario') != mode or sample.get('library_size') != size:
                    raise RuntimeError('Wrong process/account condition')
                samples.append({**sample, 'repetition': repetition})
                (args.output / 'partial.json').write_text(json.dumps(samples, indent=2) + '\n')
    finally:
        subprocess.run(['xcrun', 'simctl', 'terminate', args.device, bundle_id],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if len(samples) != 15:
        raise SystemExit('Incomplete process-startup capture.')
    groups = defaultdict(list)
    for sample in samples:
        groups[(sample['scenario'], sample['library_size'])].append(sample)
    summary = []
    for (scenario, size), values in sorted(groups.items()):
        times = [v['host_launch_to_content_observed_us'] / 1000 for v in values]
        summary.append({'scenario': scenario, 'library_size': size, 'samples': len(values),
            'os_launch_to_content_median_ms': statistics.median(times),
            'os_launch_to_content_p95_ms': sorted(times)[math.ceil(len(times) * .95) - 1],
            'dart_entry_to_content_median_ms': statistics.median(v['dart_entry_to_content_us'] for v in values) / 1000,
            'requests_at_content': [sum(v['requests'].values()) for v in values]})
    limitations = [
        'Genuine new iOS simulator app processes and Flutter engines; warm OS/filesystem/PostgreSQL/server/image disk caches, not reboot or install time.',
        'Debug simulator, no Patrol test binding; autonomous fixture entrypoint, production FlixieApp/router/AuthProvider. No physical-device/release claim.',
        'Native Firebase Auth initialisation and persisted session restoration across process termination are included; demo project and local emulator JWT verification only.',
        'Production main.dart App Check, FCM/APNs registration and external analytics are excluded; this is the isolated fixture startup variant, not the entire production launch path.',
        'Start is host monotonic time before simctl launch; end is receipt/polling of the app marker after a completed frame with Login or Alien content. Includes simctl, marker HTTP and up to ~50ms polling overhead.',
        'Local launch-config and manifest preflight are included in launch time but excluded from API counts; the host sets configuration before timing. Marker HTTP/polling overhead is included; API reads/statuses stop at useful content, not background completion.',
        'Setup signs in/out before timing, then each measured launch terminates the prior process; no sign-in call is included in restored-session timing.',
        'Single foreground surface and fixed condition order; five samples each, p95 is maximum of five. Peak RSS starts in Dart after native Firebase setup, not an OS-wide launch peak.',
        'Frame timings delivered before the useful-content marker may be empty due to native batching; this capture is for launch latency, not a complete startup frame profile.',
        'Offline external catalogue substitutions are the same as the populated fixture; no production accounts or mutations.',
        'The existing native AppDelegate still runs. Native SDK installation-ID background requests can fail against the synthetic demo Firebase project; they carry no production credentials and are outside backend API counts. Dart App Check/push registration and analytics collection are disabled for this variant.',
    ]
    sdk = json.loads(subprocess.check_output(['/opt/homebrew/bin/flutter', '--version', '--machine'], text=True))
    report = {'captured_at_utc': started.isoformat(), 'complete': True, 'device': device,
              'flutter': {key: sdk[key] for key in ['frameworkVersion', 'frameworkRevision', 'dartSdkVersion']},
              'database_manifest': manifest, 'summary': summary, 'samples': samples, 'limitations': limitations}
    (args.output / 'runtime.json').write_text(json.dumps(report, indent=2) + '\n')
    lines = ['# Fresh-process startup simulator baseline', '',
        '15 completed fresh-process launches using real persisted native Firebase emulator sessions and the populated local API.',
        'Debug autonomous fixture variant; production App Check, push registration and analytics excluded.', '',
        '| Session | Library films | OS launch → content median / p95 ms | Dart entry → content median ms | API reads at content |',
        '|---|---:|---:|---:|---|']
    for item in summary:
        lines.append(f"| {item['scenario']} | {item['library_size']} | {item['os_launch_to_content_median_ms']:.1f} / {item['os_launch_to_content_p95_ms']:.1f} | {item['dart_entry_to_content_median_ms']:.1f} | {item['requests_at_content']} |")
    lines += ['', 'Raw records: [runtime.json](runtime.json). Source hashes, build and launch logs are alongside it.',
              '', 'Limitations:', '', *['- ' + value for value in limitations], '']
    (args.output / 'README.md').write_text('\n'.join(lines))
    print(f'Saved 15 fresh-process startup samples: {args.output / "README.md"}')


if __name__ == '__main__':
    main()
