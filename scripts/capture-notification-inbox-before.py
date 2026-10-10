#!/usr/bin/env python3
"""Run the unmodified archived inbox against the current isolated HTTP fixture."""
import gzip
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
evidence = root / 'docs/performance/2026-10-09-notification-inbox-validation'
tests = root / 'test/features/profile/notifications'
legacy = tests / 'legacy_inbox.generated.dart'
runner = tests / 'baseline.generated_test.dart'
if legacy.exists() or runner.exists():
    raise SystemExit('Temporary baseline files exist; inspect them first.')
try:
    legacy.write_bytes(gzip.decompress((evidence / 'screen-before.dart.gz').read_bytes()))
    runner.write_text("""import 'package:flutter_test/flutter_test.dart';
import 'legacy_inbox.generated.dart' as legacy;
import 'journey.dart';
void main() {
  testWidgets('archived inbox polling and overlapping refresh', (tester) =>
    pollingJourney(tester, before: true, screen: () => const legacy.NotificationScreen()));
}
""")
    with (evidence / 'polling-before.log').open('w') as log:
        result = subprocess.run(['flutter', 'test', str(runner.relative_to(root))],
                                cwd=root, stdout=log, stderr=subprocess.STDOUT)
    raise SystemExit(result.returncode)
finally:
    legacy.unlink(missing_ok=True)
    runner.unlink(missing_ok=True)
