#!/bin/bash
# Native process-death regression; deliberately bypasses Orchestrator's data reset.
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:?Pass the dedicated emulator serial}"
adb="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
avd="$($adb -s "$device" shell getprop ro.boot.qemu.avd_name | tr -d '\r')"
case "$avd" in Flixie_Patrol*) ;; *) echo 'Use the dedicated Flixie_Patrol emulator.' >&2; exit 1 ;; esac
curl --fail --silent http://127.0.0.1:9099/ >/dev/null
"$adb" -s "$device" install -r build/app/outputs/apk/debug/app-debug.apk
"$adb" -s "$device" install -r build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
for phase in seed restore restore logout signedOut; do
  "$adb" -s "$device" shell am force-stop com.flixie.app
  output="$($adb -s "$device" shell am instrument -w \
    -e class com.flixie.app.AuthSessionPersistenceTest \
    -e authPhase "$phase" com.flixie.app.test/androidx.test.runner.AndroidJUnitRunner)"
  printf '%s\n' "$output"
  [[ "$output" == *'OK (1 test)'* ]] || exit 1
done
