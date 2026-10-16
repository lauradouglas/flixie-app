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

## TestFlight build 101 — 11 October 2026

Built and uploaded 2.0.1 (101) from the current working tree, including the
community discovery filters and null community-rating fix. The signed IPA
passed release entitlement validation. All 41 focused community/Pick for Us
tests, 18 Fastlane tests and iOS release guard checks passed; focused analysis
of the community screen reported no issues. Apple processing completed and the
TestFlight lane succeeded. No App Review submission was made: the user explicitly
reserved submission for a later instruction. No Android or backend deployment
was performed.

## Android production build 101 — 11 October 2026

At the user's explicit request, built and submitted Android 2.0.1 (101) to
Google Play production with the Android Firebase Auth 24.0.1 session persistence
fix. The signed release bundle built successfully, the Google OAuth preflight
passed, and Fastlane committed the production edit with changes sent for review.
An independent Play API read confirmed production version code 101, release
status `completed`, and the en-GB note: “Fixed a bug that signed users out when
reopening the app.” This API status does not establish Google review approval or
public availability. The 34 focused auth tests passed before release; the native
emulator restart test remained unverified because instrumentation stalled (see
docs/testing.md). No Apple review submission or backend deployment was made.

## App Review submission 2.0.1 (101) — 11 October 2026

At the user's explicit request, reused the processed, VALID TestFlight build 101
and submitted it for Apple production review. The cancelled 2.0.1 submission
was DEVELOPER_REJECTED with build 100 selected. Preserved its en-GB release notes:
“Explore Flixie without signing in, plus performance improvements.” The existing
IPA passed signed release entitlement validation; App Store precheck passed and
Fastlane confirmed successful submission. Manual release after approval remains
selected. No duplicate binary upload, screenshot changes or backend deployment
was performed.

## TestFlight build 104 — 12 October 2026

At the user’s request, built/uploaded 2.0.2 (104) from the current working tree,
including recent milestone trophy shields, full Milestones-page trophies and
external movie/show HTTPS sharing. Production `lib/main.dart` and HTTPS API
selected explicitly; release guard and signed IPA capability checks pass. Relevant
focused regressions and four dedicated native sharing journeys passed before upload.
Apple processing completed and Fastlane distributed to internal testers. Independent
API check confirms VALID and membership in the existing all-builds Flixie group.
No App Review submission, Android release, backend or website publication. Shared
links/install redirects still require publishing the prepared website association
files and title routes.

Retained IPA: `build/releases/ios/2.0.2-104/flixie_app.ipa`. SHA-256:
`2196f8c92d079772c06454d9d28d5b08b9f40858d0fc6ca76cb528438fef778b`.
Apple build ID: `4b6267c6-59b8-41b9-8f7e-0a47fcde4e46`.

## TestFlight 2.0.2 (105) — 12 October 2026

User authorised shipping the exclusive Pip-in-3D alternate icon. Existing beta
lane built the current working tree with production Firebase/API, validated the
signed IPA, uploaded it and waited for Apple processing. Apple confirmed processing
and internal tester distribution at 21:41 London. PipGlasses is present in the
release IPA alternate icon dictionary. No App Store review submission performed.
Retained binary and SHA-256 manifest: build/releases/ios/2.0.2-105/.
SHA-256: df32487cc362b0537051649ecd44f8896a1286858faaaadc92daf3518ea0fa4d.
Future Pip artwork variants remain design assets, not selectable icons in this build.

## TestFlight 2.0.2 (106) — 12 October 2026

User authorised deploying the cold-start shared-title routing fix. Built the
current working tree using the existing production main/Firebase/API beta lane;
signed IPA validation and release guard passed. Apple finished processing and
internal tester distribution at 22:10 London. Focused startup routing checks:
21 pass; analysis clean. Signed simulator checks verified terminated-app HTTPS
movie/show links open Alien and Game of Thrones directly.

Retained IPA and manifest: build/releases/ios/2.0.2-106/.
SHA-256: a107c5eace4aa60c4c37e20c459f530d5e959a02bb058e98912829a638d15449.
PipGlasses remains bundled. No App Store review, Android, backend or website
release performed. Physical Messages/WhatsApp validation remains for user testing.

