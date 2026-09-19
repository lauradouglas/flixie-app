# Flixie After Hours — softened app icon pack

Refined editable F from the After Hours direction: corners softened with 3-unit quadratic curves on the original 100-unit canvas, including the detached lower-right bar. Original proportions, stroke thickness and separation are retained. Lilac **#B9A0FF** on midnight **#120A24**. Prepared for the existing Flutter iPhone/iPad and Android project. The Flixie wordmark is unchanged.

## Start here

- `stores/apple-app-store-1024.png` — opaque RGB, 1024 × 1024, square.
- `stores/google-play-512.png` — 512 × 512, sRGB RGBA with fully opaque pixels, below the 1 MB limit, square.
- `transparent/f-lilac-1024.png` — isolated lilac F with genuine alpha transparency.
- `masters/f-lilac-transparent.svg` — editable vector equivalent.
- `preview.png` — presentation only; the checkerboard is a preview of transparency, not part of any transparent master.

Transparent PNGs come in lilac, midnight, white and bone, at 256, 512, 1024 and 2048 px. They use the same padded square canvas as the Apple icon, not a tightly cropped bounding box. The SVGs contain paths, not fonts or embedded bitmap artwork.

## Apple / iPhone & iPad

`apple/AppIcon.appiconset` is the primary Xcode asset catalog. It contains 1024 px default, dark and grayscale tinted appearances plus `Contents.json`. Current Xcode generates the necessary smaller iPhone/iPad renditions. The default uses lilac on midnight; dark uses lilac on #0A0616; tinted is white on black for system tinting.

All catalog PNGs have **no alpha channel**. Apple applies the outer shape, so no rounded corners or exterior shadows are baked into these files. Do not substitute the isolated transparent F for the finished catalog/store icon.

To install in this project, replace `ios/Runner/Assets.xcassets/AppIcon.appiconset` with the supplied primary folder. The existing Xcode app-icon setting is already `AppIcon`. Keep the whole folder together, including its `Contents.json`.

`apple/legacy/AppIcon.appiconset` is an alternative classic catalog with all 19 iPhone/iPad/store slots (15 PNG files). Use it **instead of**, not inside, the primary catalog for an older toolchain. It only supplies the default appearance.

`apple/icon-composer-sources` contains the transparent foreground as SVG and PNG plus an opaque background PNG for an optional layered Apple Icon Composer workflow. These are source layers, **not a compiled .icon document**. For a custom Liquid Glass/clear appearance, import into Icon Composer, set the background to midnight, inspect the system appearances, and export a `.icon` document through Xcode. The supplied conventional asset catalog does not promise bespoke Liquid Glass material behaviour. No macOS, tvOS, watchOS or visionOS target was found in the requested mobile build scope, so those have not been invented.

## Android

Merge the **contents** of `android/res` into `android/app/src/main/res`:

- `mipmap-ldpi` through `mipmap-xxxhdpi`: legacy `launcher_icon.png`, 36 / 48 / 72 / 96 / 144 / 192 px; matching round legacy versions included.
- `mipmap-anydpi-v26`: adaptive icon XML for Android 8+.
- `mipmap-anydpi-v33`: adaptive icon XML including the monochrome layer for Android 13+ themed launchers.
- `drawable/after_hours_foreground.xml`: lilac vector on a transparent 108 dp canvas.
- `drawable/after_hours_monochrome.xml`: same silhouette as a white alpha mask.
- `values/after_hours_colors.xml`: opaque midnight background.
- `drawable/ic_stat_flixie.xml`: separate white-on-transparent notification symbol at 24 dp.

The current manifest already uses `android:icon="@mipmap/launcher_icon"`. The optional round asset can be enabled with `android:roundIcon="@mipmap/launcher_icon_round"` on the same application element. No round attribute is required for ordinary adaptive masking.

Foreground and monochrome layers use a **108 × 108 dp** canvas. Visible artwork is **41.04 × 48.64 dp**, centred at (54,54). Even its bounding rectangle corners fit inside the conservative central 66 dp safe circle. The outer area stays transparent for mask/parallax space. The background is an independent full-bleed opaque colour. Do not trim or add another inset to these layers. XML vector layers are resolution independent; matching 432 px PNGs and SVGs in `android/sources` are supplied for other tooling.

Android's themed colours are chosen by the system/launcher. The purple themed icon on the preview is illustrative; it is not a fixed alternate palette.

### Notification icon

This project currently points both Firebase's default notification icon and Flutter's local-notification initialisation at the launcher mipmap. When installing the pack, set Firebase's `com.google.firebase.messaging.default_notification_icon` resource to `@drawable/ic_stat_flixie` in the manifest, and use `AndroidInitializationSettings('ic_stat_flixie')` at both initialisation sites in `lib/core/auth/push_notification_service.dart`. A launcher icon with an opaque square is not the correct white alpha silhouette for a status-bar icon. Check any server-provided notification `icon` override as well.

### Existing Flutter icon-generation configuration

The current `pubspec.yaml` launcher-icon section points to missing `assets/icon/logo_icon.png`, and uses the text logo as adaptive foreground. It does **not** describe this pack. Do not run that existing configuration over these files.

These are prebuilt native resources: Flutter builds do not need `flutter_launcher_icons` to regenerate them. For a deterministic regeneration of this pack, use `tools/generate.cjs` with Node and `sharp`, then rerun `tools/verify.cjs`. If you later choose the Flutter generator instead, update its version/configuration for monochrome support and preserve the Apple appearance slots; a simple default run can overwrite those additions.

Installed into the Flutter iOS and Android projects on 18 September 2026, including matching native and Flutter splash screens and notification wiring. See `docs/app-logo-installation.md` in the app repository for current integration and store-release instructions. The descriptions of the previous project configuration above are historical migration notes.

## Validation

- SVG-derived exports preserve the softened source paths; only centring, scale and colour vary by platform.
- All PNG sizes and catalog references checked, including alpha rules and Google Play file size.
- Adaptive foreground alpha checked against the 66 dp safe circle.
- Primary Apple catalog compiled with Xcode 27 `actool` for iPhone + iPad, deployment target iOS 13. The sandbox emitted simulator-service warnings, but catalog compilation completed successfully and produced `Assets.car` and icon renditions. This is not a simulator or signed-app test.
- Android resources compiled and linked against API 36 using `aapt2` in an isolated validation package.
- Small sizes and light/dark presentations visually inspected. A real launcher/device preview after installation remains the final check for OS effects, wallpaper tint and icon caching.

The exports are actual build assets, not AI-generated mockups. No App Store upload, signed release build or live app icon change is claimed.

## Sources

- [Apple asset catalog configuration](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)
- [Apple app icon design guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Android adaptive icons and monochrome layers](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
- [Google Play icon size, format and masking](https://developer.android.com/distribute/google-play/resources/icon-design-specifications)

## Rebuilding the files

The included scripts use Node.js and `sharp` (tested with the bundled runtime). From a directory where `sharp` resolves:

```sh
node tools/generate.cjs
node tools/verify.cjs
```

The generator writes only inside this pack, not into your native app folders. The exact geometric definition is retained in the generator and SVG masters. Preserve padding and aspect ratio when exporting variants.
