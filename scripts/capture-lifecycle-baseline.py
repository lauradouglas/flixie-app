#!/usr/bin/env python3
"""Capture native auth startup, email login and foreground resume on an isolated simulator.

Start the backend runtime API and demo Firebase emulators first (docs/testing.md).
Patrol reinstalls the app: --device must be a dedicated simulator.
"""
import argparse
from collections import defaultdict
import datetime
import hashlib
import json
import math
from pathlib import Path
import re
import statistics
import subprocess
import sys
from urllib.request import urlopen
import uuid
from runtime_ios_fixture import demo_firebase_plist

ROOT = Path(__file__).resolve().parent.parent
BASE = 'http://127.0.0.1:3007'
SCENARIOS = ['startup_signed_in', 'startup_signed_out', 'email_login',
             'resume_refresh', 'resume_throttled']


def percentile(values):
    return sorted(values)[math.ceil(len(values) * .95) - 1] if values else None


def response_gaps(samples):
    gaps = []
    for sample in samples:
        missing = {endpoint: count - sum(sample['response_statuses'].get(endpoint, {}).values())
                   for endpoint, count in sample['requests'].items()
                   if count != sum(sample['response_statuses'].get(endpoint, {}).values())}
        if missing:
            gaps.append({'scenario': sample['scenario'], 'library_size': sample['library_size'],
                         'repetition': sample['repetition'], 'requests_without_recorded_response': missing})
    return gaps



def transport_audit(samples):
    failures = []
    errors = []
    for sample in samples:
        key = {name: sample[name] for name in ('scenario', 'library_size', 'repetition')}
        statuses = {endpoint: {status: count for status, count in counts.items()
                              if int(status) >= 400 and count}
                    for endpoint, counts in sample['response_statuses'].items()}
        statuses = {endpoint: counts for endpoint, counts in statuses.items() if counts}
        if statuses:
            failures.append({**key, 'response_failures': statuses})
        if sample.get('transport_errors'):
            errors.append({**key, 'transport_errors': sample['transport_errors']})
    gaps = response_gaps(samples)
    return {'clean': not (failures or errors or gaps),
            'response_failures': failures, 'transport_errors': errors,
            'request_response_gaps': gaps}


def memory_audit(rows, retaining=False):
    expected = {(phase, size, repetition) for phase in
                (['signed_in', 'logged_out', 'switched', 'unmounted', 'post_cycle', 'post_input_replacement'] if retaining else
                 ['signed_in', 'logged_out', 'switched', 'unmounted'])
                for size in [20, 400] for repetition in range(1, 6)}
    actual = {(row['phase'], row['library_size'], row['repetition']) for row in rows}
    timestamps = [int(row.get('dateLastServiceGC') or 0) for row in rows]
    return (len(rows) == len(expected) and actual == expected
            and all(value > 0 for value in timestamps)
            and all(b > a for a, b in zip(timestamps, timestamps[1:])))