## Release 2.0.2 (107) — 12 October 2026

User authorised TestFlight upload, Apple production review submission and the
required backend reaction deployment. Last released Apple version independently
verified as 2.0.1 (101). Release notes saved at
`fastlane/release-metadata/ios/2.0.2/en-GB/release_notes.txt`; submission accepts an
explicit `notes_file` rather than replacing them with the old generic notes.

Current working tree built with production main/API. Signed IPA capability
validation passed; all 12 Pip reaction PNGs and PipGlasses alternate icon verified.
32 focused app checks, 19 Fastlane checks and iOS release guards passed. Backend
TypeScript checking and all 613 regressions passed on final commit d32441f.
Retained IPA/hash manifest: `build/releases/ios/2.0.2-107/`.
Apple accepted the binary at 23:53 London; processing and internal TestFlight
distribution completed at 23:58. Independent API confirms VALID, IN_BETA_TESTING
and membership in the Flixie group. App Store precheck passed; build 107 was
selected and successfully submitted for review at 23:59 London. Backend deployment succeeded and live `/healthcheck` returned App Healthy.
Production pipeline: https://github.com/lauradouglas/FlixieBE/actions/runs/38318691410.
Submission must reuse this uploaded binary and retain manual release after approval.

```bash
SLACK_RELEASES_WEBHOOK_URL='' RELEASE_VERSION=2.0.2 bundle exec fastlane ios submit build_number:107 ipa:build/releases/ios/2.0.2-107/flixie_app.ipa uploaded:true notes_file:fastlane/release-metadata/ios/2.0.2/en-GB/release_notes.txt
```

## Android production 2.0.2 (107) — 13 October 2026

User explicitly authorised Android production release. Google Play baseline
verified as production code 101. Built current app with production main/API,
Google OAuth preflight passed, all 35 focused Flutter checks passed. Signed AAB
contains all 12 Pip reaction assets. Retained binary/hash manifest under
`build/releases/android/2.0.2-107/`. Uploaded that exact bundle using the Fastlane
Play action with the production lane's settings (completed release, changes sent
for review, no fallback to an unsubmitted edit). Upload/commit succeeded at
00:06 London. Existing listing screenshots/metadata preserved; en-GB notes at
`fastlane/release-metadata/android/en-GB/changelogs/107.txt`. Google review and
public availability remain separate from successful submission.

## TestFlight 2.0.3 (108) — 13 October 2026

User authorised TestFlight deployment of current changes. App Store version
2.0.2 was independently READY_FOR_SALE, so marketing version is 2.0.3.
Built with production lib/main.dart/Firebase/API using existing signed lane.
Signed release entitlement checks passed; IPA verifies 12 Pip reaction assets
and 19 community Pip PNGs. Retained IPA/hash: build/releases/ios/2.0.3-108/.
86 focused app regressions, 19 Fastlane checks and iOS release guard passed.
Includes mixed Trending, guest signup section, genre Pips, 12 selectable reactions
and large previews/full-width tablet picker, loading Pip and recommendation
refresh card, and paired portrait/stacked landscape tablet Watch Plans.
Apple accepted upload at 14:50 London; processing and internal distribution
completed successfully. Independent API confirms build 108 VALID, IN_BETA_TESTING
and membership in the existing Flixie internal group. Apple build ID:
241d958f-4d9e-4e37-87cc-2c7ab1fb7565. Tester notes stored at
fastlane/release-metadata/ios/2.0.3/TestFlight.txt. Backend people-filter commit
8f26bc9 was already deployed successfully by another action; independently
verified production pipeline 38406606002. No duplicate backend deployment done.
No App Review submission or Android upload under this TestFlight request.

## TestFlight 2.0.3 (109) — 13 October 2026

