#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATROL_ANALYTICS_ENABLED=false
PATROL_BIN="${PATROL_BIN:-$HOME/.pub-cache/bin/patrol}"
if [[ ! -x "$PATROL_BIN" ]]; then
  echo "Install the pinned runner: dart pub global activate patrol_cli 4.8.0" >&2
  exit 1
fi
if [[ $# -eq 0 ]]; then
  echo "Pass a dedicated test device: scripts/test-patrol.sh -d <device-id>" >&2
  echo "Patrol uninstalls the app; do not use your everyday development device." >&2
  exit 1
fi
# Limit only test simulator builds to the host architecture (Flutter 3.44).
if [[ "$(uname -s)" == "Darwin" && -z "${XCODE_XCCONFIG_FILE:-}" ]]; then
  patrol_xcconfig="$(mktemp -t flixie-patrol)"
  trap 'rm -f "$patrol_xcconfig"' EXIT
  printf 'ARCHS[sdk=iphonesimulator*] = %s\n' "$(uname -m)" > "$patrol_xcconfig"
  export XCODE_XCCONFIG_FILE="$patrol_xcconfig"
fi
# Invalidate Flutter's native build cache on every regression run. Without a
# changed build define, incremental Xcode builds can reuse an older test bundle.
"$PATROL_BIN" test --dart-define="PATROL_BUILD_ID=$(date +%s)-$$" "$@"
