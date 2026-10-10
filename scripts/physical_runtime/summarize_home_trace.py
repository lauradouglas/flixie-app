#!/usr/bin/env python3
"""Summarize a validated populated-Home capture; all times are milliseconds."""
import argparse
import json
import statistics
from pathlib import Path


def summarize(report):
    assert report['complete'] and report['mode'] == 'release'
    rows = []
    for sample in report['samples']:
        assert sample['scenario'] == 'signed_in' and sample['library_size'] == 20
        events = sample['home_trace']
        def mark(phase):
            return next(e['atUs'] for e in events if e['phase'] == phase and e['kind'] == 'mark')
        def span(phase):
            start = next(e for e in events if e['phase'] == phase and e['kind'] == 'start')
            end = next(e for e in events if e['id'] == start['id'] and e['kind'] == 'end')
            return (end['atUs'] - start['atUs']) / 1000
        entry = mark('capture.dart-entry')
        mounted = mark('home.mounted')
        first = mark('home.plans.first-frame')
        row = {'repetition': sample['repetition'],
               'dart_to_home_mount_ms': (mounted-entry)/1000,
               'dart_to_plan_frame_ms': (first-entry)/1000,
               'home_mount_to_plan_frame_ms': (first-mounted)/1000,
               'profile_ms': span('profile'),
               'plan_preferences_ms': span('home.plans.preferences'),
               'initial_plan_load_ms': span('home.plans.load'),
               'home_mount_to_all_plan_loads_done_ms': (max(e['atUs'] for e in events if e['phase'] == 'home.plans.load' and e['kind'] == 'end')-mounted)/1000}
        for source in ['direct', 'group']:
            phase = f'api.home-plans-{source}'
            response = next(e for e in events if e['phase'] == phase+'.response')
            assert response['status'] == 200
            row[source+'_transport_ms'] = span(phase+'.transport')
            row[source+'_decode_ms'] = span(phase+'.decode')
            row[source+'_server_ms'] = response['appMs']
            row[source+'_data_ms'] = response['dataMs']
        rows.append(row)
    assert len(rows) >= 5
    return {'request_counts': [s['requests'] for s in report['samples']], 'samples': rows, 'median_ms': {
        key: round(statistics.median(row[key] for row in rows), 3)
        for key in rows[0] if key != 'repetition'},
        'limits': 'Local fixture, release iPhone. First post-frame with cards excludes poster completion. Data includes service/repository wall time, not SQL alone. Parallel durations must not be added. No before/after speedup claim.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.write_text(json.dumps(summarize(json.loads(args.capture.read_text())), indent=2)+'\n')
