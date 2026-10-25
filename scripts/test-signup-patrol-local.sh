#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -ne 1 ]]; then
  echo 'Usage: scripts/test-signup-patrol-local.sh <dedicated-patrol-device-id>' >&2
  exit 2
fi
signup_device="$1"
signup_port="${SIGNUP_API_PORT:-3000}"
if [[ ! "$signup_port" =~ ^[0-9]+$ ]] || (( signup_port < 1 || signup_port > 65535 )); then
  echo 'SIGNUP_API_PORT must be a valid local port.' >&2; exit 2
fi
# Never reinstall an everyday simulator. This suite creates fictional accounts.
if [[ "$(uname -s)" == Darwin ]]; then
  xcrun simctl list devices available -j | python3 -c '
import json,sys
wanted=sys.argv[1]
rows=[d for devices in json.load(sys.stdin)["devices"].values() for d in devices]
assert any(d["udid"]==wanted and "patrol" in d["name"].lower() for d in rows), "Use a dedicated simulator with Patrol in its name"
' "$signup_device"
else
  echo 'This runner currently validates iOS Patrol simulators. Android execution requires its own dedicated-device guard.' >&2; exit 2
fi
curl --fail --silent --show-error --max-time 5 http://127.0.0.1:9099/ >/dev/null
curl --fail --silent --show-error --max-time 10 "http://127.0.0.1:$signup_port/utils/countries" >/dev/null
flutter test --no-pub test/signup_flow_test.dart test/social_auth_test.dart \
  test/social_auth_service_test.dart test/features/authentication/signup_journey_test.dart \
  test/features/authentication/onboarding_services_details_test.dart \
  test/features/authentication/referral_toggle_test.dart test/app/router/bookmark_signup_test.dart
exec scripts/test-patrol.sh -d "$signup_device" \
  --target patrol_test/signup_suite_local_test.dart \
  --dart-define="API_BASE_URL=http://127.0.0.1:$signup_port" \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
