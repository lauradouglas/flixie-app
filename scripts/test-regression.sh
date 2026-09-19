#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter analyze lib test patrol_test
flutter test --coverage
