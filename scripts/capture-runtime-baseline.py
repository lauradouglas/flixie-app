#!/usr/bin/env python3
"""Run/extract the isolated iOS simulator benchmark and save a durable report.

Start the isolated backend fixture first.
Run: python3 scripts/capture-runtime-baseline.py --database --device <dedicated-simulator-id> --output <new-directory>
Extract an existing run: add --log <patrol-log> --xcresult <result-bundle>.
Patrol reinstalls the app: use a dedicated simulator, never a daily device.
"""
import argparse
from collections import defaultdict
import datetime
import hashlib
import json
import math
from pathlib import Path
import statistics
import re
from urllib.request import urlopen
import subprocess
import sys
from runtime_ios_fixture import demo_firebase_plist

DEFAULT_SCENARIOS = ('home', 'movie_detail', 'tv_detail', 'watchlist_20', 'watchlist_400')
SCENARIOS = (*DEFAULT_SCENARIOS, 'profile', 'friend_profile', 'social', 'watch_requests', 'movie_list_detail', 'person_detail', 'group_watch_plan', 'watch_composer', 'group_insights', 'search')

def expected_sample_keys(scenario=None):
    if scenario is not None and scenario not in SCENARIOS:
        raise ValueError(f'Unknown runtime scenario: {scenario}')
    scopes = [scenario] if scenario is not None else DEFAULT_SCENARIOS
    return {(scope, cache, run) for scope in scopes
            for cache in ('cold', 'warm') for run in range(1, 6)}

