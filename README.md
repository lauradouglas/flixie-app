# Flixie

Flixie is a Flutter app for discovering, tracking and discussing movies and TV,
and arranging Watch Plans. The mobile app targets iOS and Android. Its API lives
in the sibling `../FlixieBE` repository; `admin-dashboard/` is a separate web app.

## Start locally

Use **Flutter 3.44.0**, the version pinned by the regression workflow. Native
builds also need Xcode/CocoaPods for iOS or the Android SDK/JDK for Android.
See [testing setup](docs/testing.md) for the pinned Patrol tools.

Daily debug builds use **local Firebase Auth, Firestore and Storage**, under
`demo-flixie-local`, with the existing local PostgreSQL backend. They do not use
the production Firebase credentials or bucket. See
[local Firebase development](docs/firebase-local-development.md) for setup,
Dougasaur login, persistence and device notes.

```sh
# Start Docker Desktop first, then run from the app checkout:
scripts/dev.sh -d <ios-simulator-id>
```

This starts/reuses the local Firebase emulators, starts the existing `postgresql`
container if needed, restores local fixtures and cached original avatars, waits
for the local backend, and runs Flutter. Use `q` or Ctrl-C to stop the session;
only services started by this command are stopped. Existing services and the
shared database stay running. Logs are in `.local/firebase/logs/`.

For Android use `FLIXIE_ANDROID_EMULATOR=true scripts/dev.sh -d
<android-device-id>`. Omit `-d` for Flutter's normal device selection.
In VS Code, select **flixie-app (Mobile - Local Firebase)** (or the Android/Web
local entry) in Run and Debug, then press **Run/F5**. The configured background
task starts the same local services and waits until they are ready before Flutter
launches. Services remain available between debug sessions; use **Tasks: Terminate
Task → Flixie: start local services** to stop services owned by that task.
The VS Code development launch entries also select local
Firebase. Local builds show a `LOCAL` banner and omit cloud push and analytics.
A full restart is required when changing environments.

**Profile/release builds keep production Firebase and the production API.** Keep
`.firebase.json` and the bundled native production configuration for releases;
never replace them with emulator values. Release builds reject the emulator flag.
The existing release preparation scripts remain the release path. The explicit
“Profile - Production” launch entry is available for intentional production checks.

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
