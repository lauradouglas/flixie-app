# iPhone Flixie widgets

Small and medium WidgetKit widgets open `flixie:///search?focus=1`. Discover
focuses its input, selects an existing query and displays the keyboard. The focus
request is consumed so later widget taps work while the app is already running.
Sign-in, terms and onboarding remain required; the search destination is retained.

The Search widget is a launcher, not an editable home-screen field. It contains
no user data. The extension also includes the Watchlist widget described below,
which requires shared App Group storage and cached poster downloads.
`FlixieSearchWidget` is embedded in Runner with bundle ID
`com.flixie.flixieApp.SearchWidget`. Its version comes from the generated Flutter
configuration, matching Runner. Release signing needs an Apple App ID and
provisioning profile for this extension as well as Runner; check the existing
Fastlane export/signing flow before uploading a release containing it.

After installing a new iOS build, long-press the Home Screen, choose Edit / Add
Widget, search for Flixie and add Search Flixie. Tap anywhere on it. Verify both
sizes, a terminated app, an already running app on another tab, repeat taps after
dismissing the keyboard, an existing query, and signed-out sign-in recovery.
Use a dedicated local simulator and fictional accounts for testing. An installed
older build does not include this widget. Native target additions require a new
iOS build/install; hot reload alone cannot install the extension.

Focused automated checks:

```sh
flutter test test/search_widget_focus_test.dart test/search_screen_requests_test.dart test/setup_destination_test.dart
flutter analyze lib/features/movies/presentation/pages/search_screen.dart lib/core/auth/setup_destination.dart lib/app/router/router.dart test/search_widget_focus_test.dart
```

Validation on 4 October 2026: six focused tests passed, focused Dart analysis
passed, and the arm64 iPhone simulator extension compiled successfully. No live
development app was attached to DTD for reload. Full Runner embedding, widget
gallery appearance, native layout and real-device keyboard behavior remain to
be verified with a new local iOS install before release.

## TestFlight build 91

Uploaded 1.0.1 (91) on 4 October 2026. Registered and provisioned the widget
extension with Apple, then verified its inclusion, matching version and strict
signature in the final IPA. Widget gallery appearance and physical device
keyboard behavior still need verification using the new TestFlight build.


## Watchlist widget — 5 October 2026

The local widget extension defines **Flixie Watchlist** alongside **Search Flixie**.
Both small and medium Watchlist widgets open `flixie:///watchlist`; the medium
(wide) widget displays up to four active saved movies/shows in the Watchlist's
default newest-saved-first order. Removed entries and watched shows are excluded.
Tapping anywhere, including a poster, opens Watchlist. Empty and signed-out
states explain the next action; unavailable posters show the title.

Runner publishes only the account identifier and four title/poster records through
`flixie/watchlist_widget` to App Group `group.com.flixie.flixieApp`.
Native code downloads at most four TMDB w185 images into the shared container;
the extension reads local images and never receives authentication tokens.
AuthProvider synchronizes changed snapshots after profile/watchlist updates.
Sign-out and account changes immediately replace the snapshot and delete old
images; an obsolete download cannot publish after a newer snapshot.
WidgetKit controls the timing of reload requests, so updates are not guaranteed
instantaneously or while the app has not refreshed its watchlist.

Both targets now declare the shared App Group entitlement. Before signing a new
physical-device/TestFlight build, register this group in Apple Developer and
associate it with both `com.flixie.flixieApp` and
`com.flixie.flixieApp.SearchWidget`; regenerate their provisioning profiles.
The former no-App-Group requirement above applies only to the original search
launcher. A full native rebuild/install is required for this addition.

Focused regressions: `test/watchlist_widget_sync_test.dart` and
`test/setup_destination_test.dart`, retaining `test/search_widget_focus_test.dart`.
They cover recent ordering, mixed films/shows, four-item limit, removed/watched
exclusion, add/remove updates, unchanged snapshot deduplication, account switching,
logout clearing and recovery of the Watchlist destination after setup.

Validation on 5 October: 22 focused Flutter checks passed with auth recovery and
existing Search widget tests; focused Dart analysis was clean. The standalone
widget target and full arm64 simulator Runner build passed. Xcode extracted the
new Watchlist shortcut metadata. The development app was restored to its usual empty-entitlement
ad hoc simulator signature, launched, and reconnected to Flutter tooling
(on Sign In after installation) after App Group signing experiments were refused.
Shared-container/poster rendering, gallery appearance, iPad/large-text rendering
and physical Action Button execution remain unverified.

Release signing on 5 October: the user approved App Group registration and profile
refresh. Registered group.com.flixie.flixieApp and associated it with Runner and
SearchWidget, preserving Runner's existing group.com.flixie.app.widgets group.
Regenerated both App Store profiles and exported version 1.0.1 build 92.
Verified both final IPA signatures, matching build numbers and the shared group
through Apple's Security framework; Runner also retains production push, Apple
sign-in and its associated domain. The local codesign XML display option does not
decode the current DER entitlements, so Security.framework provided the entitlement
dictionaries for validation.

TestFlight upload succeeded on 5 October at 12:05:41 UTC. App Store Connect
visibly lists version 1.0.1 build 92 as Processing; install availability awaits
Apple processing. No external beta review or App Store submission was made.
