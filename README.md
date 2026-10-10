# Flixie

Flixie is a Flutter app for discovering, tracking and discussing movies and TV,
and arranging Watch Plans. The mobile app targets iOS and Android. Its API lives
in the sibling `../FlixieBE` repository; `admin-dashboard/` is a separate web app.

## Start locally

Use **Flutter 3.44.0**, the version pinned by the regression workflow. Native
builds also need Xcode/CocoaPods for iOS or the Android SDK/JDK for Android.
See [testing setup](docs/testing.md) for the pinned Patrol tools.

Obtain the development Firebase configuration, using `.firebase.json.example`
as the field reference. Keep the local `.firebase.json` out of Git. Native runs
also need the project's `GoogleService-Info.plist` / `google-services.json`.
Configuration is read by `lib/core/auth/firebase_options.dart`; contributors
should not replace generated options or create a new Firebase project to run
this existing app.

```sh
flutter pub get
flutter run --dart-define-from-file=.firebase.json -d <development-device>
```

Debug runs use `http://localhost:3000`; start the sibling backend for local API
work. Android emulators reach the host through `http://10.0.2.2:3000`; physical
devices need the host's LAN address:

```sh
flutter run --dart-define-from-file=.firebase.json -d <development-device> \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Profile/release runs default to the production API. `USE_PROD_API=true` selects
it for debug runs; an explicit `API_BASE_URL` takes precedence. Restart the run
after changing compile-time flags. The VS Code launch menu contains development
and production API configurations.

## Find the code

```text
lib/
  main.dart           # Bootstrap and app lifecycle
  app/                # Router and theme
  core/               # Shared API, auth, navigation, storage and UI
  features/           # Product features; start here for most changes
  models/             # Models currently shared across features
test/                 # Unit, widget and golden regressions; fixtures in support/
patrol_test/          # Native journeys on dedicated test devices
android/, ios/        # Native integration and configuration
```

Read [the architecture guide](docs/architecture.md) for ownership rules and the
Watchlist reference. Use these starting points:

| Work | Start here |
|---|---|
| Watchlist | `lib/features/watchlist/presentation/pages/watchlist_screen.dart` |
| Home | `lib/features/home/presentation/pages/home_screen.dart` |
| Movie/TV details | `lib/features/movies/presentation/pages/` |
| Movie List Detail | `lib/features/movies/presentation/pages/movie_list_detail_screen.dart` and the [ownership map](docs/architecture.md#movie-list-detail-ownership) |
| Profiles | `lib/features/profile/presentation/` |
| Social tabs and their state owners | `lib/features/social/presentation/pages/social_screen.dart` and the [Social ownership map](docs/architecture.md#social-ownership) |
| Communities and chat | `lib/features/social/` |
| Watch Plans | `lib/features/watch_plans/` |
| Search | `lib/features/movies/presentation/pages/search_screen.dart` and the [Search ownership map](docs/architecture.md#search-ownership) |
| Group Insights | `lib/features/social/presentation/widgets/insights_tab.dart` and the [Insights ownership map](docs/architecture.md#group-insights-ownership) |
| Create a Watch Plan | `lib/features/movies/presentation/widgets/watch_request_sheet.dart` and the [composer ownership map](docs/architecture.md#watch-request-composer-ownership) |
| Navigation | `lib/app/router/router.dart` and `lib/core/navigation/` |
| Session/authentication | `lib/core/auth/` |
| Colours, typography and shared UI | `lib/app/theme/` and `lib/core/widgets/` |

Other roots have separate purposes: `scripts/` contains development/release
checks, `fastlane/` contains store lanes, `assets/` contains shipped resources,
`third_party/` contains a documented Firebase App Check patch, and `design/`
contains design explorations. `build/`, `coverage/` and local `output/` are
outputs. Product decisions and historical work live in [product memory](docs/product-ideas.md).

## Check your change

Start with relevant files and tests:

```sh
flutter analyze lib/features/watchlist test/features/watchlist
flutter test test/features/watchlist/watchlist_controller_test.dart \
  test/watchlist_screen_states_test.dart test/watchlist_recommendation_batch_test.dart
```

Run affected existing tests too; many remain directly under `test/`. New tests
should follow their feature's path. [Testing guidance](docs/testing.md) lists
native coverage, fixture isolation and golden review rules.

Watchlist paging and the other critical native journeys use a **dedicated**
simulator/emulator: Patrol reinstalls the app on the selected device.

```sh
scripts/test-patrol.sh -d <dedicated-test-device> \
  -t patrol_test/watchlist_paging_test.dart
```

Run `scripts/test-regression.sh` for an explicitly requested complete local
check. GitHub's regression workflow runs analysis and Flutter tests on PRs and
main pushes; its slower Patrol job is an optional manual run. The separate iOS
and Android build workflows check native builds. See their YAML for exact
triggers and configuration; a local pass does not verify GitHub runner setup.

## Release and contribution guidance

Read [AGENTS.md](AGENTS.md) for repository rules, [the Flutter guide](docs/flutter-expert-guidance.md)
for engineering guidance, and [architecture](docs/architecture.md) before a
structural change. Preserve badge borders, privacy, responsive layout and
user-action regressions. Build 70 compatibility was retired on 6 October 2026.

Store builds/uploads use [Fastlane](docs/fastlane.md). For an Xcode archive after
local simulator testing, `sh scripts/prepare-ios-release.sh` prepares the release
configuration; then use `ios/Runner.xcworkspace`. Icon resources are maintained
directly; follow [the logo guide](docs/app-logo-installation.md).

Track cleanup and runtime evidence in [performance baselines](docs/performance-baselines.md).

Watch Plans ownership: start with
[`watch_requests_screen.dart`](lib/features/social/presentation/pages/watch_requests_screen.dart),
then its [controller](lib/features/social/presentation/controllers/watch_requests_controller.dart)
for loading/state, or the named [action flows](lib/features/social/presentation/watch_requests/)
for responses, schedules, completion and choices. The
[cleanup record](docs/performance/2026-10-07-watch-requests-cleanup.md) includes
local fixture setup and before/after evidence.