User authorised another TestFlight release after the phone Trending media-label
refinement. Latest uploaded build independently verified as 108 before choosing
109. Built current app with production main/Firebase/API via signed build lane.
95 focused app checks, 19 Fastlane checks and release guard passed. Signed IPA
capabilities and build/version verified; 12 runtime emote assets confirmed.
Retained IPA and hash manifest: build/releases/ios/2.0.3-109/.
Tester notes: fastlane/release-metadata/ios/2.0.3/TestFlight-109.txt.
Apple processing and internal distribution completed at 15:59 London.
No production App Review submission, Android
upload or backend deployment performed under this request. Newly generated angry
v2, eye-roll, rubbish, loved-up, blushing and flirty/tongue artwork remains stored
source art rather than additional selectable reactions in this build.

## Apple screenshot refresh — 13 October 2026

User requested a corner Pip inside each native screen and fresh tablet captures, then selected seated Flixie-hoodie Pip. Presentation config now points at the existing transparent hoodie asset and includes it in input hashes. The Swift compositor clips the mascot inside the native screen frame and scales it separately for phones/tablets. Original captures are not altered. The movie-detail capture now uses The Odyssey with its frozen public backdrop; the internal `06-interstellar` scene key is retained for tooling compatibility. The movie slide uses the existing where-to-watch headline because the backdrop places friend ratings below the first viewport. Previous Apple outputs were backed up under `build/store-screenshots/pre-pip-2026-10-13/`. Fresh capture/render/visual review is in progress; no store upload has been performed.

**Completed local preparation:** Fresh eight-image iPhone and eight-image iPad sets rendered with hoodie Pip, inspected together in contact sheets, and validated against native image/source/artwork hashes. Full gallery: `fastlane/store-presentation/review.html`; overview previews: `iphone-overview.png`, `ipad-overview.png`. Screenshot files retain Apple-compatible native dimensions and opaque RGB output. No listing upload performed; user review/approval is pending.

**Placement revision:** On review, the user requested Pip slightly over the device edge. Compositor now restores the screen clip before drawing the mascot, offsets him left by 32% of his illustration width, and lets his feet extend below the frame by 12% of his illustration height. Native screenshots and dimensions are preserved. Phone and tablet composition previews inspected; upload remains unapproved.

**Three-pose screenshot composition:** User selected looking-down Pip perched top-right on Home (Movies, TV & friends) and TV progress (Never lose your place). Remaining slides alternate rear-view (movie details, watch plan, community) and front-facing hoodie Pip (watchlist, rating, profile). Mascot width increased from 23% to 26% of phone frame width and from 14% to 16% on tablets. Each slide stores its own Pip asset/position; all referenced artwork is hashed so changes require regeneration. Both Apple sets regenerated; no store upload authorised yet.

**Apple upload completed — 13 October 2026:** User approved the final three-pose screenshot set and requested upload. Created editable App Store 2.0.3 draft because live 2.0.2 screenshots are locked. Uploaded all eight iPhone and eight iPad screenshots through the screenshot-only lane, with the already-reviewed preview confirmation supplied via `DELIVER_FORCE=true`. Read back both collections: correct eight-image order, every source MD5 matches the local approved file, all 16 assets COMPLETE without errors. Version remains PREPARE_FOR_SUBMISSION; no binary upload or App Review submission performed. Public screenshots will change when 2.0.3 is approved/released. Evidence: `build/store-screenshots/apple-upload-2026-10-13/verification.json` and `upload.log`.

**Combined App Store submission completed — 13 October 2026, 17:22 London:** User explicitly approved cancellation of the earlier artwork-only review. Cancelled `27954beb-8002-435a-9f52-a2d2dd28b50f`, added 2.0.3 build 109 to a new app review draft and submitted. New submission `be125fac-c589-4ed7-919a-81251509225f` is Waiting for Review. Verified build 109, manual release, release notes, eight iPhone and eight iPad screenshots with matching source checksums/order, and both header/search artwork previews attached to submitted version. Apple represents the app/version as one review item including its listing assets. Proof: `design/app-store/creative-assets/apple-combined-review.png`; release evidence under `build/releases/ios/2.0.3-109/`. No new build upload, Android submission or backend deployment.

