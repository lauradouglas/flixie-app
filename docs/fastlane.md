# Mobile deployments with Fastlane

Run commands from the repository root. Install Ruby and Bundler, then run
the following setup once (on this Mac, use Homebrew Ruby):

```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
bundle config set --local path vendor/bundle
bundle install
```

The project-local install path avoids permission errors writing to Homebrew's
shared gems, including `plugins/rdoc_plugin.rb`. `.bundle/` and `vendor/bundle/`
are ignored by Git. Use the same Ruby PATH for the commands below.
The Gemfile pins Fastlane; commit Gemfile.lock when updating it.
Flutter and the platform SDKs must already be installed. iOS needs macOS, Xcode,
CocoaPods and the existing distribution certificate/provisioning profile for
`com.flixie.flixieApp` (team `4T69VPQXW6`). Configure signing in Xcode first.
Fastlane reuses Flutter/Xcode signing; it does not create certificates or use Match.

Copy `fastlane/.env.example` to `fastlane/.env` and fill in the credential paths.
Keep keys outside this repository. Environment variables can also be supplied by
CI. For Apple, create an App Store Connect team API key with access to upload
builds (App Manager), and set its key ID, issuer ID and downloaded `.p8` path.
For Google, use the existing Play service account with permissions for the desired
tracks. Enable the Google Play Android Developer API. The local `.play-store.env`
file is loaded only by the legacy script; direct lanes use `fastlane/.env` or
exported environment variables.

Both platforms require `.firebase.json`. Android also needs
`android/app/google-services.json`, `android/key.properties` and its upload
keystore. iOS requires `ios/Runner/GoogleService-Info.plist`.

Choose BUILD_NUMBER above every build already uploaded to the relevant store;
these lanes deliberately require an explicit number. Replace 123 below with that
number. Marketing version comes from `pubspec.yaml`. No tracked version bump is
made. Run relevant app regression checks before creating a release.

```bash
# Signed artifacts only
bundle exec fastlane ios build build_number:123
bundle exec fastlane android build build_number:123

# Build and upload to App Store Connect / TestFlight
bundle exec fastlane ios beta build_number:123

# Build and upload an internal draft (not yet available to testers)
bundle exec fastlane android draft build_number:123

# Internal and production drafts in one run
bundle exec fastlane android draft build_number:123 track:both

# Retry production promotion after a successful internal upload; no rebuild
bundle exec fastlane android promote build_number:123
```

Apple uploads skip waiting for processing and do not submit for App Review or
external TestFlight review. Existing automatic internal TestFlight groups may
receive processed builds. Finish tester distribution or App Store submission in
App Store Connect. Google uploads always create drafts; review and roll out in
Play Console. Store descriptions, screenshots and changelogs are left untouched.
A successful upload is not confirmation that store processing or review passed.
If an upload succeeded, do not rebuild and upload that number again: inspect it
in the store console. Use the promotion lane for partial two-track failures.

Artifacts: `build/ios/ipa/*.ipa` and
`build/app/outputs/bundle/release/app-release.aab`. Remove stale IPA files if
Fastlane reports multiple matches. Builds explicitly use `lib/main.dart` and the
production HTTPS API, preserving the Xcode release guard after Patrol testing.
This tooling does not retire support for iOS 1.0.0 build 70.

## Store screenshots

The screenshot lanes capture these eight screens, in order: Home, Alex River's
profile, Watchlist, an Alien Watch Plan with Jamie, the Drama community,
Interstellar (movie 157336), The Newsroom (show 15621), and the rating sheet.
They use the production screens, theme and main navigation with fictional
test-only accounts and isolated API responses. Firebase login and the live
backend are not started. Public TMDB artwork needs internet access. The fixture
copy is English (en-GB), dark mode. The capture app uses the same purple
root backdrop as production so transparent routes do not render black. Shared
fictional friend ratings populate Home, Watchlist and movie details consistently.
The Alien plan is scheduled three days ahead at 19:30. Provider offers are
illustrative UK purchase data, not a live availability check.

A separate macOS composition step adds headlines, the official text wordmark
and a subtle rounded frame using the bundled Manrope font and AppKit. It
contains the full screenshot at its original aspect ratio and exports the same
canvas dimensions as the native PNG; it does not repaint app content. No
ImageMagick, downloaded device frames or image-generation service is needed.
Headlines and upload order are configured in `fastlane/ScreenshotPresentation.json`.
The native originals remain untouched.

