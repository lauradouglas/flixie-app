#!/usr/bin/env bash
# Focused cross-repository suite. Optional real-DB tests use fictional accounts.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "${1:-}" && "${1:-}" != "--local-db" ]]; then
  echo 'Usage: scripts/test-notifications.sh [--local-db]' >&2
  exit 2
fi
flutter test \
  test/notification_*_test.dart \
  test/foreground_*_test.dart \
  test/referral_notification_test.dart \
  test/watch_plan_notification_contract_test.dart \
  test/watch_plan_foreground_refresh_test.dart \
  test/watch_plan_reminder_policy_test.dart
(
  cd ../FlixieBE
  npm run test:notifications
  if [[ "${1:-}" == "--local-db" ]]; then
    npm run test:community-replies:e2e:local
    npm run test:watch-plans:e2e:local
    npm run test:group-watch-plans:e2e:local
  elif [[ -n "${1:-}" ]]; then
    echo 'Usage: scripts/test-notifications.sh [--local-db]' >&2
    exit 2
  fi
)
