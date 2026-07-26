#!/bin/sh
set -e

# Xcode scheme pre-actions do not consistently inherit values from the
# target's xcconfig. Load Flutter's complete generated environment before
# invoking the framework preparation step.
flutter_environment="${SRCROOT}/Flutter/flutter_export_environment.sh"
if [ -f "${flutter_environment}" ]; then
  . "${flutter_environment}"
fi

# Retain a fallback for projects generated without the shell environment file.
if [ -z "${FLUTTER_ROOT:-}" ]; then
  generated_config="${SRCROOT}/Flutter/Generated.xcconfig"
  if [ -f "${generated_config}" ]; then
    FLUTTER_ROOT="$(sed -n 's/^FLUTTER_ROOT=//p' "${generated_config}" | head -n 1)"
    export FLUTTER_ROOT
  fi
fi

flutter_backend="${FLUTTER_ROOT:-}/packages/flutter_tools/bin/xcode_backend.sh"
if [ ! -f "${flutter_backend}" ]; then
  echo "error: Flutter SDK could not be located. Run 'flutter pub get' before archiving." >&2
  exit 1
fi

/bin/sh "${flutter_backend}" prepare
