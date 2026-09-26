#!/usr/bin/env bash
# Compatibility entry point: preserve the existing two-draft default.
set -euo pipefail
export DEBUG=false FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_OPT_OUT_USAGE=1
cd "$(dirname "$0")/.."
set -a
[[ ! -f .play-store.env ]] || source .play-store.env
set +a
: "${BUILD_NUMBER:?Set BUILD_NUMBER above every version code already uploaded to Play}"
exec bundle exec fastlane android draft "build_number:$BUILD_NUMBER" "track:${PLAY_STORE_TRACK:-both}"