def main():
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--log', type=Path)
    parser.add_argument('--xcresult', type=Path)
    parser.add_argument('--source-snapshot', type=Path)
    parser.add_argument('--scenario', choices=SCENARIOS, help='Capture only one mounted screen; default captures all five')
    parser.add_argument('--database', action='store_true', required=True, help='Use the isolated localhost PostgreSQL API on port 3007')
    args = parser.parse_args()
    try:
        manifest = json.load(urlopen('http://127.0.0.1:3007/benchmark/manifest', timeout=3))
    except OSError as error:
        raise SystemExit('Start scripts/start-runtime-benchmark.cjs in the backend checkout before capturing.') from error
    if manifest.get('database') != 'flixie_runtime_fixture':
        raise SystemExit('Refusing a backend other than the isolated runtime fixture.')
    args.output.mkdir(parents=True, exist_ok=False)
    started = datetime.datetime.now(datetime.timezone.utc)
    if args.scenario in ('group_insights', 'search'):
        files = list((root / 'lib').rglob('*.dart')) + [
            root / 'patrol_test/runtime_baseline_test.dart', root / 'patrol_test/support/runtime_database_fixture.dart',
            Path(__file__).resolve(), root.parent / 'FlixieBE/scripts/runtime-benchmark.ts',
            root.parent / 'FlixieBE/scripts/runtime-watch-plan-fixtures.ts',
            root.parent / 'FlixieBE/scripts/runtime-search-fixture.ts']
        hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
        (args.output / 'harness-source.json').write_text(json.dumps(hashes, indent=2) + '\n')
    if args.scenario == 'watch_composer':
        files = [root / 'lib/features/movies/presentation/widgets/watch_request_sheet.dart',
            root / 'patrol_test/runtime_baseline_test.dart', root / 'patrol_test/support/runtime_database_fixture.dart',
            root / 'scripts/capture-runtime-baseline.py', root.parent / 'FlixieBE/scripts/runtime-benchmark.ts',
            root.parent / 'FlixieBE/scripts/runtime-watch-plan-fixtures.ts']
        files += list((root / 'lib/features/movies/presentation/widgets/watch_composer').glob('*.dart'))
        files += [p for p in [root / 'lib/features/movies/presentation/controllers/watch_composer_controller.dart',
            root / 'lib/features/movies/presentation/controllers/watch_composer_providers.dart',
            root / 'lib/features/movies/presentation/watch_composer_actions.dart',
            root / 'lib/features/movies/data/watch_composer_service.dart'] if p.exists()]
        hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
        (args.output / 'harness-source.json').write_text(json.dumps(hashes, indent=2) + '\n')
    if args.scenario == 'group_watch_plan':
        files = list((root / 'lib/features/watch_plans').rglob('*.dart')) + [
            root / 'patrol_test/runtime_baseline_test.dart', root / 'patrol_test/support/runtime_database_fixture.dart',
            root / 'scripts/capture-runtime-baseline.py', root.parent / 'FlixieBE/scripts/runtime-watch-plan-fixtures.ts']
        hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
        (args.output / 'harness-source.json').write_text(json.dumps(hashes, indent=2) + '\n')
    if args.scenario == 'person_detail':
        files = [root / 'lib/features/movies/presentation/pages/person_detail_screen.dart',
                 root / 'patrol_test/runtime_baseline_test.dart',
                 root / 'patrol_test/support/runtime_database_fixture.dart',
                 root / 'scripts/capture-runtime-baseline.py',
                 root.parent / 'FlixieBE/scripts/runtime-benchmark.ts',
                 root.parent / 'FlixieBE/scripts/runtime-person-fixture.ts']
        files += list((root / 'lib/features/movies/presentation/widgets/person_detail').glob('*.dart'))
        files += [path for path in [
            root / 'lib/features/movies/presentation/controllers/person_detail_controller.dart',
            root / 'lib/features/movies/presentation/person_filmography_selection.dart',
            root / 'lib/features/movies/presentation/person_detail_action_flow.dart',
            root / 'lib/features/movies/data/person_detail_service.dart'] if path.exists()]
        hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
        (args.output / 'harness-source.json').write_text(json.dumps(hashes, indent=2) + '\n')

    log = args.log
    result = args.xcresult
    if log is None:
        snapshot = args.output / 'repository.json'
        subprocess.run([sys.executable, str(root / 'scripts/repo-baseline.py'), str(snapshot)], check=True)
        args.source_snapshot = snapshot
        log = args.output / 'patrol.log'
        with demo_firebase_plist(root), log.open('w') as output:
            command = [str(root / 'scripts/test-patrol.sh'), '-d', args.device,
                '-t', 'patrol_test/runtime_baseline_test.dart']
            if args.database:
                command += ['--dart-define=RUNTIME_DATABASE=true', '--dart-define=API_BASE_URL=http://127.0.0.1:3007']
            if args.scenario:
                command += [f'--dart-define=RUNTIME_SCENARIO={args.scenario}']
            run = subprocess.run(command, cwd=root, stdout=output,
                stderr=subprocess.STDOUT)
        if run.returncode:
            raise SystemExit(f'Patrol failed ({run.returncode}); preserve and inspect {log}. No successful baseline recorded.')
        candidates = [p for p in (root / 'build').glob('ios_results_*.xcresult')
            if p.stat().st_mtime >= started.timestamp()]
        if candidates:
            result = max(candidates, key=lambda p: p.stat().st_mtime)

    # Native samples go to the localhost collector before Xcode removes its simulator clone.
    console = re.sub(r'\x1b\[[0-9;]*m', '', log.read_text())
    if not re.search(r'Successful:\s*1', console) or re.search(r'Failed:\s*[1-9]', console):
        raise SystemExit('The supplied native run did not pass; no successful baseline recorded.')
    native = json.load(urlopen('http://127.0.0.1:3007/benchmark/results', timeout=10))
    raw = native['samples']
    completion = {**native['method'], 'samples': len(raw), 'complete': native['complete']}
    samples = {(sample['scenario'], sample['cache'], sample['repetition']): sample
        for sample in raw}
    expected = expected_sample_keys(args.scenario)
    expected_count = len(expected)
    if not native['complete'] or len(raw) != expected_count or len(samples) != expected_count:
        (args.output / 'incomplete.json').write_text(json.dumps({'status': 'incomplete',
            'completion': completion, 'samples': raw}, indent=2) + '\n')
        raise SystemExit(f'Incomplete capture ({len(raw)}/{expected_count} samples); no successful baseline reported. Inspect {log} and {result}.')

    if set(samples) != expected:
        raise SystemExit('Unexpected or missing scenario/cache/repetition keys.')
    def percentile(values, fraction):
        return sorted(values)[max(0, math.ceil(len(values) * fraction) - 1)] if values else None

    failures = defaultdict(lambda: defaultdict(int))
    for sample in raw:
        for endpoint, statuses in sample.get('response_statuses', {}).items():
            for status, count in statuses.items():
                if int(status) >= 400:
                    failures[endpoint][status] += count
    groups = defaultdict(list)
    for sample in raw:
        groups[(sample['scenario'], sample['cache'])].append(sample)
    summary = []
    for (scope, cache), values in sorted(groups.items()):
        build = [time for value in values for time in value['frame_build_us']]
        raster = [time for value in values for time in value['frame_raster_us']]
        hz_values = {value['display_refresh_hz'] for value in values}
        hz = next(iter(hz_values)) if len(hz_values) == 1 else None
        budget = 1_000_000 / hz if hz and hz > 0 else None
        exceeded = sum(max(ui, gpu) > budget for ui, gpu in zip(build, raster)) if budget else None
        summary.append({'scenario': scope, 'cache': cache, 'samples': len(values),
            'useful_content_median_ms': statistics.median(v['useful_content_us'] for v in values) / 1000,
            'useful_content_p95_ms': percentile([v['useful_content_us'] for v in values], .95) / 1000,
            'settled_median_ms': statistics.median(v['settled_us'] for v in values) / 1000,
            'build_p95_ms': percentile(build, .95) / 1000 if build else None,
            'raster_p95_ms': percentile(raster, .95) / 1000 if raster else None,
            'frames_observed': len(build), 'frame_budget_exceeded': exceeded,
            'display_refresh_hz': hz,
            'requests_load': [sum(v['requests_load'].values()) for v in values],
            'requests_total': [sum(v['requests_total'].values()) for v in values],
            'rss_peak_median_mib': statistics.median(v['rss_peak_bytes'] for v in values) / 1048576,
            'rss_end_median_mib': statistics.median(v['rss_end_bytes'] for v in values) / 1048576,
            'rss_end_minus_start_median_mib': statistics.median(v['rss_end_bytes'] - v['rss_start_bytes'] for v in values) / 1048576})

    sdk = json.loads(subprocess.check_output(['/opt/homebrew/bin/flutter', '--version', '--machine'], text=True))
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '--json'], text=True))
    device = next(({**item, 'runtime': runtime} for runtime, items in devices['devices'].items()
        for item in items if item['udid'] == args.device), None)
    if device is None:
        raise SystemExit('Device ID is not an iOS simulator; refusing to label this a simulator capture.')
    report = {'captured_at_utc': started.isoformat(), 'device': device,
        'flutter': {key: sdk[key] for key in ['frameworkVersion', 'frameworkRevision', 'dartSdkVersion']},
        'source_snapshot': str(args.source_snapshot) if args.source_snapshot else None,
        'xcresult': str(result) if result else None, 'method': completion,
        'limitations': ['debug simulator + Patrol overhead; not physical-device or release performance',
            'first-content polling includes automation observation overhead',
            ('Real localhost PostgreSQL/API; Firebase verification isolated; auth/startup excluded' if completion.get('database_manifest') else '25ms mock HTTP; authentication/startup excluded'),
            'Catalogue posters remain; image disk cache and network conditions are not reset or controlled',
            'API request counts exclude poster/image downloads and fixture bootstrap',
            'Cold means named service/image-memory caches reset; PostgreSQL buffers/server caches remain warm',
            'Home retains its session snapshot after the first mount; its cold median is not five full-cold screen loads',
            'Firebase/legacy reactions are isolated, trending/details use local catalogue transport; external cast is empty',
            'Offline external movie-recommendation and TV-provider refresh failures are retained by endpoint/status',
            'five runs per condition; p95 time-to-content is the maximum of five samples',
            'frames combine screen loading and five flings; budget exceedance is a duration proxy, not measured dropped frames',
            'RSS includes engine/test harness; endpoint memory is pre-GC, not retained heap or proof of leaks',
            'provider_enrichment_batches is cumulative within each cold/warm auth pair'],
        'response_failures': dict(failures),
        'home_first_fresh_mount': next((sample for sample in raw if sample['scenario'] == 'home' and sample['cache'] == 'cold'), None),
        'summary': summary, 'samples': raw}
    (args.output / 'runtime.json').write_text(json.dumps(report, indent=2) + '\n')
    lines = ['# Simulator runtime baseline', '', f"Captured {started.date()} using {device['name']} ({device['runtime']}).",
        '', ('Debug + Patrol, populated local PostgreSQL/API, catalogue posters. Five repetitions per condition.' if completion.get('database_manifest') else 'Debug + Patrol, fictional 25ms HTTP, no poster images. Five repetitions per condition.'),
        'Cold/warm refers to selected service caches in one running process, not OS launch. No speedup claimed.',
        ('**Home:** only the first mount is fully fresh at the screen level. Later cold rows retain its session snapshot.' if report['home_first_fresh_mount'] else f'**Scope:** {args.scenario} only; no Home samples.'), '',
        '| Screen | Cache | Useful median / p95 ms | Settled median ms | UI / raster p95 ms | Frames over budget / observed | Load requests | Peak RSS MiB |',
        '|---|---|---:|---:|---:|---:|---|---:|']
    def number(value): return f'{value:.1f}' if value is not None else 'unavailable'
    for item in summary:
        lines.append(f"| {item['scenario']} | {item['cache']} | {number(item['useful_content_median_ms'])} / {number(item['useful_content_p95_ms'])} | {number(item['settled_median_ms'])} | {number(item['build_p95_ms'])} / {number(item['raster_p95_ms'])} | {item['frame_budget_exceeded']} / {item['frames_observed']} | {item['requests_load']} | {number(item['rss_peak_median_mib'])} |")
    lines += ['', 'Recorded offline-fixture endpoint failures:', '',
        *[f'- `{endpoint}`: {dict(statuses)}' for endpoint, statuses in failures.items()], '',
        'Raw timings, frames, endpoint counts, memory, display and SDK metadata are in [runtime.json](runtime.json).', '',
        'Limitations:', '', *['- ' + limitation for limitation in report['limitations']], '',
        'Not measured: OS cold launch, Firebase/auth bootstrap, production backend latency, physical-device profile performance,',
        ('Chat/search, Social group-membership stress, native foreground resume/account switching and retained heap after GC.' if args.scenario == 'social' else 'Profile/gallery, social/chat/search, native foreground resume or account switching, retained heap after GC and photo-gallery stress.'), '']
    (args.output / 'README.md').write_text('\n'.join(lines))
    print(f'Saved {len(raw)} complete samples and summary: {args.output / "README.md"}')


if __name__ == '__main__':
    main()
