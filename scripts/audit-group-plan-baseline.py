#!/usr/bin/env python3
"""Audit Group Watch Plan captures against fixed local fixture endpoint budgets."""
import argparse
from collections import Counter
import json
from pathlib import Path


def budget(plan_reads=1):
    return {'GET /groups/user/runtime-fixture-0': 1, **{
        f'GET /groups/runtime-plan-group-{i}/{kind}': plan_reads if kind == 'requests' else 1
        for i in range(4) for kind in ('requests', 'members')}}


def audit(report, *, before):
    samples = report.get('samples', [])
    expected_keys = {('group_watch_plan', cache, i) for cache in ('cold', 'warm') for i in range(1, 6)}
    keys = {(s['scenario'], s['cache'], s['repetition']) for s in samples}
    errors = []
    if not report.get('method', {}).get('complete') or len(samples) != 10 or keys != expected_keys:
        errors.append('Incomplete or duplicate sample set')
    expected_stages = {'past': {}, 'active': {}, 'refresh': budget(),
                       'refresh_burst': budget(2 if before else 1), 'open_detail': budget(), 'back': {}}
    total = Counter(budget())
    for stage in expected_stages.values():
        total.update(stage)
    for sample in samples:
        if sample.get('requests_load') != budget():
            errors.append('Initial endpoint budget differs')
        stages = sample.get('group_stages', {})
        if set(stages) != set(expected_stages):
            errors.append('Missing or unexpected journey stage')
        for name, expected in expected_stages.items():
            stage = stages.get(name, {})
            if stage.get('requests') != expected or stage.get('settled_us', 0) <= 0:
                errors.append(f'Invalid stage {name}')
        if sample.get('requests_total') != dict(total):
            errors.append('Total endpoint budget differs')
        if sample.get('response_statuses') != {k: {'200': v} for k, v in total.items()} or sample.get('transport_errors'):
            errors.append('HTTP/transport accounting differs')
    return {'complete': not errors, 'samples': len(samples),
            'requests_per_sample': sum(total.values()),
            'tracked_requests': sum(sum(s.get('requests_total', {}).values()) for s in samples),
            'refresh_burst_reads': sum(expected_stages['refresh_burst'].values()), 'errors': errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--before', action='store_true')
    args = parser.parse_args()
    result = audit(json.loads((args.capture / 'runtime.json').read_text()), before=args.before)
    (args.capture / 'group-audit.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    if not result['complete']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