**Android Pip screenshot preparation/staging completed — 13 October 2026:** Applied the approved Apple headlines and three enlarged Pip poses to all 24 verified native Android captures: eight phone, eight 7-inch and eight 10-inch. Fresh capture attempts were blocked by emulator/ADB service timeouts and a native pumpAndSettle timeout; no partial or failed captures replaced the originals. The Android movie slide remains Interstellar rather than the new Odyssey backdrop, and native UI is from the existing verified sets. Experimental capture-harness changes were reverted; the functional change is Android Pip composition. All 19 presentation checks and 11 capture-runner checks pass. Staged all 24 new PNGs through Google Play API, verified every SHA-256 and each category’s order. Edit `17165304840054983059` intentionally uncommitted following the existing user-owned Console selection/submission workflow. Evidence: `build/store-screenshots/android-pip-upload-2026-10-13.json`; gallery: `fastlane/store-presentation-android/review.html`. No Android binary upload or release submission performed.

## TestFlight and App Store 2.0.3 (110) — 13 October 2026

User authorised TestFlight deployment and replacement of the current App Store submission build. Built current working tree using production main/Firebase/API. Includes content-sized Home carousel, compact spacing, four-line synopses and TV friend previews with separate movie/show state. All 46 focused app checks, 19 Fastlane checks and release guard passed; signed IPA validated. Retained binary/SHA-256 manifest under `build/releases/ios/2.0.3-110/`. Apple processed build 110 VALID and distributed to internal testers at 18:38 London. Replaced waiting build-109 review, preserving release notes/listing screenshots and manual release. Independent API confirms 2.0.3 build 110 WAITING_FOR_REVIEW, submission `fb43c623-039f-47e2-ad75-d992584d7b92`, eight iPhone and eight iPad screenshots. Verification: `build/releases/ios/2.0.3-110/app-store-submission.json`. No Android or backend deployment performed. Show-response badge/removed-membership fixes remain local backend changes requiring separate production rollout.

### Android Pip screenshots production submission — 13 October 2026

The user explicitly authorized applying the staged artwork to production. The API service account returned 403 for validation and commit, so the 24 uploaded images were selected through the authenticated Play Console asset library: eight each for phone, 7-inch tablet and 10-inch tablet, in Home/movie/watchlist/plan/rating/TV/community/profile order. The 24 new Pip composites were declared as AI-created or edited artwork. Saved and sent all three listing changes for review. Play Console shows **Changes in review**, with quick checks running and managed publishing off (publishes after approval). No app binary or release track was changed. Proof: `fastlane/store-presentation-android/google-play-screenshots-in-review.png`. This supersedes the earlier uncommitted/manual-selection status for these images; the API edit itself was not committed.

### Android 2.0.3 (110) production submission — 13 October 2026, 19:22 London

User explicitly requested a new production app submission. Built and retained signed production AAB with current working tree, production main/Firebase/API, 12 Pip emotes and 19 community Pips. Uploaded bundle and en-GB notes with Fastlane Supply; metadata/images/screenshots skipped to preserve listing work. Upload and commit succeeded. Independent API verifies production version code 110, completed rollout configuration, correct release notes. Play Console shows 2.0.3 Production / Start full rollout under Changes in review, with quick checks running and managed publishing off. Public release awaits Google approval. Evidence: `build/releases/android/2.0.3-110/`, including SHA-256 manifest, build log, track readback and review screenshot. Analysis found no issues; 19 Fastlane checks pass. Broader app tests passed 85, with two unchanged pre-existing stale expectations: Home subscription fixture still mocks movie-only trending, and cinema synopsis expects the former three-line cap. Auto-review rejected proposed updates as weakening assertions; neither test changed. No backend deployment was performed.


## TestFlight 2.0.3 (111) — 13 October 2026

User authorised TestFlight deployment of the current app changes. Built signed production IPA using `lib/main.dart`, production Firebase/API configuration and version 2.0.3 build 111. Includes the iframe trailer player with direct landscape, native YouTube controls, persistent close, portrait restoration and fade/black orientation transition. All 19 focused trailer/card checks, 19 Fastlane tests and the iOS release guard passed; signed IPA entitlements, version/build and landscape capabilities validated. Retained IPA, SHA-256 manifest and logs under `build/releases/ios/2.0.3-111/`.

