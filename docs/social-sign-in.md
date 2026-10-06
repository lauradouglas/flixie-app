# Apple and Google sign-in

Implemented locally on 3 October 2026. Login and signup offer Apple and Google on iOS and Google only on Android;
Settings connects either provider to the current Firebase UID. Only one social
provider may be connected through the app. Once connected, the connection buttons
are replaced with a compact status in Settings → Account. Existing accounts that
already have both providers retain them. Existing profiles,
libraries and relationships stay on that UID. A credential belonging to another
account is rejected with instructions; accounts are never merged by email.

New identities complete the existing display-name, username, consent, referral,
avatar and onboarding flow without setting a password. Their email comes from
the authenticated identity, including Apple's private relay address. Missing
profiles (null/404) resume signup; network/server errors remain recoverable errors.
Signing out abandons the local signup state. A restored identity with a saved
profile resumes ordinary onboarding.

Password settings are shown only for password accounts. Account deletion confirms
ownership with an available method and refreshes the backend token. Apple-linked
accounts reauthenticate with Apple; on iOS/macOS the returned authorization code
is revoked before deletion. Web/Android Apple reauthentication does not expose
that Apple-platform code through the installed SDK; server-side Apple revocation
is not implemented for those platforms.

## Provider configuration before release

Release preparation on 3 October 2026: Google and Apple are enabled in Firebase.
The Apple bundle capability and a refreshed App Store distribution profile include
Sign in with Apple. Android intentionally offers Google only, as requested by the user.

- Enable Google and Apple in the existing Firebase project's Authentication
  providers. Keep email/password enabled for existing clients.
- Enable Sign in with Apple for `com.flixie.flixieApp` in the Apple developer
  account and regenerate distribution provisioning profiles. The Runner
  entitlement is included. For Apple on Android/web, configure the Apple Service
  ID, Team ID, key and Firebase callback URL in the provider console. Store the
  private key only in the provider console/server secrets, never in this app.
- iOS Google configuration uses the existing CLIENT_ID and REVERSED_CLIENT_ID
  from `ios/Runner/GoogleService-Info.plist`. Info.plist includes the client ID
  and callback scheme. GoogleSignIn 9.2.0 needs GTMSessionFetcher 3.x, compatible
  with the existing Firebase 11.15.0 SDK; the Podfile lock records this resolution.
- Android Google services configuration now includes the web OAuth client
  (client_type 3), verified against the enabled Firebase Google provider.
  Register debug/release signing certificate SHA fingerprints in Firebase.
  An Android or iOS OAuth client ID is not a substitute for the web client ID.
- Web uses Firebase popups and does not initialize the native Google SDK.
  Register the deployed domain (and localhost for development) as authorized
  Firebase Auth domains. Allow popups when testing.

A native rebuild is required after adding google_sign_in. Hot reload cannot
register a newly installed native plugin or apply entitlements.

## Local verification

83 focused tests passed, including API null-profile handling, authentication,
linking, deletion and responsive layouts. Targeted Dart analysis passed.
The iOS debug simulator build succeeded with the existing simulator-only
architecture workaround:

```sh
# Temporary xcconfig contains: ARCHS[sdk=iphonesimulator*] = arm64
XCODE_XCCONFIG_FILE=/tmp/flixie-social-simulator.xcconfig \
  flutter build ios --simulator --debug --no-codesign
```

No running Flutter app was connected to the Dart tooling daemon, so no live
hot reload was available. The build does not verify Apple distribution signing,
Android compilation, or real provider login.


```sh
flutter test test/social_auth_test.dart test/social_auth_service_test.dart \
  test/social_auth_layout_test.dart test/auth_recovery_test.dart \
  test/signup_flow_test.dart test/signup_avatar_step_test.dart \
  test/login_layout_test.dart test/terms_deletion_test.dart test/auth_ui_test.dart
```

The social auth fixtures use the fictional `alien-fan@example.invalid` identity
and injected profile storage. They never write to a database or a real Google,
Apple or Firebase account. These tests cover both new and existing users,
consent, profile failure, restored sessions, linking, credential conflicts and
cancellation. They do not prove OAuth provider provisioning is correct.

For a real-provider smoke test, use dedicated development accounts: sign up with
each provider, finish onboarding, sign out/in, and separately link either provider
to a password account in Settings. Verify it returns to the same library and that
the app prevents connecting the other social provider afterward. Also test cancel,
Apple Hide My Email, a credential already linked elsewhere, and account deletion.
Do not use a real user's account for the deletion test.

