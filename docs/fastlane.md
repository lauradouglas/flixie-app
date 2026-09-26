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