Apple accepted the upload at 23:11 London and processed/distributed it at 23:16 London. Independent App Store Connect API confirms build `dc27fe13-2430-4ee2-9847-3d9c5c7056f2`, processing VALID, internal state IN_BETA_TESTING; existing Flixie internal group has automatic build access. Verification: `build/releases/ios/2.0.3-111/testflight-verification.json`. No App Store review submission/replacement, Android upload or backend deployment performed.


## TestFlight 2.0.4 (112) — 14 October 2026

User authorised TestFlight deployment. Built the current working tree with production main/Firebase/API, including availability-alert settings and inbox cards for films/TV, Popcorn Catch and current Home improvements. The initial 2.0.3 upload was rejected before acceptance because Apple had already approved 2.0.3; rebuilt with marketing version 2.0.4 and retained build number 112. No App Store review submission or replacement performed.

Validation: 26 focused app tests, 19 Fastlane tests (106 assertions), release guard and signed IPA entitlement validation pass. Production `lib/` analysis is clean. Broad analysis reports 36 diagnostics in archived performance harnesses, tests, preview tools and third-party source; these were retained/reported without suppressions. Native availability-alert journey remains unverified from the earlier simulator attempt.

Apple accepted the corrected upload at 22:30 London. Independent API confirms build `5007920f-cc1d-4800-b247-4361b1719d6f`, processing VALID, internal state IN_BETA_TESTING and automatic access for the existing Flixie group. Signed IPA, SHA-256 manifest, logs and verification: `build/releases/ios/2.0.4-112/`.


## TestFlight 2.0.4 (113) — 15 October 2026

User requested TestFlight deployment after approving Pip's performance and friend
challenge designs. Built the current working tree with production `lib/main.dart`,
Firebase and HTTPS API settings. All 24 focused Popcorn Catch tests, 19 Fastlane
checks (107 assertions), iOS release guard and production `lib/` analysis pass.
The signed IPA passed validation and Apple accepted the upload at 09:24 London.
Build processing/tester availability remains pending at the latest API check.
Retained IPA, SHA-256 manifest and logs under `build/releases/ios/2.0.4-113/`.
No App Store review submission, Android upload or backend deployment performed.
The new challenge service/database migration still requires a separate backend
rollout before its live functionality can be confirmed.


