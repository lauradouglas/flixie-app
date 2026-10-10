#!/usr/bin/env python3
"""Capture repository size metrics. These do not measure app speed.

Usage: python3 scripts/repo-baseline.py [output.json]
Existing snapshots are never overwritten.
"""
import datetime
import json
import hashlib
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
files = []
for path in sorted((root / 'lib').rglob('*.dart')):
    text = path.read_text()
    files.append({'path': path.relative_to(root).as_posix(),
                  'lines': len(text.splitlines()), 'bytes': path.stat().st_size,
                  'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
result = {
    'captured_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'kind': 'repository structure; not runtime performance',
    'revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
    'working_tree_dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True)),
    'dart_files': len(files), 'dart_lines': sum(f['lines'] for f in files),
    'over_500_lines': sum(f['lines'] > 500 for f in files),
    'over_1000_lines': sum(f['lines'] > 1000 for f in files),
    'largest_files': sorted(files, key=lambda f: (-f['lines'], f['path']))[:20],
    'files': files,
}
encoded = json.dumps(result, indent=2) + '\n'
if len(sys.argv) == 2:
    with Path(sys.argv[1]).open('x') as output:
        output.write(encoded)
elif len(sys.argv) == 1:
    print(encoded, end='')
else:
    raise SystemExit(__doc__)
