#!/usr/bin/env python3
"""Controlled paired Group Insights memory investigation on a dedicated simulator."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import statistics
import subprocess
import sys
from urllib.request import urlopen
from runtime_ios_fixture import demo_firebase_plist

PHASES = ('baseline', 'mounted', 'unmounted', 'neutral_input', 'cache_cleared')
CONDITIONS = ('no_images', 'controlled_images')
VERSIONS = ('before', 'after')
OWNERS = {'_MemoryBeforeGroupInsightsTabState', 'GroupInsightReview', 'GroupInsightsResponse', 'GroupInsightsController', '_MemoryBeforeInsightReviewCardState', 'GroupInsightMovie', '_InsightReviewCardState', 'GroupInsightMember', '_GroupInsightsTabState'}



def audit(data):
    expected = {(version, condition, repetition) for version in VERSIONS
                for condition in CONDITIONS for repetition in range(1, 6)}
    visits = data.get('samples', [])
    rows = data.get('memory_samples', [])
    keys = lambda row: (row['version'], row['condition'], row['repetition'])
    errors = []
    if not data.get('complete') or len(visits) != 20 or {keys(v) for v in visits} != expected:
        errors.append('Missing/duplicate/incomplete visits')
    if len(rows) != 100 or {(keys(r), r['phase']) for r in rows} != {(k, p) for k in expected for p in PHASES}:
        errors.append('Missing/duplicate memory phases')
    for visit in visits:
        if visit.get('periods') != ['month', 'all', 'month', 'month', 'month']:
            errors.append('Incorrect period query order')
        budget = {'GET /groups/runtime-plan-group-0/insights': 5}
        if visit['requests'] != budget or visit['responses'] != {k: {'200': v} for k, v in budget.items()} or visit['transport_errors']:
            errors.append(f'Transport/request accounting failed: {keys(visit)}')
    dates = [int(row.get('date_last_gc') or 0) for row in rows]
    if any(t <= 0 for t in dates) or any(b <= a for a, b in zip(dates, dates[1:])):
        errors.append('GC observations lack distinct increasing timestamps')
    for row in rows:
        actual = row.get('actual_live_counts', {})
        if set(actual) != OWNERS or any(not isinstance(value, int) or value < 0 for value in actual.values()):
            errors.append('Missing/invalid direct live-instance counts')
        page = '_MemoryBeforeGroupInsightsTabState' if row['version'] == 'before' else '_GroupInsightsTabState'
        if row['phase'] == 'mounted' and actual.get(page) != 1:
            errors.append('Mounted owner query does not identify exactly one active page')
        if row['phase'] == 'mounted' and row['version'] == 'after' and actual.get('GroupInsightsController') != 1:
            errors.append('Mounted current page lacks exactly one controller')
        if row['image_cache_pending'] != 0:
            errors.append(f'Pending images at observation: {keys(row)} {row["phase"]}')
        if row['condition'] == 'no_images' and row['image_cache_bytes'] != 0:
            errors.append('Image-free control contains decoded images')
        if row['phase'] in ('baseline', 'cache_cleared') and (row['image_cache_bytes'] or row['image_cache_live']):
            errors.append('Cleared image control contains cached/live images')
        if row['condition'] == 'controlled_images' and row['phase'] == 'mounted' and row['image_cache_bytes'] <= 0:
            errors.append('Image condition rendered no decoded images')
    return {'complete': not errors, 'visits': len(visits), 'gc_observations': len(rows),
            'tracked_requests': sum(sum(v['requests'].values()) for v in visits), 'errors': errors}


def summarise(data):
    output = []
    for condition in CONDITIONS:
        for version in VERSIONS:
            group = [r for r in data['memory_samples'] if r['condition'] == condition and r['version'] == version]
            for phase in PHASES:
                rows = [r for r in group if r['phase'] == phase]
                med = lambda f: round(statistics.median(f(r) for r in rows) / 1048576, 4)
                counts = {}
                for name in {item['name'] for r in rows for item in r['owners']}:
                    values = [next((item['instances'] for item in r['owners'] if item['name'] == name), 0) for r in rows]
                    counts[name] = {'min': min(values), 'max': max(values)}
                baseline = {r['repetition']: r for r in group if r['phase'] == 'baseline'}
                output.append({'condition': condition, 'version': version, 'phase': phase,
                    'rss_median_mib': med(lambda r: r['rss_after_gc_bytes']),
                    'heap_median_mib': med(lambda r: r['memory_usage']['heapUsage']),
                    'external_median_mib': med(lambda r: r['memory_usage']['externalUsage']),
                    'image_cache_median_mib': med(lambda r: r['image_cache_bytes']),
                    'heap_delta_from_baseline_median_mib': med(lambda r: r['memory_usage']['heapUsage'] - baseline[r['repetition']]['memory_usage']['heapUsage']),
                    'rss_delta_from_baseline_median_mib': med(lambda r: r['rss_after_gc_bytes'] - baseline[r['repetition']]['rss_after_gc_bytes']),
                    'allocation_census': counts, 'actual_live_counts': {name: {'min': min(r['actual_live_counts'][name] for r in rows), 'max': max(r['actual_live_counts'][name] for r in rows)} for name in OWNERS}, 'retaining_paths': sum(len(r['retaining_paths']) for r in rows)})
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--order', choices=('no_images_first', 'images_first'), required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '--json']))
    device = next((d for ds in devices['devices'].values() for d in ds if d['udid'] == args.device), None)
    if not device or not any(word in device['name'].lower() for word in ('patrol', 'memory')):
        raise SystemExit('Use a dedicated named Patrol/Memory simulator; this runner reinstalls its app.')
    manifest = json.load(urlopen('http://127.0.0.1:3007/benchmark/manifest', timeout=3))
    if manifest.get('database') != 'flixie_runtime_fixture' or manifest.get('watchPlans', {}).get('groups') != 4:
        raise SystemExit('Refusing a database/group set other than the isolated fixture.')
    args.output.mkdir(parents=True, exist_ok=False)
    paths = list((root / 'lib').rglob('*.dart')) + [root / 'patrol_test/group_insights_memory_test.dart',
        root / 'patrol_test/support/group_insights_memory_before.dart',
        root / 'patrol_test/support/runtime_database_fixture.dart', Path(__file__).resolve()]
    hashes = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    (args.output / 'source.json').write_text(json.dumps(hashes, indent=2) + '\n')
    (args.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    with demo_firebase_plist(root), (args.output / 'patrol.log').open('w') as log:
        result = subprocess.run([str(root / 'scripts/test-patrol.sh'), '-d', args.device,
            '-t', 'patrol_test/group_insights_memory_test.dart', '--dart-define=API_BASE_URL=http://127.0.0.1:3007',
            '--dart-define=INSIGHTS_MEMORY_ORDER=' + args.order], cwd=root, stdout=log, stderr=subprocess.STDOUT)
    log = re.sub(r'\x1b\[[0-9;]*m', '', (args.output / 'patrol.log').read_text())
    if result.returncode or not re.search(r'Successful:\s*1', log) or not re.search(r'Failed:\s*0', log):
        raise SystemExit('Native capture did not pass. Preserve the log; no successful memory result recorded.')
    data = json.load(urlopen('http://127.0.0.1:3007/benchmark/results', timeout=10))
    (args.output / 'runtime.json').write_text(json.dumps(data, indent=2) + '\n')
    checks = audit(data)
    checks['source_hashes_match'] = all(hashlib.sha256((root / name).read_bytes()).hexdigest() == sha for name, sha in hashes.items())
    if data.get('method', {}).get('order') != args.order or data.get('method', {}).get('suite') != 'insights_memory':
        checks['errors'].append('Collector suite/order does not match')
    checks['complete'] = not checks['errors'] and checks['source_hashes_match']
    (args.output / 'audit.json').write_text(json.dumps(checks, indent=2) + '\n')
    if not checks['complete']:
        raise SystemExit('Memory audit failed; preserve results and investigate.')
    (args.output / 'summary.json').write_text(json.dumps(summarise(data), indent=2) + '\n')
    print(json.dumps(checks, indent=2))


if __name__ == '__main__':
    main()
