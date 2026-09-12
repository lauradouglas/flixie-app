#!/usr/bin/env bash
# Build and upload a draft release. Credentials stay outside the repository.
set -euo pipefail
# Google API debug logs can include authentication headers.
export DEBUG=false FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_OPT_OUT_USAGE=1
cd "$(dirname "$0")/.."
[[ ! -f .play-store.env ]] || source .play-store.env
: "${PLAY_STORE_KEY_FILE:?Set PLAY_STORE_KEY_FILE to your Google Play service-account JSON path}"
: "${BUILD_NUMBER:?Set BUILD_NUMBER above every version code already uploaded to Play}"
TRACK="${PLAY_STORE_TRACK:-both}"
case "$TRACK" in internal|production|both) ;; *) echo 'PLAY_STORE_TRACK must be internal, production or both' >&2; exit 1;; esac
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo 'BUILD_NUMBER must be a positive integer' >&2; exit 1; }
[[ -f "$PLAY_STORE_KEY_FILE" ]] || { echo 'Google Play key file not found' >&2; exit 1; }
command -v fastlane >/dev/null || { echo 'Install Fastlane before running this script' >&2; exit 1; }
UPLOAD_TRACK="$TRACK"
[[ "$TRACK" != both ]] || UPLOAD_TRACK=internal
flutter build appbundle --release --build-number="$BUILD_NUMBER" \
  --dart-define-from-file=.firebase.json \
  --dart-define=API_BASE_URL=https://flixie-api-fmcehvaecwdheccm.northeurope-01.azurewebsites.net
fastlane supply --package_name com.flixie.app \
  --json_key "$PLAY_STORE_KEY_FILE" \
  --aab build/app/outputs/bundle/release/app-release.aab \
  --track "$UPLOAD_TRACK" --release_status draft \
  --skip_upload_metadata true --skip_upload_images true \
  --skip_upload_screenshots true --skip_upload_changelogs true

if [[ "$TRACK" == both ]]; then
  fastlane supply --package_name com.flixie.app \
    --json_key "$PLAY_STORE_KEY_FILE" \
    --track internal --track_promote_to production --track_promote_release_status draft \
    --version_code "$BUILD_NUMBER" --release_status draft \
    --skip_upload_aab true --skip_upload_apk true \
    --skip_upload_metadata true --skip_upload_images true \
    --skip_upload_screenshots true --skip_upload_changelogs true
fi
