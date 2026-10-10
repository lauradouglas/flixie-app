#!/usr/bin/env python3
"""Audit Group Insights period, refresh and exact HTTP work in populated captures."""
import argparse
import json
from pathlib import Path

PATH = '/groups/runtime-plan-group-0/insights'
KEY = 'GET ' + PATH

def audit(report):
    samples = report.get('samples', [])
    expected = {('group_insights', c, i) for c in ('cold', 'warm') for i in range(1, 6)}
    errors = []
    if not report.get('method', {}).get('complete') or len(samples) != 10 or {(s['scenario'], s['cache'], s['repetition']) for s in samples} != expected:
        errors.append('Missing/duplicate/incomplete samples')
    stages = {'all_time': ['all'], 'same_period': [], 'month': ['month'],
              'refresh': ['month'], 'refresh_burst': ['month']}
    # The screen leaves limit at the server default.
    def queries(periods): return [PATH + '?timeWindow=' + p for p in periods]
    # ApiClient already merges concurrent identical GETs in both versions.
    total = 5
    for sample in samples:
        if sample.get('requests_load') != {KEY: 1}: errors.append('Incorrect initial endpoint budget')
        actual = sample.get('insights_stages', {})
        if set(actual) != set(stages): errors.append('Missing/unexpected stage')
        for name, periods in stages.items():
            stage = actual.get(name, {})
            if stage.get('requests') != ({KEY: len(periods)} if periods else {}) or stage.get('queries') != queries(periods) or stage.get('settled_us', 0) <= 0:
                errors.append('Incorrect period/requests/timing: ' + name)
        periods = ['month'] + [p for ps in stages.values() for p in ps]
        if sample.get('insights_queries') != queries(periods): errors.append('Incorrect full query sequence')
        if sample.get('requests_total') != {KEY: total}: errors.append('Incorrect total request budget')
        if sample.get('response_statuses') != {KEY: {'200': total}} or sample.get('transport_errors'):
            errors.append('HTTP/transport accounting failed')
    return {'complete': not errors, 'samples': len(samples),
            'tracked_requests': sum(sum(s.get('requests_total', {}).values()) for s in samples), 'errors': errors}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    args = parser.parse_args()
    result = audit(json.loads((args.capture / 'runtime.json').read_text()))
    (args.capture / 'insights-audit.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    if not result['complete']: raise SystemExit(1)

if __name__ == '__main__': main()