References: [Firebase Flutter social authentication](https://firebase.google.com/docs/auth/flutter/federated-auth)
and [Google Sign-In iOS setup](https://pub.dev/packages/google_sign_in_ios).

## Release attempt — 3 October 2026

User requested Play production and iOS TestFlight deployment. iOS 1.0.1 (89)
was archived, manually signed with a refreshed App Store profile including
Sign in with Apple, and uploaded successfully to App Store Connect. Processing
and tester availability require store confirmation. Android signed bundle 89
built successfully but was not uploaded: Firebase Apple provider lacks the
Services ID required for Android OAuth. Await configuration or an explicit
decision to omit Apple on Android. Existing Play production build 88 is unchanged.
39 focused auth/deletion tests passed. Targeted analysis reported one informational
curly-braces lint at auth_provider.dart:367 and no errors.

### Platform scope confirmed

User confirmed Android needs Google only and iOS needs both Apple and Google.
Provider buttons and Settings explanatory text now follow that scope. Existing
linked identities remain visible. 35 focused tests passed, including platform
variants for sign-in and linking; targeted analysis is clean. Development app
hot reload succeeded. Apple reports uploaded build 89 as VALID. Android 89 is
being rebuilt for production with the platform restriction.

Release result: rebuilt Android 89 with Google-only provider UI, uploaded the
production draft, then successfully submitted the production rollout for Google
review. iOS 1.0.1 (89) is VALID in App Store Connect with both providers. Store
review/availability is distinct from successful upload and submission.

### TestFlight signing correction — build 90

User reported an unknown error connecting Apple in TestFlight 89. Inspection of
the exact uploaded IPA proved its app signature lacked Apple sign-in, APNs and
associated-domain entitlements, despite the embedded profile permitting them.
The unsigned-archive export workaround lost the application entitlements. Build
90 preserves the same compiled app and signs it with explicit release entitlements
before export. The final IPA passes entitlement validation; the validator rejects
build 89 and is now required by the Fastlane iOS build lane. TestFlight upload
is in progress. Real-device Apple linking still requires verification after install.

Build 90 upload succeeded at 16:40 local time on 3 October 2026.
Final IPA entitlement checks passed; 15 Fastlane tests (76 assertions) and
the iOS release guard passed. Apple processing and real-device retest remain pending.

### Google Play signing registration correction

User reported Google sign-in bouncing back in production. Downloaded Play-generated
build 89 base APK and verified its signing certificate using apksigner. Its SHA-1
49d092224ab10fb1fbd0c167698ba19084b98732 was absent from Firebase. Registered
that SHA-1 and its verified SHA-256 on com.flixie.app; Firebase generated the
matching Android OAuth client. Refreshed local Google services configuration while
preserving the verified web OAuth client. Existing installed build 89 already has
the web client, so this server-side registration should not require a new binary.
Real Play-installed device retest is pending; do not claim end-to-end success yet.

### Android deleted web OAuth client — 4 October 2026

A further Play-installed Android failure was traced to the **web OAuth client**,
not the Play signing certificate. Google's authorization endpoint returned
`deleted_client` / “The OAuth client was deleted” for
`1093787683868-6d5o5dduc9jeoas22jtfmfu2rjklmq1i.apps.googleusercontent.com`.
Google Cloud no longer listed that client among active or recoverable clients.
The exact cause/date of deletion is unknown. The prior Firebase SHA registration
was verified against the normal Play APK variant for Android 10+ as well as the
previously downloaded archive-stub variant. The normal APK's embedded
`default_web_client_id` matched the deleted ID.

With the user's explicit approval, created the replacement web application
client `Flixie Google sign-in` in the existing project, using the existing
`https://flixie-9a8eb.firebaseapp.com/__/auth/handler` callback. Saved its ID and
secret in Firebase's Google provider configuration. The secret is not stored in
this repository. The replacement ID is
`1093787683868-cok4pahqen4qj6qc5mueuf6tsv7v65s4.apps.googleusercontent.com`.
Firebase's live configuration and Google authorization endpoint both accept it.
Refreshed `android/app/google-services.json` from Firebase.

**An Android app update is required**: Play build 89 embeds the deleted web client
ID and cannot receive the replacement through a server-side configuration update.
The active iOS client is separate and was preserved, which explains why Google
sign-in could still work in the iPhone simulator. No backend/API contract changed.

The Android Fastlane build now runs `scripts/check-google-oauth.py` before
compilation. It requires a web OAuth client in the Android config and verifies
that Google's authorization endpoint reaches sign-in using the configured Firebase
callback, rejecting deleted/invalid clients, invalid callbacks and error pages.
This requires network access and proves configuration validity, not account login.
Run `python3 scripts/test-google-oauth.py` for isolated regression checks.

Validation: 18 focused auth tests, 5 OAuth guard tests, and 15 Fastlane tests
(78 assertions) passed. Google live provider/client checks passed. Android debug
compilation and emulator smoke-test results are recorded below when complete.

Android debug APK compilation succeeded. Inspection of the built APK's
`default_web_client_id` confirms the replacement ID is packaged. Installed and
launched this APK on the dedicated Pixel 9 Pro emulator (Android 17); the Flutter
engine loaded. The emulator has zero Google accounts, so real Google sign-in and
the account-picker outcome remain unverified. No Android release was uploaded.
