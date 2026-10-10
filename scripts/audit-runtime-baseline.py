#!/usr/bin/env python3
"""Audit a completed runtime capture's request/response accounting and frozen source."""
import argparse
from collections import Counter
import json
from pathlib import Path


def audit(report, actual, expected, paths=None):
    gaps, errors, failures = [], [], []
    samples = report['samples']
    for sample in samples:
        key = {name: sample[name] for name in ('scenario', 'cache', 'repetition')}
        statuses, requests = sample['response_statuses'], sample['requests_total']
        delta = {path: requests.get(path, 0) - sum(statuses.get(path, {}).values())
                 for path in requests.keys() | statuses.keys()
                 if requests.get(path, 0) != sum(statuses.get(path, {}).values())}
        if delta:
            gaps.append({**key, 'request_response_differences': delta})
        if sample.get('transport_errors'):
            errors.append({**key, 'transport_errors': sample['transport_errors']})
        bad = {path: {status: n for status, n in counts.items() if int(status) >= 400 and n}
               for path, counts in statuses.items()}
        bad = {path: counts for path, counts in bad.items() if counts}
        if bad:
            failures.append({**key, 'response_failures': bad})
    actual_hashes = {item['path']: item['sha256'] for item in actual['files']}
    expected_hashes = {item['path']: item['sha256'] for item in expected['files']}
    scope = set(paths) if paths else actual_hashes.keys() | expected_hashes.keys()
    differences = [path for path in sorted(scope)
                   if path not in actual_hashes or path not in expected_hashes or
                   actual_hashes[path] != expected_hashes[path]]
    return {'samples': len(samples), 'scenarios': dict(Counter(s['scenario'] for s in samples)),
            'tracked_requests': sum(sum(s['requests_total'].values()) for s in samples),
            'transport_clean': not (errors or gaps), 'http_clean': not failures,
            'request_response_gaps': gaps, 'transport_errors': errors, 'response_failures': failures,
            'source_verification_scope': sorted(scope) if paths else 'all lib Dart files',
            'source_hashes_match': not differences, 'source_differences': differences}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--source-path', action='append', help='Verify specified source paths instead of all lib files')
    args = parser.parse_args()
    report = json.loads((args.capture / 'runtime.json').read_text())
    if not report['method']['complete']:
        raise SystemExit('Refusing to audit an incomplete capture as successful.')
    result = audit(report, json.loads((args.capture / 'repository.json').read_text()),
                   json.loads(args.source.read_text()), args.source_path)
    output = args.capture / 'transport-audit.json'
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    if not all(result[key] for key in ('transport_clean', 'http_clean', 'source_hashes_match')):
        raise SystemExit('Capture audit failed; retain the evidence and investigate.')


if __name__ == '__main__':
    main()