To refresh only the two movie images while preserving every other PNG:

```bash
python3 scripts/store-screenshots.py ios --scenes 06-interstellar 08-rating
python3 scripts/store-screenshots.py android --scenes 06-interstellar 08-rating
```

Selective capture requires an existing validated full set.

Capture commands run from **flixie-app/**, using the Ruby setup above:

```bash
# Capture iPhone and iPad screenshots locally. No store credentials needed.
bundle exec fastlane ios screenshots

# Capture one dedicated iOS simulator instead (UDID from simctl list devices).
bundle exec fastlane ios screenshots device:DEDICATED_SIMULATOR_UDID

# Boot the Flixie_Patrol AVD in Android Studio first, then capture Android.
bundle exec fastlane android screenshots

# Capture real tablet layouts into separate Google Play categories.
bundle exec fastlane android screenshots type:sevenInchScreenshots
bundle exec fastlane android screenshots type:tenInchScreenshots

# Or select a booted dedicated emulator explicitly.
bundle exec fastlane android screenshots device:emulator-5554
```

Configure devices in `fastlane/ScreenshotConfig.json`. The default iOS devices
are a dedicated iPhone 17 Pro Max and 13-inch iPad Pro, using the installed iOS
26.5 runtime. The runner creates and boots those named simulators if necessary.
Change `device_type`/`runtime` to identifiers from `xcrun simctl list devicetypes`
and `xcrun simctl list runtimes` when using a different Xcode installation.
Android uses the existing dedicated **Flixie_Patrol** AVD; change `android.avd`
to another dedicated AVD if needed. Android requires SDK platform-tools (`adb`
on PATH), the pinned Patrol CLI, and the JDK/SDK described in `docs/testing.md`.
The capture lane clears Fastlane’s Bundler environment for the SDK subprocess
so Flutter can use the separately installed CocoaPods.
Capture devices must be named **Flixie Screenshots…** / **Flixie Patrol** on iOS,
or **Flixie_Screenshots…** / **Flixie_Patrol…** on Android: Patrol reinstalls the
app. The runner serializes concurrent capture commands because Patrol generates
a shared test bundle. Avoid running other Patrol tests during capture.

Use the dedicated `Flixie_Patrol` AVD with hardware graphics (`-gpu host`).
The 1080×1920 capture completed successfully. A taller-display retry hit a
launcher ANR, and an API 35 fallback failed instrumentation startup; both
failed runs left the successful set untouched. Android temporarily uses the configured `size` (1080×1920) so native
captures meet [Google Play's screenshot size/aspect-ratio requirements](https://support.google.com/googleplay/android-developer/answer/9866151).
The phone density is 420 dpi. Tablet configuration lives under `android_tablets`:
7-inch uses 900×1600 at 240 dpi (600 dp wide), and 10-inch uses 1440×2560
at 280 dpi (about 823 dp wide). These are native tablet-layout captures, not
enlarged phone images. Each tablet category has its own capture manifest;
the presentation validator checks all three sets independently. The previous size and density overrides
are restored after capture. Native screenshots are
saved as lossless 24-bit RGB PNGs; removing a fully opaque alpha channel preserves
every RGB pixel. Transparent captures fail instead of being altered.

The test waits for page content and artwork decoding, then contacts a temporary
authenticated localhost server. That server saves a native PNG with `simctl`
or `adb screencap` before allowing navigation to the next screen. Android captures also check native WindowManager focus for system error dialogs.
A failed run
does not replace the previous complete device set. iOS status chrome is set to
9:41/full battery during capture and the override is cleared afterwards.

Inspect the PNGs before uploading:

- iOS: `fastlane/screenshots/en-GB/<device>-01-home.png` through `08-rating.png`.
- Android: `fastlane/metadata/android/en-GB/images/` contains separate
  `phoneScreenshots/`, `sevenInchScreenshots/`, and `tenInchScreenshots/` sets.
- Capture manifests: `fastlane/screenshot-manifests/<platform>/`.
- Failed native test logs: `build/store-screenshots/`.

Generated images and manifests are ignored by Git. iOS identifies display
families from the native image dimensions. Each Android screenshot category
should contain just one eight-image device set; remove an older device's images
and corresponding manifest if changing devices. For iOS, remove the PNGs and
matching manifest to retire an old device set.

Generate the eight-image presentation per device after capture:

```bash
bundle exec fastlane ios prepare_screenshots
bundle exec fastlane android prepare_screenshots
```

Inspect `fastlane/store-presentation/review.html` and the full-resolution PNGs in
`fastlane/store-presentation/en-GB/`. The upload order is Home → friends’ movie
ratings → Watchlist → Watch Plan → personal rating → TV progress → Community →
Profile. Android uses the same order with its native captures. Its movie-detail
headline highlights where to watch, since friends’ ratings sit below the
fold on that display. Android files are generated
under `fastlane/store-presentation-android/en-GB/images/phoneScreenshots/`, with
its own `review.html`. Each output is opaque 24-bit RGB and retains the native dimensions.
The manifest hashes every input, headline configuration, font and output; stale
or edited presentations fail validation instead of silently reaching the store.
After recapturing or changing copy, rerun `prepare_screenshots` and review it.

**Current 2.0 workflow: show the finished iPhone, iPad and Android sets to the user and
obtain approval before uploading.** Generation never uploads or submits.
On 2 October 2026, the user approved the Apple set; all eight iPhone and eight
iPad images were uploaded to editable version 2.0 and their order verified.
The user subsequently approved the Android phone set and requested both tablet
sizes be uploaded together before submitting the listing for review. The user
then took over Play Console selection and submission: prepare the tablet files
and stage them in the asset library only. Do not commit or submit the listing
on their behalf under that revised instruction. Both tablet asset uploads completed on 3 October 2026: eight 900×1600
7-inch PNGs and eight 1440×2560 10-inch PNGs. All 16 Google SHA-256
checksums match the local files. Both native capture runs passed; the 10-inch
run required a cold restart of the dedicated emulator after hung virtual CPU
threads. The final presentation contains 24 images, and all eight approved
phone PNGs remain byte-identical. The user owns selection and submission. The service account cannot commit listing edits; asset-only staging leaves
the temporary API edit uncommitted so the user can select images in Console.

Upload is a separate command, using the store credentials in `fastlane/.env`:

```bash
bundle exec fastlane ios upload_screenshots
bundle exec fastlane android upload_screenshots
```

Upload validates complete eight-screen manifests and PNG dimensions first.
The iOS lane replaces the listing's screenshot collection with the locally
prepared presentation sets; it skips binary/metadata upload and does not submit for review.
It targets the editable App Store version, not the TestFlight build. Android
uploads screenshots only, skipping bundles, descriptions, other artwork and
changelogs. Existing release lanes still leave all listing screenshots untouched.
These capture lanes do not prove live login or backend behaviour.

Focused screenshot checks:

```bash
python3 scripts/test-store-screenshots.py
python3 scripts/test-prepare-store-screenshots.py
ruby scripts/test-fastlane.rb
flutter test test/store_screenshot_fixture_test.dart
```

No automatic deployment workflow is enabled. These lanes can later be called
from CI once signing and secrets are configured there.

Focused tooling checks (no builds, credentials or uploads):

```bash
ruby scripts/test-fastlane.rb
bash scripts/test-ios-release-guard.sh
```

References: [Fastlane setup](https://docs.fastlane.tools/getting-started/ios/setup/),
[TestFlight](https://docs.fastlane.tools/actions/upload_to_testflight/),
[Google Play](https://docs.fastlane.tools/actions/upload_to_play_store/).

## Signed IPA entitlement verification

The iOS build lane runs `python3 scripts/validate-ios-ipa.py <ipa>` before upload.
It checks the signed application, not just the provisioning profile, for Apple
sign-in, production APNs, associated domains, app identity and disabled debugging.
An unsigned archive can export successfully while losing capabilities; do not
assume export success proves these entitlements survived. Build 89 demonstrated
this failure and was superseded by explicitly signed build 90.

## TestFlight build 93 — 5 October 2026

Uploaded version 1.0.1 build 93 successfully at 13:09 UTC. Includes the
Watchlist Home fallback for direct widget launches. All 69 focused navigation,
foreground notification, inbox and plan-refresh tests passed. The standard lane
hit stale automatic signing profiles; the archive was rebuilt without signing,
then explicitly signed and exported using the existing build-92 distribution
profiles. Both final IPA signatures, build numbers, shared widget App Group,
production APNs, Apple sign-in and associated-domain entitlements were verified
through Security.framework. No external review or App Store submission was made.
The friend-plan notification category fix is in the backend and remains local;
this app upload does not deploy it.

## TestFlight build 96 — 5 October 2026

Uploaded version 1.0.1 build 96 successfully following the user's TestFlight
request. Built the current working tree with `lib/main.dart` and the production
HTTPS API. All 48 focused sign-in, notification navigation, Watchlist navigation
and widget-sync tests passed, alongside 15 Fastlane tests and the iOS release
guard checks. The archive was explicitly signed with the existing distribution
identity and build-92 profiles, then exported. Verified both app and widget
signatures, build numbers and shared App Group, plus the app's production APNs,
Apple sign-in and associated-domain entitlements. Upload success does not by
itself confirm Apple processing. No external review or App Store submission was
made, and this upload does not deploy backend changes.

## TestFlight and Google Play build 97 — 5 October 2026

Uploaded version 1.0.1 build 97 to TestFlight and committed Android version code
97 to the production track for Google review at the user's explicit request.
Includes the person-heart background fix, stale group-invitation membership
navigation, own-activity reaction controls, searchable three-column ratings grid,
preference explanations, watchlist loading labels/light separators, watch-history
menu contrast, Home icon buttons (original Trailer styling retained), and Watch
Plan movie links. Pick for us details navigation was already fixed locally and
its 18 focused checks passed. The initial 92 focused release checks, 28 Watch Plan
checks, 15 Fastlane tests and iOS release guards passed. Focused Dart analysis
passed for the final Watch Plan changes. Full regression/Patrol was not run.

Built the current working tree with lib/main.dart and the production API.
The final iOS archive was explicitly signed using the existing distribution
identity and profiles, then exported. Both app/widget signatures and build
numbers, production APNs, Apple sign-in, associated domains and App Shortcuts
were verified before upload. Apple processing and Google review are separate
from upload success. No Apple App Store review submission, listing asset changes,
backend deployment or production database changes were performed.

## External TestFlight build 98 — 6 October 2026

At the user's request, uploaded 2.0.1 (98) for assignment to external testers.
App Store Connect reports the released App Store version as 2.0, so an iOS
build-name override of 2.0.1 was necessary; 1.0.2 would remain below the released
version. The tracked pubspec version was not changed. Build 97 was VALID before
this upload. All 75 focused app checks, 15 Fastlane checks and the iOS release
guards passed. Built the current working tree with lib/main.dart and production
API configuration, manually signed with the existing distribution identity and
profiles, exported and verified both app/widget versions and signatures, required
production entitlements and App Shortcuts. Apple accepted the upload at 15:13 UTC.
Processing and external beta review remain separate. No external group assignment,
beta-review submission, App Store submission, Android upload or backend deployment
was performed; the user requested a build to assign themselves.

## Production review submission

Explicitly authorised production submissions can use the following lanes. Use a new build number above all store uploads and set RELEASE_VERSION to the intended marketing version. Android submission sends a completed production rollout for review; it does not fall back silently to an unsubmitted edit. Apple submits for review and retains manual release after approval. Existing screenshots are preserved.

```bash
RELEASE_VERSION=2.0.1 bundle exec fastlane android submit build_number:99
RELEASE_VERSION=2.0.1 bundle exec fastlane ios submit build_number:99
```

Play credentials must be exported or configured in fastlane/.env. Android notes live in fastlane/release-metadata/android/en-GB/changelogs/<build>.txt. Apple notes are supplied by the submission lane. Do not retry a successful upload with the same build number; inspect store state first.

For the same signed IPA in TestFlight and App Review, upload once, wait for processing, then select the uploaded build without uploading again:

```bash
RELEASE_VERSION=2.0.1 bundle exec fastlane ios beta build_number:99 ipa:build/ios/ipa/flixie_app.ipa wait:true
RELEASE_VERSION=2.0.1 bundle exec fastlane ios submit build_number:99 ipa:build/ios/ipa/flixie_app.ipa uploaded:true
```

Release 2.0.1 (99) was submitted to Google Play production and Apple review on 10 October 2026 and made available to internal TestFlight testers.
