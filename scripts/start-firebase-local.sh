#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
mkdir -p .local/firebase
args=(emulators:start --project demo-flixie-local --config firebase.local.json --only auth,firestore,storage --export-on-exit=.local/firebase/data)
if [[ -f .local/firebase/data/firebase-export-metadata.json ]]; then
  args+=(--import=.local/firebase/data)
fi
exec firebase "${args[@]}"
