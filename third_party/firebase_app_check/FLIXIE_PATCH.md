# Flixie Android compatibility patch

Source: FlutterFire `firebase_app_check` 0.3.2+10 from pub.dev, under the
included BSD license. Runtime sources are retained; examples/tests are omitted.

Changes are limited to Android: remove the deprecated
`firebase-appcheck-safetynet:16.1.2` dependency, its Java import and activation
branch. Unsupported providers fail explicitly. Play Integrity and Debug remain
available. Flixie selects Play Integrity in release builds.

The Dart and Apple implementations are unchanged, avoiding an unrelated
Firebase major upgrade during iOS review. Remove this local package and restore
a hosted dependency when upgrading the Firebase family to a compatible version
with upstream SafetyNet removal (0.4.0 or newer).
