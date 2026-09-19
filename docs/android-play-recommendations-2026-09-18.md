# Android Play recommendations — 18 September 2026

## Changes

- Use a local copy of firebase_app_check 0.3.2+10 with only its Android
  SafetyNet dependency and activation branch removed. Play Integrity remains
  the release provider. See third_party/firebase_app_check/FLIXIE_PATCH.md.
- Explicitly enable Flutter edge-to-edge on Android, use a transparent
  navigation bar, and stop hiding the status bar in all four launch themes.
- Add portrait/landscape authentication tests with gesture and three-button
  navigation insets, including side cutout padding.

## Verification

- Gradle releaseRuntimeClasspath dependencyInsight: no SafetyNet dependency.
- App Check release Java compilation and app release resource processing pass.
- 20 focused Flutter tests pass; changed Dart files pass analysis.
- Removed the 8.1 GB regenerable Runner Xcode DerivedData cache; retained
  release archives, source and emulator data. After rebuilding, free space was
  approximately 5.3 GB.
- Debug APK built and installed on Pixel 9 Pro emulator (Android 17), using
  the local backend at 10.0.2.2:3000 and the existing signed-in account.
- Visually checked Home and Search with gesture/three-button navigation,
  keyboard opening and dismissal, and landscape. Found Search extending under
  the landscape side navigation bar; added side SafeArea protection to the
  shared shell, rebuilt, and confirmed the corrected Home/Search layout.
- Restored portrait/automatic rotation and gesture navigation. No signed Play
  bundle was uploaded. This debug run does not verify Play Integrity issuance.

Before publishing, run a release build on an Android device: check login,
signup, keyboard appearance/dismissal, bottom navigation and sheets in portrait
and landscape with both navigation modes. Install through a Play internal
testing track to verify real Play Integrity token issuance. Check older Android
as well as Android 15/16. Play Console may retain warnings for version 64 until
a replacement bundle is analysed; these changes do not guarantee every static
edge-to-edge warning from the Flutter engine or third-party plugins disappears.
