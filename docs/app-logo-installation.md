# Flixie mobile logo installation — 18 September 2026

The softened After Hours F is installed in both mobile projects. Lilac #B9A0FF on midnight #120A24; the existing Flixie text wordmark is preserved.

## Installed surfaces

- iPhone/iPad app icon: default, dark and tinted appearances in Runner/Assets.xcassets/AppIcon.appiconset. Opaque 1024px inputs, system-applied masking.
- Android: legacy launcher sizes, round icons, adaptive icons (API 26+) and monochrome themed icons (API 33+).
- iOS native launch screen and Android native splash (including Android 12+ day/night): centred transparent F on midnight. Flutter loading screen continues with the same 192px canvas and retains session recovery/retry behaviour.
- About & Credits: F above the preserved original wordmark.
- Android foreground, background and scheduled notifications: white alpha silhouette `ic_stat_flixie`, including Firebase manifest defaults and all local notification paths. A keep rule protects the string-referenced resource from release shrinking.
- Existing general-purpose `assets/icon/flixie_icon_1024.png` updated; new transparent `flixie_f_transparent.png` added. Original text logo and third-party provider marks unchanged.

## Source and regeneration

Editable vectors: assets/brand/after-hours-f.svg and assets/brand/app-icon.svg. `scripts/refresh-brand-rasters.cjs` uses Node + sharp to refresh Flutter PNGs and native splash rasters. Native launcher resources come from output/flixie-after-hours-app-icons-softened. Its tools/generate.cjs and tools/verify.cjs regenerate and validate the export pack; copy the Apple catalog and Android res contents into their native folders after regeneration.

The obsolete flutter_launcher_icons configuration was removed because it referenced a missing source and would lose appearance/themed layers. Do not run that older generator over the installed native resources. The legacy splash.jpg is retained as original wordmark artwork but no longer used by the loading screen.

## Store updates

### Apple

Use **App Store Connect**, not Certificates, Identifiers & Profiles in the Apple Developer portal. The icon is embedded in the uploaded build; there is no separate replacement image field for the normal iOS app icon.

1. Archive and upload a new build with a higher build number using the existing release process.
2. App Store Connect → Apps → Flixie → select the iOS version under Distribution → Build → select that processed build.
3. Complete the version submission and submit for review. The public icon follows the released version. TestFlight uses the uploaded build.
4. Refresh any screenshots or previews containing the old symbol. If custom product pages or icon experiments exist, review their artwork separately.

Reference: https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon

### Google Play

1. Play Console → Flixie → Grow users → Store presence → Main store listing → Graphics → App icon.
2. Upload `output/flixie-after-hours-app-icons-softened/stores/google-play-512.png` (512 × 512 RGBA PNG, opaque artwork, under 1 MB). Save and submit the listing changes for review through Publishing overview; publish after approval if managed publishing is enabled.
3. Upload a new Android App Bundle with a higher version code through the desired testing/production track. This updates installed launcher icons and splash screens; the listing image alone cannot do that.
4. Check localized/custom listings and active store-listing experiments for separately overridden icons, and replace old-symbol feature graphics/screenshots where present.

Reference: https://support.google.com/googleplay/android-developer/answer/9866151?hl=en-GB

## Verification and limits

Installed Apple asset catalog compiled successfully with actool for iPhone/iPad; installed Android resources compiled and linked against API 36 with aapt2. Focused Dart analysis passed. Startup and notification tests passed, plus splash layout checks on small/large phones, landscape and tablet at 200% text scaling.

No signed release build was uploaded or published. Real-device launcher caching, system tinting and notification delivery should be checked on the next install. A custom layered Liquid Glass/Icon Composer document is not included; the supplied Apple catalog contains conventional default/dark/tinted artwork.