**Production backend verification — 15 October 2026:** A subsequent check of
API - Deploy run [38707759971](https://github.com/lauradouglas/FlixieBE/actions/runs/38707759971)
confirms backend commit `e410c32` had already deployed successfully. The production
migration step applied `20261014220000_popcorn_levels` and
`20261014230000_popcorn_challenges` at 09:47 London and reported all migrations
successfully applied before the API deployment. This supersedes the earlier
statement that the challenge backend rollout was pending. No duplicate migration
execution was needed.


## TestFlight 2.0.4 (114) — 15 October 2026

User authorised TestFlight deployment of the current working tree. Includes retro arcade chooser, Pip Pairs with outfit artwork and three difficulty modes, and Space Premiere with heart lives. All 65 focused game tests, 19 Fastlane checks (107 assertions), release guard and production lib analysis passed. Signed production IPA validated, game artwork/font confirmed bundled, and binary/SHA-256 retained under `build/releases/ios/2.0.4-114/`. Apple accepted upload at 13:12 London and processing/internal distribution completed at 13:17. Independent API confirms build `bc21773b-1d90-4890-96ec-bc5ad031c43b`, VALID and IN_BETA_TESTING. No App Review submission, Android or backend deployment. A subsequent full-round Popcorn regression and preview-only fixture correction were made after upload; they do not change the production binary.


## TestFlight 2.0.4 (115) — 15 October 2026

User explicitly authorised TestFlight upload of the audio-enabled app. Built current working tree with production main/Firebase/HTTPS API. Includes three quiet music loops, 17 game effects, saved music/effects switches and volume control, lifecycle/route audio handling and pausing action games for audio settings. Pip character voices excluded. All 76 focused game/audio checks, 19 Fastlane tests (107 assertions), release guard and production lib analysis passed. Native iPhone simulator check played all 20 files. Signed IPA entitlements validated; all 20 WAVs and native audio framework confirmed bundled. Retained signed IPA/SHA-256 manifest/logs at `build/releases/ios/2.0.4-115/`. Apple accepted upload at 14:24 London; processing and internal distribution completed at 14:29. Independent API confirms build `1b7dcfb4-6423-43fe-b637-bd140907ac36`, VALID and IN_BETA_TESTING. Tester notes at `fastlane/release-metadata/ios/2.0.4/TestFlight-115.txt`. No App Review submission, Android upload or backend deployment.


## TestFlight 2.0.4 (116) and watch backend — 16 October 2026

User authorised TestFlight and explicitly included the backend rollout. Signed production IPA built from the current working tree with production main/Firebase/HTTPS API, validated release entitlements, and retained with SHA-256/source manifest under `build/releases/ios/2.0.4-116/`. Includes independent watch-together logging, optional dates, favourite-first companions, external watch invites through signup, cumulative gold stars, separate watch comments, visible recommendation and companion avatars/personalised wording on Friends activity. Companion details remain excluded from Around Flixie. Review title/body redesign and movie-bestie statistics remain proposals.

43 focused watch/invite/router tests, 19 Fastlane tests (107 assertions), release guard and lib analysis passed. Backend CI passed 658 tests; explicit released-client watch payload regressions also passed. Backend commit `cb57d823dfec0427f6f9c5bc16c81a05c9e1c183` deployed through https://github.com/lauradouglas/FlixieBE/actions/runs/38900426784; both additive migrations applied before Azure deployment. Live nonexistent invite lookup exercises the new table and returns INVITE_CLOSED; unauthenticated existing user routes still return 401. Unrelated backend safety/availability edits were excluded.

Apple accepted the upload at 13:39 London, finished processing at 13:44, and confirmed internal distribution. Independent API verification: build `efa52ff0-e608-46d6-9e57-978cf298318d`, VALID and IN_BETA_TESTING. Tester notes: `fastlane/release-metadata/ios/2.0.4/TestFlight-116.txt`. No App Review submission or Android rollout.


## TestFlight 2.0.4 (117) and multiple-companion backend — 16 October 2026

User requested deployment after multiple-companion implementation. Backend commit `644a40bc1f36646824ca4cefc2de102051d6f681` deployed successfully through https://github.com/lauradouglas/FlixieBE/actions/runs/38909093629. All 660 deployed-source CI tests passed, migrations reported none pending, and production health/auth/external-invite read smoke checks passed. Unrelated backend changes remain excluded. Local working-tree verification passed 662 backend tests.

Signed production IPA built from current working tree with production main/Firebase/HTTPS API. Includes multiple Flixie friend selection with favourites first, independent recipient log/rate prompts, plural avatar display in Friends activity and watch history, persistent review shortcut and keyboard layout improvements. External invites remain a separate single-person flow. TV season ratings were captured as an idea during deployment and are not included.

All 27 focused watch UI checks, 19 Fastlane tests (107 assertions), iOS release guard and production lib analysis passed; signed entitlements/version/build validated. Native multi-watch Patrol test built but XCTest stalled before app launch on two attempts, so native end-to-end verification remains outstanding. Retained IPA, SHA-256/source manifest, logs and backend evidence: `build/releases/ios/2.0.4-117/`. Apple uploader reported successful transfer at 15:16 London (delivery `a468d74a-766f-4254-9950-2e0c444228e6`), alongside Apple API HTTP 500 responses which caused Fastlane to exit before processing/distribution. Subsequent upload-receipt API confirms COMPLETE with no errors/warnings and processed-build API confirms VALID (`a468d74a-766f-4254-9950-2e0c444228e6`). Finished metadata/distribution only, without reuploading: tester notes set and internal distribution succeeded at 15:31 London. Final independent API confirms VALID / IN_BETA_TESTING. Evidence retained in `apple-upload-state.json`, `testflight-verification.json` and `distribution.log`. No App Review or Android deployment performed.

## TestFlight 2.0.4 (118) and guest-game backend — 16 October 2026

User authorised TestFlight deployment, then explicitly included the guest-game backend rollout. Backend release was isolated from unrelated local safety/availability work in commit `963e21f290ac37ab9ec8a82d971c2cc8c4b85bdc`. Build, TypeScript checking and all 662 backend tests passed locally; production CI also passed 662 tests. Workflow https://github.com/lauradouglas/FlixieBE/actions/runs/38930481384 applied additive migration `20261016160000_guest_popcorn_rounds` before deploying Azure. Live smoke checks confirm health 200, guest-round issuance 201 with version 3/600 ticks/claim token/expiry, and unauthenticated claim/ranked starts 401. No real-account claims or leaderboard scores were posted by release checks.

Signed production IPA uses main/Firebase/HTTPS API, version 2.0.4 build 118. Includes Cinema notebook reviews and the optional watch-save-to-review continuation, plus playing games before signup and carrying a guest Popcorn round through signup for explicit score posting. 83 focused app tests, 19 Fastlane tests (107 assertions), release guard and production lib analysis pass. Native review-posting Patrol journey passes; phone/landscape/tablet/large-text keyboard coverage passes. Native iPad visual review and complete native guest signup/score posting remain unverified. Signing, version/build and bundled Pip artwork verified. Runtime source/artwork hashes remained unchanged during build. Retained IPA, SHA-256, source manifest, tester notes, check logs and backend evidence under `build/releases/ios/2.0.4-118/`. Apple accepted the upload at 17:27 London and completed processing/internal distribution at 17:32. Independent API verification confirms build `1d4ce5a8-60a0-4220-9a1e-93299b649d61`, VALID / IN_BETA_TESTING. Tester notes are set. Evidence is retained in `testflight-verification.json`, `release.json` and `upload.log`. No App Store review submission or Android rollout performed.


## Apple watch-entry screenshot refresh — 16 October 2026

User requested replacement of the outdated “Every watch. Your own rating.” App Store screenshot. Captured the current watch-entry UI through the isolated native Patrol fixture on dedicated iPhone 17 Pro Max and iPad Pro 13-inch simulators. The fixture now uses reduced motion so decorative loops settle, and its action selects the current Recommend pill. Focused fixture regression passes; both native captures and all 16 presentation provenance checks pass. Existing headline, Flixie wordmark and hoodie Pip framing are preserved.

Published 2.0.3 is locked, so created an editable 2.0.4 App Store draft. Replaced only the fifth (rating) screenshot in each en-GB device set. Read back all eight assets per set: replacement delivery COMPLETE, all source checksums match the local files, original order retained and the other seven screenshots per set byte-identical. Version remains PREPARE_FOR_SUBMISSION; no App Review submission or binary selection. Public screenshots change with the next approved release. Before/after API evidence, original-image backups and upload log: `build/store-screenshots/rating-refresh-2026-10-16/`.


## TestFlight 2.0.4 (120) — 16 October 2026

User authorised a TestFlight build and initially requested App Review, then explicitly revoked review submission and instructed immediate stop. Signed production main/Firebase/HTTPS API build 120 validated, with source integrity unchanged during build. Includes smaller Griddy Pip and removal of the signed-in Home catch-up banner. Guest Home design exploration is separate and is not in this binary. Apple processing and internal distribution succeeded: build `162854d5-fee8-4bbe-9deb-66bc6c8dddde`, VALID / IN_BETA_TESTING.

The submission command was interrupted at the user's stop instruction. Independent Apple read confirms version 2.0.4 is DEVELOPER_REJECTED, manual release, with no active review submission. Build 120 remains on TestFlight. Release notes and build selection were staged before interruption; existing screenshots were preserved. Do not restart or submit for App Review without a new explicit user request. Evidence: `build/releases/ios/2.0.4-120/review-stop-verification.json`. No backend or Android deployment.
