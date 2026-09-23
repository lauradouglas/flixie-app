#!/bin/sh
# Focused release-entry-point regression checks; does not build or sign an app.
set -eu
cd "$(dirname "$0")/.."
for target in lib/main.dart /project/lib/main.dart; do
  CONFIGURATION=Release FLUTTER_APPLICATION_PATH=/project FLUTTER_TARGET="$target" DART_DEFINES='' \
    sh scripts/validate-ios-release.sh
done
for target in patrol_test/test_bundle.dart /project/patrol_test/test_bundle.dart ''; do
  if CONFIGURATION=Release FLUTTER_APPLICATION_PATH=/project FLUTTER_TARGET="$target" DART_DEFINES='' \
    sh scripts/validate-ios-release.sh >/dev/null 2>&1; then
    echo "Release guard unexpectedly accepted: $target" >&2
    exit 1
  fi
done
CONFIGURATION=Debug FLUTTER_TARGET=patrol_test/test_bundle.dart sh scripts/validate-ios-release.sh
printf '%s\n' 'iOS release guard checks passed'
