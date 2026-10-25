#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Extra arguments select the device. Android emulator uses host forwarding below.
host=127.0.0.1
if [[ "${FLIXIE_ANDROID_EMULATOR:-false}" == true ]]; then host=10.0.2.2; fi
exec flutter run --dart-define-from-file=.firebase.local.json \
  --dart-define="FIREBASE_EMULATOR_HOST=$host" \
  --dart-define="API_BASE_URL=http://$host:3000" "$@"