def retaining_audit(rows):
    if not memory_audit(rows, retaining=True):
        return False
    for row in rows:
        if row['phase'] not in ['unmounted', 'post_cycle', 'post_input_replacement']:
            continue
        count = row.get('instance_lookup_count')
        if count is None:
            return False
        paths = row.get('retaining_paths', [])
        if len(paths) != count:
            return False
        for path in paths:
            if (path.get('type') != 'RetainingPath' or not path.get('gcRootType')
                    or path.get('length', 0) <= 0
                    or len(path.get('elements', [])) != path['length']):
                return False
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--retaining-paths', action='store_true')
    parser.add_argument('--scope', choices=['standard', 'accounts'], default='standard')
    parser.add_argument('--device', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.retaining_paths and args.scope != 'accounts':
        parser.error('--retaining-paths requires --scope accounts')
    manifest = json.load(urlopen(BASE + '/benchmark/manifest', timeout=5))
    if manifest.get('database') != 'flixie_runtime_fixture':
        raise SystemExit('Refusing a backend other than the isolated fixture.')
    devices = json.loads(subprocess.check_output(
        ['xcrun', 'simctl', 'list', 'devices', '--json'], text=True))
    device = next(({**item, 'runtime': runtime}
                   for runtime, items in devices['devices'].items()
                   for item in items if item['udid'] == args.device), None)
    if device is None:
        raise SystemExit('Choose a dedicated iOS simulator.')
    # Seeding is rerunnable and refuses other identities. No credentials printed.
    subprocess.run(['node', 'scripts/seed-runtime-auth.cjs'],
                   cwd=ROOT.parent / 'FlixieBE', check=True)
    args.output.mkdir(parents=True, exist_ok=False)
    capture_id = str(uuid.uuid4())
    started = datetime.datetime.now(datetime.timezone.utc)
    subprocess.run([sys.executable, str(ROOT / 'scripts/repo-baseline.py'),
                    str(args.output / 'repository.json')], check=True)
    files = [ROOT / 'lib/core/auth/auth_provider.dart',
             ROOT / 'lib/core/auth/auth_account_cache.dart',
             ROOT / 'lib/core/auth/auth_session_recovery.dart',
             ROOT / 'lib/main.dart',
             ROOT / 'lib/core/auth/push_notification_service.dart',
             ROOT / 'patrol_test/runtime_lifecycle_baseline_test.dart',
             ROOT / 'patrol_test/support/runtime_database_fixture.dart',
             ROOT / 'scripts/capture-lifecycle-baseline.py',
             ROOT / 'scripts/runtime_ios_fixture.py',
             ROOT.parent / 'FlixieBE/scripts/runtime-benchmark.ts',
             ROOT.parent / 'FlixieBE/scripts/runtime-http-server.cjs',
             ROOT.parent / 'FlixieBE/scripts/runtime-emulators.json',
             ROOT.parent / 'FlixieBE/scripts/runtime-emulators.rules',
             ROOT.parent / 'FlixieBE/scripts/seed-runtime-auth.cjs']
    hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
    (args.output / 'harness-source.json').write_text(json.dumps(hashes, indent=2) + '\n')
    log = args.output / 'patrol.log'
    with demo_firebase_plist(ROOT), log.open('w') as output:
        run = subprocess.run([str(ROOT / 'scripts/test-patrol.sh'), '-d', args.device,
            '-t', 'patrol_test/runtime_lifecycle_baseline_test.dart',
            '--dart-define=API_BASE_URL=http://127.0.0.1:3007',
            '--dart-define=RUNTIME_CAPTURE_ID=' + capture_id,
            '--dart-define=RUNTIME_LIFECYCLE_SCOPE=' + args.scope,
            '--dart-define=RUNTIME_RETAINING_PATHS=' + str(args.retaining_paths).lower()],
            cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
    if run.returncode:
        raise SystemExit(f'Native run failed; no successful baseline recorded. Inspect {log}.')
    console = re.sub(r'\x1b\[[0-9;]*m', '', log.read_text())
    if not re.search(r'Successful:\s*1\b', console) or re.search(r'Failed:\s*[1-9]', console):
        raise SystemExit('Native run did not report one successful test.')
    native = json.load(urlopen(BASE + '/benchmark/results?suite=lifecycle', timeout=10))
    (args.output / 'native.json').write_text(json.dumps(native, indent=2) + '\n')
    samples = native['samples']
    scenarios = ['logout', 'account_switch_login'] if args.scope == 'accounts' else SCENARIOS
    expected = {(scenario, size, repetition) for scenario in scenarios
                for size in [20, 400] for repetition in range(1, 6)}
    actual = {(v['scenario'], v['library_size'], v['repetition']) for v in samples}
    if not native['complete'] or native['method']['capture_id'] != capture_id or len(samples) != len(expected) or actual != expected:
        raise SystemExit('Incomplete or stale capture; no successful baseline recorded.')
    audit = transport_audit(samples)
    (args.output / 'transport-audit.json').write_text(json.dumps(audit, indent=2) + '\n')
    if not audit['clean']:
        raise SystemExit('Transport-incomplete capture; raw samples retained, no reliable baseline recorded.')
    groups = defaultdict(list)
    failures = defaultdict(lambda: defaultdict(int))
    for sample in samples:
        groups[(sample['scenario'], sample['library_size'])].append(sample)
        for endpoint, statuses in sample['response_statuses'].items():
            for status, count in statuses.items():
                if int(status) >= 400:
                    failures[endpoint][status] += count
    gaps = response_gaps(samples)
    summary = []
    for (scenario, size), values in sorted(groups.items()):
        build = [t for value in values for t in value['frame_build_us']]
        raster = [t for value in values for t in value['frame_raster_us']]
        def phase_median(name):
            times = [value['phases_us'][name] for value in values if name in value['phases_us']]
            return statistics.median(times) / 1000 if times else None
        summary.append({
            'scenario': scenario, 'library_size': size, 'samples': len(values),
            'useful_median_ms': statistics.median(v['useful_content_us'] for v in values) / 1000,
            'useful_p95_ms': percentile([v['useful_content_us'] for v in values]) / 1000,
            'settled_median_ms': statistics.median(v['settled_us'] for v in values) / 1000,
            'build_p95_ms': percentile(build) / 1000 if build else None,
            'raster_p95_ms': percentile(raster) / 1000 if raster else None,
            'rss_peak_median_mib': statistics.median(v['rss_peak_bytes'] for v in values) / 1048576,
            'requests': [sum(v['requests'].values()) for v in values],
            'firebase_sign_in_median_ms': phase_median('firebase_email_sign_in_us'),
            'profile_total_median_ms': phase_median('profile_total_us'),
            'terms_median_ms': phase_median('terms_us'),
            'profile_calls': [v['phases_us'].get('profile_calls', 0) for v in values],
        })
    bundles = [p for p in (ROOT / 'build').glob('ios_results_*.xcresult')
               if p.stat().st_mtime >= started.timestamp()]
    sdk = json.loads(subprocess.check_output(
        ['/opt/homebrew/bin/flutter', '--version', '--machine'], text=True))
    limitations = [
        'Debug iOS simulator and Patrol observation/automation overhead; no release or physical-device claim.',
        'Startup is fresh auth provider/app root and real session restoration in one process; OS launch, engine startup and persisted-session restoration across process death are excluded.',
        'Firebase native initialisation has one separate observation before scenarios; App Check, FCM/APNs, native sign-in-provider dialogs and production network latency are excluded.',
        'Production FlixieApp/router/AuthProvider and native email SDK are used; test providers replace root main wiring, analytics stays local, push registration is disabled.',
        'SharedPreferences loads are included in startup root setup but its native/in-process caches remain warm; production main.dart pre-runApp setup is not measured as a whole.',
        'Home session snapshot, selected service caches and decoded images reset before startup/login; server, PostgreSQL buffers, image disk cache and Firebase SDK remain warm.',
        'Restoration signs into the demo SDK before timing; measures auth-state emission, token reuse, SQL profile/terms, routing and Home readiness.',
        'Login starts at automated Sign In tap after fields are filled; includes observation overhead, emulator sign-in, profile/terms and Home content.',
        'Resume starts immediately before native openApp; records Flutter resumed callback, visible Home and profile readiness separately in raw samples; one-second background interval.',
        'First resume performs one profile read owned by AuthProvider recovery; Home reuses that profile. Second resume within two minutes performs none. Compare with the original two-read reference.',
        'Local fixture server keep-alive lifetime is recorded in the manifest; transport errors, missing responses and HTTP errors invalidate this capture. No hidden transport retries.',
        'API settled timing waits for tracked HTTP and auth prefetch; excludes ongoing Firestore subscriptions and five-second notification polling.',
        'Five repetitions per condition: useful-content p95 is the maximum of five samples. RSS is pre-GC engine/test-process memory, not retained heap.',
        'Existing local catalogue external-transport substitutions remain; endpoint failures are included, not discarded.',
    ]
    if args.scope == 'accounts':
        limitations = [
            'Debug iOS simulator; five repetitions in each direction, real native demo Firebase Auth and local populated PostgreSQL.',
            'Logout starts at production AuthProvider.signOut and ends at visible Login with native session cleared; confirmation UI excluded.',
            'Account-switch login starts at Sign In tap after logout and target fields are prepared. It is the login leg, not a combined switch or human typing time.',
            'Push registration is disabled; demo token cleanup is attempted by production logout, but production FCM/APNs latency is not represented.',
            'GC allocation profiles are separate from timed windows; decoded image caches are not manually cleared between logout and switching.',
            'RSS includes native engine/test allocations. Allocation profiles cover the Dart isolate only; retained instance counts do not identify retaining paths.',
            'Startup/login/resume historical results remain separate. These samples measure current fixture content and warm native SDK/server caches.',
        ]
        memory = native.get('memory_samples', [])
        if not (retaining_audit(memory) if args.retaining_paths else memory_audit(memory)):
            raise SystemExit('Incomplete GC diagnostics.')
    report = {
        'captured_at_utc': started.isoformat(), 'device': device,
        'flutter': {key: sdk[key] for key in ['frameworkVersion', 'frameworkRevision', 'dartSdkVersion']},
        'xcresult': str(max(bundles, key=lambda p: p.stat().st_mtime)) if bundles else None,
        'method': native['method'], 'complete': True, 'transport_clean': True, 'summary': summary,
        'response_failures': dict(failures), 'request_response_gaps': gaps,
        'limitations': limitations, 'samples': samples,
        'memory_samples': native.get('memory_samples', []),
        'samples_sha256': hashlib.sha256(json.dumps(samples, sort_keys=True).encode()).hexdigest(),
    }
    (args.output / 'runtime.json').write_text(json.dumps(report, indent=2) + '\n')
    lines = ['# Account lifecycle simulator baseline' if args.scope == 'accounts' else '# Startup, login and resume simulator baseline', '',
        'Real native Firebase Auth emulator + populated local PostgreSQL. Five repetitions per condition.',
        'Logout and the subsequent target-account Sign In are measured separately; form preparation is outside timing.' if args.scope == 'accounts' else 'Startup here means app/auth bootstrap in a running test process; fresh-process launch is recorded separately in the startup simulator reference.', '',
        f"Native Firebase initialisation: {native['method']['firebase_initialize_us'] / 1000:.1f} ms (one observation).", '',
        '| Journey | Library films | Useful median / p95 ms | Settled median ms | UI / raster p95 ms | API reads | Peak RSS MiB |',
        '|---|---:|---:|---:|---:|---|---:|']
    def number(value):
        return f'{value:.1f}' if value is not None else 'unavailable'
    for item in summary:
        lines.append(f"| {item['scenario']} | {item['library_size']} | {number(item['useful_median_ms'])} / {number(item['useful_p95_ms'])} | {number(item['settled_median_ms'])} | {number(item['build_p95_ms'])} / {number(item['raster_p95_ms'])} | {item['requests']} | {number(item['rss_peak_median_mib'])} |")
    lines += ['', 'Timed production auth phases (medians):', '',
        '| Journey | Library | Firebase email sign-in ms | Profile reads total ms | Terms ms | Profile calls |',
        '|---|---:|---:|---:|---:|---|']
    for item in summary:
        lines.append(f"| {item['scenario']} | {item['library_size']} | {number(item['firebase_sign_in_median_ms'])} | {number(item['profile_total_median_ms'])} | {number(item['terms_median_ms'])} | {item['profile_calls']} |")
    lines += ['', 'Failures by endpoint/status:', '',
        *[f'- `{endpoint}`: {dict(statuses)}' for endpoint, statuses in failures.items()],
        *(['None recorded.'] if not failures else []), '',
        'Request/response gaps (transport failures or unfinished requests):', '',
        *[f'- {item}' for item in gaps],
        *(['None recorded.'] if not gaps else []), '',
        'Raw timing boundaries, profile/terms/sign-in phases, lifecycle callbacks, API responses, frames and memory: [runtime.json](runtime.json).', '',
        'Limitations:', '', *['- ' + value for value in limitations], '']
    (args.output / 'README.md').write_text('\n'.join(lines))
    print(f'Saved {len(samples)} complete lifecycle samples: {args.output / "README.md"}')


if __name__ == '__main__':
    main()
