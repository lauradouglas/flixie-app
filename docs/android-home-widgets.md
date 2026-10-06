# Android Home Screen widgets

Flixie offers **Search Flixie** and **Flixie Watchlist**. Long-press the Home
Screen, choose Widgets, find Flixie and add either widget. Resize Watchlist wider
to show up to four most recently saved active films/shows. Smaller sizes open
Watchlist; Search opens Discover with search focused. Authentication and setup
still apply, with the requested destination retained.

The shared Flutter WatchlistWidgetSync snapshot now supports Android and iOS.
Android stores just four titles/poster paths in private no-backup storage.
The app publishes changes after its profile/watchlist refreshes; widgets do not
independently fetch account data or contain login tokens. Removed/watched entries
are excluded by the shared selector. Sign-out/account changes clear all cached
images immediately, and revision checks reject late downloads. Failed downloads
show the title; signed-out and empty widgets explain the next action.

Posters come only from HTTPS TMDB w185 paths, with bounded bytes/dimensions and
connection/read timeouts. The widget uses Android RemoteViews, immutable explicit
PendingIntents and non-exported providers. Native rebuild/install is required.

## Focused verification

Shared Flutter checks:

    flutter test test/watchlist_widget_sync_test.dart test/setup_destination_test.dart test/search_widget_focus_test.dart

Native OS-widget tests use an optional AndroidJUnitRunner override; the default
runner remains Patrol. Use a dedicated emulator with fictional fixtures only:

    cd android
    ./gradlew :app:assembleDebug :app:assembleDebugAndroidTest -PflixieWidgetTestRunner=androidx.test.runner.AndroidJUnitRunner

Install the debug app and test APK on the selected emulator, then run:

    adb -s <device> shell am instrument -w -e class com.flixie.app.FlixieWidgetsTest com.flixie.app.test/androidx.test.runner.AndroidJUnitRunner

Tests cover four-title selection, credential exclusion, account/logout cleanup,
stale poster rejection, narrow/wide layouts, 130/300/600dp widths at 1.3 text scale,
signed-out/empty recovery, native image rendering and removal, provider metadata,
and widget deep-link launches. Flutter checks retain Search focus/repeat launches
and Watchlist recovery through auth/setup.

An optional captureWidgets=true instrumentation argument captures real native
RemoteViews in a private debug-only WidgetPreviewActivity, using four public
fictional-fixture posters. The preview activity is absent from release builds.
This does not replace a real launcher or physical-device check.

Verification on 5 October 2026: 11 focused Flutter tests and nine native tests
passed; analysis and debug/release builds passed. The native preview was inspected
and the release manifest excludes the preview activity. The tap test was then
strengthened to click the applied RemoteViews itself; it compiled, but its final
run was blocked by an unavailable automatic approval reviewer. Tablet installation
stalled, so tablet launcher and physical-device verification remain outstanding.
No Play Store release was made.
