#!/bin/sh
# Prepare Xcode Archive after local simulator testing, without building twice.
set -eu
cd "$(dirname "$0")/.."
flutter build ios --release --config-only \
  --dart-define-from-file=.firebase.json \
  --dart-define=API_BASE_URL=https://flixie-api-fmcehvaecwdheccm.northeurope-01.azurewebsites.net
