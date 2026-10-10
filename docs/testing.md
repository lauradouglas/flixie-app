# Regression testing

Flixie uses two layers:

- Flutter unit, widget and golden tests: models, state, API contracts, forms,
  search, watchlists, watch plans, chat, themes and responsive layout.
- Patrol native tests: real Flutter components running inside the installed app
  on iOS/Android, with native automation and isolated auth/API fixtures.

Patrol setup follows https://patrol.leancode.co/documentation.
Pinned versions: Flutter 3.44.0, Patrol 4.10.0, patrol_cli 4.8.0.

## Local commands

Install dependencies and the runner:

```sh
flutter pub get
dart pub global activate patrol_cli 4.8.0
```

Full Flutter check (when explicitly requested, or in CI):

```sh
scripts/test-regression.sh
```

Device check (use a dedicated simulator/emulator, never your regular development
installation: Patrol uninstalls the app):

```sh
scripts/test-patrol.sh -d <device-id>
scripts/test-patrol.sh -d <device-id> -t patrol_test/favourites_test.dart
```

The local iOS test simulator created during setup is named **Flixie Patrol**.
The script disables Patrol CLI analytics and applies a simulator-only host
architecture setting for Flutter 3.44. This does not alter release architectures.
Each run also supplies a unique build ID to prevent incremental native builds
from reusing an outdated Dart test bundle.

Android needs Android SDK/JDK 17 and a booted emulator; set ANDROID_HOME to your
SDK location. iOS needs Xcode, an installed simulator runtime and CocoaPods.

## Watchlist reference cleanup

The feature ownership map is in [architecture](architecture.md). New controller,
action-flow and movie-search regressions live in `test/features/watchlist/`.
They use fictional Robin/Sam/Jules accounts and recognisable movie/show titles;
no live database or account is needed. Existing widget, API-batch and native
fixtures remain in their established locations.

```sh
flutter analyze lib/features/watchlist test/features/watchlist
flutter test test/features/watchlist test/watchlist_screen_states_test.dart \
  test/watchlist_recommendation_batch_test.dart test/watchlist_release_status_test.dart \
  test/watchlist_movie_row_test.dart test/tonight_filters_test.dart \
  test/watchlist_large_library_test.dart test/watchlist_widget_sync_test.dart \
  test/watchlist_navigation_button_test.dart test/appearance_test.dart
```

Use the dedicated-device command above with
`-t patrol_test/watchlist_paging_test.dart` for the 400-title scroll journey.
This covers the real widgets/controllers and serializers with isolated fixtures,
not live Firebase, production persistence or push delivery.

## Initial device coverage

- Large watchlist: 400 saved titles load providers/friends in 20-card pages,
  with additional pages requested while scrolling rather than all at once.
- Movie and show ranking: reorder, save API payload, confirmation toast, reopen
  with persisted order.
- Movie and show favourites at ten: replacement prompt, disabled submit before
  selection, cancellation preserves existing items, and confirmed replacement
  removes only the selected item without altering the other category.
- Failed ranking save: no false success or lost order, retry succeeds.
- Friend activity: navigating to a film dismisses its modal; returning from the
  native home screen preserves the destination.
- Favourite gallery: all ten entries are reachable at larger text size without
  layout exceptions.

The fixture app uses production components, themes, models and API serialization.
Native tests that start requests from frame callbacks use `useApiFixture` from
`test/support/api_fixture.dart`: those callbacks do not retain the zone used by
`http.runWithClient`. The helper restores normal networking in teardown.
Record requests inside the fixture callback and assert their methods, paths and
bodies from the test body. Calling `expect` inside a native frame's HTTP callback
can throw `OutsideTestException` before the request is recorded; a widget may
then handle that exception as a load failure, obscuring the fixture problem.
It does not start the full production bootstrap, Firebase login or a live backend.
These tests therefore do NOT prove that real login, push delivery, database
constraints, external providers, or live ranking persistence are healthy. Add a
separate staging-account suite for those; never run write tests against real users.
The earlier PostgreSQL locking error needs backend integration coverage, not
just a mocked mobile test.

## Pull requests

`.github/workflows/regression.yml` runs Flutter checks on pull requests, pushes
to main and manual dispatch. The slower Patrol iOS simulator job runs only on
manual dispatch with `run_patrol` explicitly selected; it is disabled by default
and never runs automatically. Both jobs have a 20-minute timeout. Failure
artifacts are uploaded.
Android's native runner is configured for local/device-farm execution; Android
device execution is not yet a CI job.
The GitHub workflow must be pushed before it can run; local validation does not
verify GitHub runner provisioning. Android device execution is not yet verified.

Keep the optional Patrol job out of required branch-protection checks. The
workflow must be enabled in GitHub for automatic Flutter checks to run.

## Baseline cleanup during setup

The initial full Flutter run returned **616 passed / 12 failed**. Those failures
were investigated rather than skipped:

- Search expectations now exercise the actual 400 ms debounce and retain checks
  for cancelled submissions and stale responses.
- Watchlist refresh now opens the filter menu containing the control.
- Auth timeout asserts recovery state and a retained Firebase session.
- Three Watch Plan empty-message expectations use the current approved copy.
- Fixed a real list-update bug: unrelated edits no longer send `groupId: null`.
  Moving to PERSONAL still explicitly clears it; reassignment is also tested.
- Inspected the five golden differences: only the previously requested fallback
  avatar changes differed. Updated those specific baselines.

After cleanup, the full local gate passed: analysis clean and **630 Flutter tests passed**.
The native suite also passed on the dedicated iPhone 17 Pro / iOS 26.5 simulator:
**9 Patrol tests passed, 0 failed, 0 skipped** (19 September 2026).
No tests are excluded. The CI job fails on any failing assertion.

The large-watchlist follow-up passed a 635-test full run, 24 focused watchlist
checks, and the native 400-title paging test. The native fixture-client change
also passed its cross-zone test and existing API recovery tests. Search and
friends filters are checked against offscreen matches, not only the first page.

## Adding tests

Use stable keys/tooltips or visible labels, await meaningful UI state, and assert
persisted outcomes and error recovery. Avoid fixed sleeps, real user data, and
tests that only check that a screen exists. Keep fixture HTTP expectations strict.
For each bug, first write the failing user journey, then fix it and rerun the
smallest relevant suite. Add backend contract tests for database-only failures.

## GitHub runner parity

The project explicitly disables Flutter's automatic Swift Package Manager
migration in `pubspec.yaml`. RunnerUITests currently imports Patrol through
CocoaPods; clean runners must use the same integration as local builds. Migrate
both the app and native test target together before enabling SwiftPM.

Golden checks keep the committed reference images. The shared comparator allows
only sparse RGB rounding: at most 0.05% of pixels may differ, each RGB channel by
at most 2/255, with alpha and image dimensions unchanged. This covers the seven
reviewed failures from GitHub run 35461189419 (16–107 pixels, maximum channel
difference 2). A single larger colour difference, transparency change, resize,
or broader drift still fails and writes the usual comparison artifacts. Tests
exercise these rejection boundaries; do not increase tolerance to mask a new
visual change.


## Movie score privacy

Settings → Preferences → **Rate movies first** is off by default and saved per
account on the current device. It hides other users’ movie scores and public
averages until a confirmed personal rating exists. TV and the viewer’s own scores
remain visible. A failed eligibility load keeps unknown movie scores hidden and
provides a retry. Review prose, chat messages, recommendations and rating counts
are not censored.

`test/movie_rating_privacy_test.dart` covers persistence, account-switch races,
failed loads, immediate unlocks, chat movie/TV/ownership rules, and large text.
`patrol_test/movie_rating_privacy_test.dart` exercises the setting and a successful
rating save through the movie service on an isolated fixture account.


## First-time setup

Signup collects credentials, consent, required first and last names, and an avatar.
Both the form and backend reject missing or blank names. Country now lives with streaming
services in setup. Taste selection supports both media types and is optional;
selected titles become profile favourites in selection order, without adding
watches or ratings. Skipping adds no favourites. Account-scoped taste seeds
are stored on this device and can reorder server-eligible Home movie picks.
Explicit genre preferences and streaming services are saved to the account.

Setup offers library import, viewing preferences, real recommendations with
regional availability, watchlist actions, friend discovery and an optional tour.
Completion failures remain retryable. Notification permission is requested only
from an explicit contextual opt-in, not authentication.

`setup_flow_test.dart` covers country/provider saves, retry, movie/TV identity,
skipping, the search contract, watchlist addition and responsive layouts.
`patrol_test/setup_test.dart` exercises movie/TV picks and adding a show on a
fixture account. `notification_opt_in_test.dart` protects consent timing.

### Genre communities

Focused UI checks: `flutter test test/genre_communities_test.dart`.
Native join → review → leave journey (isolated fixtures):
`scripts/test-patrol.sh -d <dedicated-test-device> -t patrol_test/genre_communities_test.dart`.
The backend has a focused `src/routes/genreCommunities.test.ts` API test and a
local-only rollback verification script; see `../FlixieBE/docs/genre-communities.md`.
Verified 26 September 2026: genre join/read/leave passed on the dedicated
**Flixie Patrol** iOS simulator; focused genre widget tests and backend privacy,
pagination/aggregation integration checks passed. No golden baselines changed.

Anime extension: `test/genre_communities_test.dart` includes mixed movie/show IDs,
separate member averages and joining; seven widget tests pass. Backend Anime API
checks and rollback local integration cover exact keywords, joining/leaving,
private/nonmember exclusions, member scores and tied mixed-media pagination.
The dedicated Patrol community journey now runs for Horror and Anime series.
Anime verification completed: seven Flutter tests, clean focused analyzer, two
API tests, rollback database checks, 12 build-70 checks and both dedicated iOS
Patrol journeys pass. Production was not modified.

## Watch-plan native journeys

Run the focused suite on the dedicated simulator:

```sh
scripts/test-patrol.sh -d D4255A47-A9F1-4BFB-A770-557608119574 -t patrol_test/watch_plans_test.dart
```

`watch_plans_test.dart` exercises production creation sheets, the friend detail
screen, and the group V2 screen through the real API serializers. Its strict,
stateful `support/watch_plan_fixture.dart` uses fictional accounts and no live
network or database writes. Unexpected API paths fail the test.

The eleven journeys cover:

- Single-film invitation creation in date-only and timed modes, including a
  failed save, retry, and closing the sheet only after success.
- Exact calendar-date storage for date-only plans and exact local-to-UTC
  conversion for the chosen 19:30 time.
- Friend and group invitation responses with failed-save recovery.
- Date-only and timed schedule proposals, preserving the flag after native
  background/foreground transitions.
- Date-only agreement with a 9am-only reminder policy and all-day calendar data.
- Timed rescheduling: the original schedule remains until agreement, then the
  replacement survives a fresh detail load. Reminder and calendar data retain
  the exact agreed time.
- Multiple-film group picks followed by the creator's final-film selection,
  retaining the original options and other members' choices.
- The invited person adds Obsession to Alien/The Odyssey, existing films are
  filtered out of search results, their picks save without changing the creator's
  picks, and all three options survive a fresh detail load.
- A watch with a rating and review that still succeeds when secondary aggregate
  rating sync fails, without duplicate watch submissions on app resume.

These are native UI-to-API integration journeys, not live-server tests. They
validate reminder policy and calendar event data; they do not prove OS push
notification delivery, calendar permission handling, or PostgreSQL constraints.
The focused watch-plan model, lifecycle, calendar, reminder and backend service
regressions remain complementary checks. Patrol must not use production login
credentials or the everyday development simulator.

### Real local HTTP and PostgreSQL watch-plan journeys

From `../FlixieBE`, with the local database enabled and migrated:

```sh
npm run test:watch-plans:e2e:local
```

`scripts/test-watch-plans-e2e.ts` mounts the production Express routers on a
temporary loopback server and uses real authorization, services, transactions
and Prisma persistence. It refuses non-local database targets, creates fresh
fictional users and a private group, then removes their rows in `finally`.
Local metadata must include Alien, The Odyssey and Obsession.

It checks date-only creation/acceptance and fresh API state, exact timezone
conversion for timed plans (including older requests without the optional flag),
accepted and declined reschedules, agreed transitions between date-only and timed
plans, an invited person adding Obsession without
overwriting the creator's picks, creator-only final selection, outsiders and
identity spoofing, duplicate options, and invalid ratings before any diary write.
Direct and group ratings, notes and linked diary entries are read back from SQL;
repeated saves must retain one entry. A missed participant must have no diary
entry. Group date-only agreement, final completion and multiple-film creation,
member additions and creator selection are also checked.

Only Firebase identity verification and external chat transport are isolated.
Chat/Firestore delivery deliberately fails while real SQL writes and stored
notifications run, verifying that creation still reports success. This complements
the native fixture suite; neither suite verifies live Firebase authentication,
OS reminder delivery, calendar permissions or production deployment.

Verified locally on 4 October 2026: all 11 native journeys passed on Flixie
Patrol (iOS 26.5), and all six real HTTP/SQL journey groups passed. The final
native bundle was rerun without rebuilding after recovering a simulator launch
failure. Build-70 compatibility passed all 17 checks; focused error/policy tests
passed all 12, and Dart analysis plus backend/runner TypeScript checks passed.

### Four-member group Watch Plans

See [the complete scenario inventory](group-watch-plan-test-scenarios.md) for all
25 real HTTP/PostgreSQL scenarios, 13 shared native/widget journeys, run commands,
persistent four-member local fixtures, product fixes and verification boundaries.
The coverage includes partial declines and recipient filtering, date-only and timed
schedules, replacement proposals, individual votes, later film additions,
permissions, closed plans and idempotent independent watch logging.

### Foreground notification policy

`flutter test test/foreground_social_notice_test.dart test/foreground_watch_plan_notice_test.dart test/watch_plan_notice_preview_test.dart`

20 focused cases passed on 4 October 2026. Direct messages show a banner outside
their conversation; the open conversation stays quiet. Friend/group invitations
open the actionable inbox. Routine group chat, reactions, film votes and shortlist
additions remain quiet. Other Watch Plan lifecycle banners retain current-plan
navigation and delayed-event protection. Foreground FCM handling never falls back
to a system notification; background delivery remains unchanged. These tests cover
payload policy and real widgets, not live APNs/FCM delivery or Android scheduled
local-reminder presentation. Development app notification initialization was
hot-restarted after the change.

### Grouped community replies

Backend: `npm run test:community-replies:e2e:local` runs guarded local PostgreSQL
checks for 100 replies to a post and 100 to a discussion, in concurrent batches.
It verifies one inbox row per recipient/conversation, zero reply pushes, preserving
read state on immediate duplicate delivery, unread refresh on new replies, reopening
a dismissed digest, distinct conversations and preferences. Legacy individual reply
cards are closed on the next reply to that conversation. Fixtures are isolated and
cleaned up. Backend route/privacy and mention tests plus build-70 checks also pass.

Flutter: `flutter test test/notification_inbox_test.dart test/foreground_social_notice_test.dart test/notification_destination_test.dart`
verified 33 cases, including displaying the grouped discussion summary and no
community-reply banner. No production migration or deployment was performed.

## Focused notification suite

Run `scripts/test-notifications.sh` for notification delivery, banner, inbox,
permission-offer, reminder and routing regressions across the app and backend.
Use `scripts/test-notifications.sh --local-db` to also exercise isolated local
community-reply digests and friend/four-member group plan journeys. The detailed
scenario list and live-device verification boundaries are in
[notification-test-scenarios.md](notification-test-scenarios.md).

## Notification return navigation — 5 October 2026

Focused Flutter navigation checks: `flutter test test/notification_inbox_navigation_test.dart test/notification_navigation_matrix_test.dart test/notification_destination_exit_test.dart test/foreground_notification_navigation_test.dart test/chat_back_button_test.dart test/watch_plan_back_navigation_test.dart`. These exercise real inbox cards, the production foreground/tap handlers, actual destination loading/error states, preserved drafts, duplicate callbacks, and Home fallback.

Device checks: `scripts/test-patrol.sh -d <dedicated-device> -t patrol_test/notification_navigation_test.dart`. Fictional fixtures cover banner → inbox → group invitation → Back → original draft, and cold community-post navigation → Home, both across native background/resume. They do not send a real APNs/FCM push or log into a production account.

Validation: 223 focused notification/navigation tests and 54 existing media/profile/community tests passed. The 38-case matrix also passed with modal and immediate-duplicate checks. The two dedicated Patrol journeys passed on both iOS and Android (four device cases, no skips). Final shared-navigation analysis is clean. The earlier repository-wide test failures are not resolved by these focused results.

## Movie Detail cleanup and baseline checks

Run the focused ownership/loading tests after changing Movie Detail sections:

```sh
flutter test test/features/movies/ test/movie_detail_loading_test.dart test/movie_detail_cache_test.dart test/movie_images_test.dart test/video_card_test.dart test/rewatch_log_sheet_test.dart
```

The 6 October extraction also passed the actual-screen notification destination
exit regressions. Request/concurrency budgets are covered by
`test/watchlist_large_library_test.dart`, and TV progressive loading by
`test/show_progressive_loading_test.dart`. See
[performance baselines](performance-baselines.md) for the frozen repository
snapshot, fixture observations and outstanding profile-device measurements.
Test wall-clock duration does not measure app performance.

Movie Detail's second extraction adds save-failure/retry, favourite membership,
late-viewer-save isolation and friend search/profile navigation checks. The focused
70-test set passed. Native favourites and social/navigation checks use the dedicated
Patrol simulator; `movie_detail_social_test.dart` checks the extracted friends sheet.

### Populated simulator runtime ledger

Startup/login/resume captures also use the native Firebase SDK against disposable
local Auth/Firestore emulators. From the backend checkout, in a separate terminal:

```sh
JAVA_HOME="$(/usr/libexec/java_home -v 21)" firebase emulators:start --only auth,firestore --project demo-flixie-review --config scripts/runtime-emulators.json
```

Keep the local PostgreSQL fixture API below running. Then, from this checkout:

```sh
python3 scripts/capture-lifecycle-baseline.py --device <dedicated-ios-simulator-id> --output docs/performance/<new-lifecycle-directory>
python3 scripts/capture-startup-baseline.py --device <dedicated-ios-simulator-id> --output docs/performance/<new-startup-directory>
```

Run these **sequentially**, with no other iOS builds in this checkout: each runner
temporarily replaces the native Firebase plist with a demo-only config during its
build/run and restores its exact original bytes in `finally`. It refuses to overwrite
concurrent plist edits. Original config contents are never exported. Both runners
seed only two fictional demo Auth identities, use localhost services and require a
dedicated simulator; they install/reinstall the app. The startup target is an
autonomous benchmark entrypoint and must never be distributed.

The lifecycle test measures fresh app/auth-root startup in one Patrol process,
real Login form submission and native home/openApp resumes. The original reference
records two profile reads on the first resume. The current regression asserts one
AuthProvider-owned profile read, reused by Home, and none on the next within the
production throttle. Manual refresh and action-triggered updates retain profile reads.
The startup runner separately terminates and launches fresh native processes and
Flutter engines, retaining the native Firebase session between launches. It measures
the host launch request to a completed Login/Home frame marker; polling/HTTP overhead
is included. Both use the actual FlixieApp/router/AuthProvider. App Check, FCM/APNs,
social-provider dialogs, production network latency and physical release performance
are outside the local fixture scope. Source snapshots, logs, raw samples and summaries
are saved only as successful baselines after complete captures.

Focused correctness checks:

```sh
flutter test test/auth_recovery_test.dart test/home_startup_recovery_test.dart test/auth_prefetch_overlap_test.dart
dart analyze patrol_test/runtime_lifecycle_baseline_test.dart tool/runtime_startup.dart lib/features/home/presentation/pages/home_screen.dart
```

Prepare the isolated database and start the fixture API in the backend checkout:

```sh
node scripts/prepare-runtime-database.cjs
node scripts/start-runtime-benchmark.cjs
```

These tools read only the **local** catalogue URL. They create the separately named
`flixie_runtime_fixture` database and copy catalogue data without account, rating,
review or group records. The seed refuses non-fixture accounts and is rerunnable.
Its 42 fictional users include 20/400-film libraries and privacy/spoiler cases.
The API binds to `127.0.0.1:3007`; Firebase identity verification is isolated in this
process, real routes/services/SQL run, and write routes are unavailable. Cached
provider availability is fictional; TMDB trending/detail transport reads the local
catalogue. External cast payloads are empty; catalogue image URLs remain present.
The real analytics controller runs with collection disabled for fixtures. This
harness does not start production background workers.

Capture from the Flutter checkout:

```sh
python3 scripts/capture-runtime-baseline.py --database --device <dedicated-ios-simulator-id> --output docs/performance/<new-dated-directory>
```

Patrol reinstalls the app. The benchmark exports each sample to the local collector
before simulator cleanup, records five selected-cache-reset/cached pairs for five
scenarios,
and produces a raw JSON ledger plus a summary. It does not enforce machine-dependent
speed gates. Run the backend harness type check with
`node node_modules/typescript/bin/tsc -p scripts/runtime-tsconfig.json`.

## Home loading ownership and subscription checks — 7 October 2026

Run the focused controllers and real-widget subscription/layout checks:

```sh
flutter test test/features/home/home_controller_test.dart test/features/home/home_watch_plans_controller_test.dart test/features/home/home_subscriptions_test.dart test/features/home/home_hero_card_test.dart
```

Controller checks cover late/account-switched responses, disposal, overlapping
refreshes, retained errors versus denied access, snapshot revalidation, independent
section loading and resume profile reuse. Subscription checks retain actual hero
Card identities across notification/profile/recommendation updates and verify
per-movie friend updates. Hero checks cover phone/tablet/landscape at text scales
1 and 2 with real action taps. The wider focused Home/auth/plan suite is listed in
[the cleanup record](performance/2026-10-07-home-cleanup.md); 79 checks passed.

Use the existing lifecycle capture runner for the same 20/400-library comparison.
Transport exceptions are recorded separately from HTTP status failures and missing
responses. Retain partial collectors and failed native logs; never report an
incomplete capture as a successful baseline or weaken the useful-title assertion.

## Reliable lifecycle capture transport

The isolated runtime API now keeps idle connections for 60 seconds, longer than
Dart's default idle pool lifetime. Restart an older fixture API process before
capturing; its manifest includes `transport.keep_alive_ms` and Node version.
`scripts/probe_runtime_transport.dart` issues 100 real manifest reads over five
bursts, with six-second idle gaps, and fails on any error. Run it before the native
capture so it does not interfere with measured windows.

Lifecycle captures reject missing/extra responses, HTTP failures and recorded
transport exceptions, retaining `native.json` and `transport-audit.json` for
investigation. A visible useful title alone is insufficient for a reliable baseline.
See [the reliability record](performance/2026-10-07-reliable-login.md) for evidence.

## TV Detail checks — 7 October 2026

```sh
flutter test test/show_progressive_loading_test.dart test/show_episode_progress_test.dart test/features/movies/show_detail_controller_test.dart test/features/movies/show_detail_action_flow_test.dart test/features/movies/show_detail_screen_test.dart
scripts/test-patrol.sh -d <dedicated-ios-simulator-id> -t patrol_test/show_detail_test.dart
```

The 45 focused checks cover progressive loading, independent retry, account and
refresh guards, disposal, rating metadata, episode progress, partial season saves,
Undo, spoiler visibility and future episodes. Real screen layout checks cover
small/large phones, tablet and landscape with text scales 1 and 2. The native
journey also checks Watchlist remains available when all ten favourite slots are
occupied. Its fictional Alien: Earth fixture uses mocked writes, released and
future episodes; it cannot alter real accounts. The runtime capture runner automatically uses the
demo configuration wrapper in `scripts/runtime_ios_fixture.py`, which restores
both native plist files afterwards. Evidence and benchmark boundaries are in
[the TV cleanup record](performance/2026-10-07-tv-detail-cleanup.md).

For a TV-only mounted runtime reference using the populated local PostgreSQL API:

```sh
python3 scripts/capture-runtime-baseline.py --database --scenario tv_detail --device <dedicated-ios-simulator-id> --output docs/performance/<new-tv-directory>
python3 -m unittest discover -s scripts/tests -p test_runtime_capture_scope.py
```

This requires exactly ten unique TV samples: five reset/cached pairs. Omitting
`--scenario` retains the existing 50-sample full ledger. The runner rejects
incomplete or unexpected scenario/cache/repetition sets. Transport exceptions
are captured separately from HTTP failures; the TV report retains the isolated
provider-refresh failure rather than treating it as a healthy service.

## Own Profile cleanup checks — 7 October 2026

```sh
flutter test test/features/profile/profile_controller_test.dart test/features/profile/profile_action_flow_test.dart test/features/profile/profile_screen_test.dart test/profile_lazy_stats_test.dart test/profile_tab_scroll_test.dart test/profile_favourites_library_test.dart test/profile_combined_activity_test.dart test/profile_stats_insights_test.dart test/profile_library_totals_test.dart test/favourite_editing_test.dart test/favourite_limits_test.dart test/profile_header_layout_test.dart test/ratings_sheet_test.dart test/profile_avatar_size_test.dart test/profile_avatar_test.dart
scripts/test-patrol.sh -d <dedicated-ios-simulator-id> -t patrol_test/profile_screen_test.dart -t patrol_test/profile_gallery_test.dart -t patrol_test/profile_library_totals_test.dart -t patrol_test/favourites_test.dart
python3 scripts/capture-runtime-baseline.py --database --scenario profile --device <dedicated-ios-simulator-id> --output docs/performance/<new-profile-directory>
```

The 52 focused checks cover own Profile's loading, account/disposal guards,
filters/paging, lazy/coalesced Stats, notification rebuild scope, Continue
Watching save/Undo/failure, gallery/ranking/totals wiring, avatar behavior and
ratings navigation. Whole-screen checks use 320×800, 390×850, 1024×800 and
844×390 at text scales 1 and 2. The native actual Profile journey additionally
opens all ten fictional favourite movies and returns between all three tabs.

`--scenario profile` is opt-in and requires ten unique samples; default captures
remain the original five screens / 50 samples. Profile measures a mounted page
with a preloaded fictional user, Library completion and Activity/Stats/Library/
cached-Stats switches. Raw `profile_tabs` retains elapsed time and reads for each
switch. The native capture asserts no eager reviews/wrapped reads and no reads
when returning to loaded Stats. It uses the existing populated local PostgreSQL
fixture with fictional 20-film account; this is separate from login/OS startup.
Use the demo native configuration wrapper for manually invoked native journeys;
the runtime capture runner applies/restores it automatically.

## Friend Profile cleanup checks — 7 October 2026

```sh
flutter test test/features/profile/friend_profile_controller_test.dart test/features/profile/friend_profile_action_flow_test.dart test/features/profile/friend_profile_screen_test.dart test/friend_profile_milestones_test.dart test/friend_rating_privacy_surfaces_test.dart test/list_profile_privacy_test.dart test/movie_rating_privacy_test.dart test/notification_destination_exit_test.dart
scripts/test-patrol.sh -d <dedicated-ios-simulator-id> -t patrol_test/friend_profile_test.dart
python3 scripts/capture-runtime-baseline.py --database --scenario friend_profile --device <dedicated-ios-simulator-id> --output docs/performance/<new-friend-profile-directory>
```

The 74 focused checks cover the controller's viewer/subject/disposal generations,
refresh/paging races, compatibility agreement and active favourites, no reads for
notification-only changes, unavailable profiles, retries, real friendship writes,
overlap/failure/stale confirmations and stale open comparison sheets. Actual
screen checks cover badge borders, preview/privacy and incoming Accept/Decline,
same-route subject changes, and all three tabs at four phone/tablet/landscape
sizes with text scales 1 and 2. A 40-row activity check protects lazy rendering
and verifies the last row is reachable without a duplicate fetch. Existing milestone, rating/list privacy and
notification Back/Home regressions remain part of this focused selection.

The native fixtures are fictional, use a mocked transport and cannot change real
accounts. They cover the actual Friend Profile ten-film gallery and tab returns,
and accepting an incoming request in preview mode. Use the temporary demo native
configuration wrapper described above when invoking them manually.

The new `friend_profile` runtime scenario is opt-in, with ten samples; default
captures remain 50. It mounts `runtime-fixture-2` (150-film library, 100 ratings,
ten reviews) as seen by fictional 20-film viewer `runtime-fixture-0` through the
real local PostgreSQL/API. Useful content means the fetched profile's totals,
not preloaded own Profile, app startup or login. Samples include five Overview
flings and Activity/Reviews/Overview/cached-Reviews visits; tab times and reads
are saved in `profile_tabs`. Returning to Reviews asserts zero new reads. Both
runs use the same scenario and native scroll navigation. See
[the cleanup record](performance/2026-10-07-friend-profile-cleanup.md) for results
and limitations.

## Account lifecycle runtime capture

With the existing isolated runtime PostgreSQL API on port 3007 and demo Firebase
Auth/Firestore emulators running, capture logout and the subsequent account's
login on the dedicated Patrol simulator:

```sh
python3 scripts/capture-lifecycle-baseline.py --scope accounts \
  --device D4255A47-A9F1-4BFB-A770-557608119574 \
  --output docs/performance/<new-account-capture-directory>
python3 -m unittest scripts/tests/test_lifecycle_transport_audit.py
```

This opt-in scope records 20 timings and 40 service-GC allocation observations.
It alternates the fictional 20/400-film accounts using production auth/session
logic and real native emulator email sign-in. Logout and target login are separate
legs; form entry and GC are outside timing. The reporter requires every condition,
clean HTTP accounting and advancing GC timestamps. The default scope still records
50 startup/login/resume samples. Push registration is disabled; production push
token cleanup latency cannot be inferred from this demo project.

For the separate auth retaining-path investigation, add `--retaining-paths` to
`--scope accounts`. It records 60 service-GC observations, including one after
each per-cycle async function returns and an account-free text-input replacement
control. Retaining paths contain class/reference labels only. Paths are collected
with a 1,000-element limit and must be complete; `getInstances` counts are recorded
separately because additional allocations/collection can occur after the allocation
profile. The control asserts zero surviving `_LifecycleAuth` instances after the
neutral field is removed. It changes the diagnostic environment outside timed
windows, so its timings must not be presented as an app performance improvement.


## Auth account-cache ownership

Focused owner and facade regression checks:

```sh
flutter analyze lib/core/auth/auth_account_cache.dart lib/core/auth/auth_provider.dart \
  test/core/auth/auth_account_cache_test.dart test/auth_recovery_test.dart
flutter test test/core/auth/auth_account_cache_test.dart test/auth_recovery_test.dart \
  test/auth_prefetch_overlap_test.dart test/notification_account_identity_test.dart \
  test/notification_inbox_test.dart test/notification_visibility_test.dart
flutter test test/watchlist_screen_states_test.dart \
  test/watchlist_recommendation_batch_test.dart test/activity_tabs_test.dart
```

The existing lifecycle capture command measures startup/login/resume. Use its
`--scope accounts --retaining-paths` option for logout, subsequent account login
and memory controls. Existing isolated local fixtures remain sufficient: this
ownership extraction adds no feature or database mutation.


## Session recovery ownership checks

Focused virtual-time checks cover shared profile/resume work, forced Retry versus
throttle, capped retries, background cancellation, token revision ordering,
expired sessions, timeouts and account/disposal guards. The facade cases protect
startup restoration and the activity marker consumed by Home.

```sh
flutter test test/core/auth/auth_session_recovery_test.dart test/auth_recovery_test.dart \
  test/home_startup_recovery_test.dart test/auth_prefetch_overlap_test.dart
flutter analyze lib/core/auth/auth_session_recovery.dart lib/core/auth/auth_provider.dart \
  test/core/auth/auth_session_recovery_test.dart test/auth_recovery_test.dart
```

Use the existing populated lifecycle runner for startup/login/resume, and its
`--scope accounts --retaining-paths` mode for logout/switch/disposal controls.
Source fingerprints include the recovery owner. Allocation counters for the owner
are observations, not a separate live-instance or retaining-path diagnosis.
See [the recovery record](performance/2026-10-07-session-recovery.md) for matched
references, results and validation limitations.


## Person Detail cleanup checks

```sh
flutter test test/features/movies/person_detail_controller_test.dart \
  test/features/movies/person_filmography_selection_test.dart \
  test/features/movies/person_detail_screen_test.dart test/person_image_test.dart
flutter test test/notification_destination_exit_test.dart --plain-name 'person actual screen'
scripts/test-patrol.sh -d <dedicated-device> -t patrol_test/person_detail_test.dart
python3 -m unittest scripts.tests.test_runtime_capture_scope
python3 scripts/capture-runtime-baseline.py --database --scenario person_detail \
  --device <dedicated-device> --output docs/performance/<fresh-person-capture>
```

Controller tests cover invalid IDs, retries, image fallback, late responses,
disposal, duplicate favourite taps and account changes. Widget checks cover
favourite outcomes, all-year reset, search/media filters, sheet navigation,
account guards, photos and narrow/large/landscape layouts at up to 2× text.
Patrol uses strict fictional fixtures for favourite writes; it never saves to a
real account. The populated capture uses the guarded local PostgreSQL/API runtime
fixture: Casey Runtime (`990000001`), 120 catalogue movie credits, one TV credit,
overlapped crew jobs and three catalogue poster substitutes for photos. It adds
full-credit browsing, Alien search and TV filter stages with per-stage request
counts. Person Detail is opt-in; the default 50-sample capture remains unchanged.
See [the cleanup record](performance/2026-10-08-person-detail-cleanup.md) for
recorded results and the distinction between debug observations and release gains.


## Controlled Person Detail memory investigation

Use the isolated populated runtime API on localhost:3007 and a dedicated simulator
whose name contains Patrol or Memory. The runner reinstalls that simulator's app.

```sh
python3 scripts/capture-person-memory.py --device <dedicated-device> \
  --order no_images_first --output docs/performance/<fresh-person-memory-1>
python3 scripts/capture-person-memory.py --device <dedicated-device> \
  --order images_first --output docs/performance/<fresh-person-memory-2>
python3 -m unittest scripts.tests.test_person_memory_capture
```

Both archived and current screens run in the same native debug binary, with
controlled locally cached images and an image-free condition. Each fresh process
records 20 visits and 100 GC checkpoints; the second reverses condition order.
Allocation census counters, direct instance counts and retaining paths are
separate observations. A neutral text field replaces the framework's last-input
reference before the final checkpoints. No production writes are made. The
runner audits request/response accounting, GC timestamps, image controls and
unchanged source, and restores temporary native demo configuration. See
[the investigation record](performance/2026-10-08-person-memory.md) for results
and limits; this is not a release/physical-device benchmark.


## Controlled Group Watch Plan memory investigation

Use the isolated populated API on localhost:3007 and a dedicated Patrol/Memory
simulator. This reinstalls that simulator's app. Run both orders with unchanged
source and database fixtures:

```sh
python3 scripts/capture-group-memory.py --device <dedicated-device> \
  --order no_images_first --output docs/performance/<fresh-group-memory-1>
python3 scripts/capture-group-memory.py --device <dedicated-device> \
  --order images_first --output docs/performance/<fresh-group-memory-2>
python3 -m unittest scripts.tests.test_group_memory_capture
```

Each process warms both archived/current pages, then records 20 visits and 100
GC checkpoints. The four-group/twelve-plan fixture supplies real database reads;
only poster/backdrop URLs change to deterministic locally cached PNGs (342×513
and 1280×720), or null for the image-free control. The journey scrolls, switches
Past/Active, refreshes singly and jointly, opens a detail and returns. Refresh
signals after close must cause no reads. The collector checks exact 40-before/
36-current request budgets, responses, increasing GC timestamps, image controls,
direct owner counts and unchanged source. It records retaining paths separately
from allocation counters. Neutral input removes framework last-interaction roots
before the final image-cache-cleared observation. This is a debug simulator
investigation, not a release-device performance claim. See the
[9 October findings and residuals](performance/2026-10-09-group-memory.md).

## Group Watch Plan cleanup checks

```sh
flutter test test/features/watch_plans test/group_watch_plan_journeys_test.dart \
  test/watch_plan_foreground_refresh_test.dart test/group_watch_plan_tab_test.dart \
  test/watch_plan_back_navigation_test.dart test/group_watch_plan_completion_test.dart
scripts/test-patrol.sh -d <dedicated-device> -t patrol_test/group_watch_plans_test.dart
python3 -m unittest scripts.tests.test_runtime_capture_scope scripts.tests.test_group_plan_capture
python3 scripts/capture-runtime-baseline.py --database --scenario group_watch_plan \
  --device <dedicated-device> --output docs/performance/<fresh-group-plan-capture>
python3 scripts/audit-group-plan-baseline.py docs/performance/<fresh-group-plan-capture>
```

Use the existing guarded runtime PostgreSQL/API fixture on localhost:3007 for the
read-only benchmark: four four-member groups and 12 plans, using fictional accounts
and catalogue titles. The current budget is nine reads on load, refresh, combined
refresh signals and detail opening; Past/Active/back add none. The audit's
`--before` option is only for the preserved original 13-read refresh-burst reference.
Save actions use the four-member in-memory fixture shared by widget and native
journeys. Test account/route changes, delayed reads, duplicate writes, subscription
disposal, narrow/large/landscape layouts and increased text size.
See [the cleanup record](performance/2026-10-08-group-watch-plan-cleanup.md).

## Watch Request composer checks

```sh
flutter test test/features/movies/watch_composer test/watch_plan_friends_loading_test.dart \
  test/group_provider_match_test.dart test/watch_plan_date_only_test.dart
scripts/test-patrol.sh -d <dedicated-device> \
  -t patrol_test/watch_composer_test.dart -t patrol_test/watch_plans_test.dart
python3 -m unittest scripts.tests.test_composer_capture scripts.tests.test_runtime_capture_scope
python3 scripts/capture-runtime-baseline.py --database --scenario watch_composer \
  --device <dedicated-device> --output docs/performance/<fresh-composer-capture>
python3 scripts/audit-composer-baseline.py docs/performance/<fresh-composer-capture>
```

Use the existing isolated populated runtime fixture on localhost:3007. The measured
viewer has 40 friends and four overlapping groups. The benchmark selects actual
recipient tiles, centres them within nested scroll views and verifies their checked
state. Current expected reads: four cold/three warm on load; one per new friend;
two for each of the first two groups; one to revisit the first group; none when
revisiting the friend. Mode switches add no reads. The audit's `--before` flag is
only for the archived original's repeated provider lookups.

Shared native/widget journeys cover friend/group save retries, cinema browsing,
search, account-switch sheet removal, provider reuse and analytics failure after a
confirmed save. Unit checks cover stale replies, disposal, in-flight sharing,
request bodies, candidate limits and date-only encoding. Responsive checks cover
small/large phones, landscape and tablets with 2× text. All fixtures are fictional;
the populated timing capture is read-only and does not benchmark SQL send latency.
See [the composer record](performance/2026-10-08-watch-composer-cleanup.md).

## Group Insights cleanup checks

```sh
flutter test test/features/social/group_insights test/group_insights_loading_test.dart
scripts/test-patrol.sh -d <dedicated-device> -t patrol_test/group_insights_test.dart
python3 -m unittest scripts.tests.test_insights_capture scripts.tests.test_runtime_capture_scope
python3 scripts/capture-runtime-baseline.py --database --scenario group_insights \
  --device <dedicated-device> --output docs/performance/<fresh-insights-capture>
python3 scripts/audit-insights-baseline.py docs/performance/<fresh-insights-capture>
```

The populated read-only capture uses the existing isolated PostgreSQL/API fixture
on localhost:3007: `runtime-plan-group-0` has ten watched/rated titles, ten reviews,
three discussion titles and four contributors in both tested periods. No additional
seed or production credentials are required. Five cold/warm pairs measure opening,
five flings, All time, repeated All time, This month, refresh and simultaneous
refresh callbacks. The exact budget is five HTTP reads per visit in both versions;
reselecting the active period adds none. The shared API client already merges the
simultaneous identical GETs. Auditing checks query periods as well as endpoint counts.

Focused tests cover account/group/period changes, stale failures and results,
disposal, fresh reads after completion, sync/async failure retries, empty-group
handling, rating privacy, badge mappings, spoiler reset, movie/profile navigation
and narrow/large/landscape/tablet layouts at 1×/2× text. Six journeys share their
implementation between widget and native Patrol execution. All mocked identities
are fictional. The native action suite uses isolated HTTP fixtures; the timing
capture uses populated SQL reads. See the
[cleanup report](performance/2026-10-09-group-insights-cleanup.md) for results and limits.

### Controlled Group Insights memory check

`patrol_test/group_insights_memory_test.dart` compares the frozen pre-cleanup tab
with the current tab in the same process, using real isolated database reads and
controlled poster images. This is separate from the six Insights correctness
journeys and the timing ledger. Run both fresh-process image orders on a dedicated
simulator (Patrol reinstalls the app):

```sh
python3 -m unittest discover -s scripts/tests -p 'test_insights_memory_capture.py'
python3 scripts/capture-insights-memory.py --device <dedicated-simulator> --order no_images_first --output docs/performance/<date>-insights-memory-no-images-first
python3 scripts/capture-insights-memory.py --device <dedicated-simulator> --order images_first --output docs/performance/<date>-insights-memory-images-first
```

Use a fresh output folder each time. The local API on port 3007 must expose the
`flixie_runtime_fixture` manifest and populated Insights for `runtime-plan-group-0`.
Each run validates 20 visits, 100 distinct GC observations, five exact period reads
per visit, HTTP 200 accounting, pending-image state and unchanged sources. The
archive test verifies the before source hash and class-renaming-only adaptation.
No production instrumentation or new seed is required. See the
[Insights memory investigation](performance/2026-10-09-insights-memory.md).

## Search cleanup checks

Search logic tests live in `test/features/movies/search/controller_test.dart`.
Shared user journeys in `patrol_test/support/search_journeys.dart` run as both
widget checks and native Patrol tests: history, paging failure/retry, failed
refresh, collections retry, detail destinations, notification/focus updates and
superseded queries. Layout checks cover 320/430-pixel phones, landscape and a
1024-pixel tablet at normal and 2× text. Rating privacy covers result and trending
cards. Keep the existing Search service, ranking, debounce, history and deep-link
focus checks alongside these.

```sh
flutter test test/features/movies/search test/search_concurrency_test.dart test/search_screen_requests_test.dart test/search_screen_updates_test.dart test/search_widget_focus_test.dart test/search_popularity_ranking_test.dart
scripts/test-patrol.sh -d <dedicated-simulator> -t patrol_test/search_test.dart
```

For the controlled local native setup, `docs/performance/2026-10-09-search-validation/run-native.py`
uses the existing temporary demo Firebase configuration and restores it afterward.
Patrol reinstalls the app; never use the daily development simulator.

Search is an opt-in runtime scenario; the default five-screen capture is unchanged:

```sh
python3 scripts/capture-runtime-baseline.py --database --device <dedicated-simulator> --scenario search --output <new-directory>
python3 scripts/audit-search-baseline.py <new-directory>
```

The isolated backend's `scripts/runtime-search-fixture.ts` supplies a populated
PostgreSQL catalogue snapshot at the TMDB transport boundary. API controllers and
services still run, but these timings exclude external TMDB latency and per-query
SQL work. The audit requires ten distinct cold/warm samples, exact query/page/mode
sequences, matching HTTP 200 counts and no transport errors. The capture fingerprints
all production Dart and its harness/backend inputs. See the
[dated Search report](performance/2026-10-09-search-cleanup.md) for results and limits.

### Controlled Search memory comparison

`patrol_test/search_memory_test.dart` mounts the frozen pre-cleanup Search reference
and current implementation in one app. The reference is byte-verified against the
archived baseline apart from class names. Two fresh native processes reverse image
condition order and alternate version order; each performs 20 measured visits and
100 GC checkpoints after warming both variants. The populated local Search fixture
remains required. Only image fields are replaced with null or deterministic cached
PNG paths; service/cache behaviour stays real. The full exercised image inventory
is precached before mounted GC and its exact RGBA bytes asserted, preventing lazy
scroll boundaries from changing the paired image control.

```sh
python3 scripts/capture-search-memory.py --device <dedicated-Patrol-simulator> --order no_images_first --output <new-directory>
python3 scripts/capture-search-memory.py --device <dedicated-Patrol-simulator> --order images_first --output <another-new-directory>
python3 -m unittest discover -s scripts/tests -p 'test_search_memory_capture.py'
```

The runner audits query budgets, HTTP responses, GC checkpoints, mounted owner
counts, image controls and source fingerprints. Direct live counts are separate
from allocation census. Post-close retaining paths distinguish the test binding's
last input from shared Trending caching and surviving Search owners. Compare both
neutral-input and cache-cleared phases; raw RSS alone cannot establish a leak.
See the [dated investigation](performance/2026-10-09-search-memory.md) for results
and limits. These captures reinstall the dedicated app and temporarily substitute
demo iOS Firebase configuration, which is restored afterward.

### Onboarding ownership and mounted baseline

Run the existing setup suites plus the account/controller regressions:

```sh
flutter test test/onboarding_screen_test.dart test/setup_flow_test.dart test/setup_activation_test.dart test/setup_communities_test.dart test/setup_destination_test.dart test/features/authentication/
python3 -m unittest discover -s scripts/tests -p 'test_onboarding_capture.py'
```

On a dedicated simulator, `patrol_test/onboarding_journeys_test.dart` groups the
existing setup save/resume and explicit community join/resume journeys. Run
`patrol_test/signup_activation_test.dart` for explicit public-favourites consent.
Use `scripts/test-patrol.sh -d <dedicated-simulator> -t <test-file>`.

With the existing isolated runtime fixture server running on port 3007:

```sh
python3 scripts/capture-onboarding-baseline.py --device <dedicated-Patrol-simulator> --output <new-directory>
```

This capture reinstalls the dedicated app and restores temporary demo iOS Firebase
configuration afterward. It records five mounted visits after one warm-up, checks
four successful catalogue reads per visit and verifies movie/show taste plus one
watchlist save. The catalogue comes from the populated local database snapshot;
country/provider reference data and account writes/completion stay in fictional
fixtures. Images are absent. It does not measure real write latency, full signup,
authentication, production recommendation latency or physical-device performance.
See the [Onboarding cleanup report](performance/2026-10-09-onboarding-cleanup.md).

### Notification legacy-card cleanup — 9 October 2026

The unused `NotificationRequestCard` was removed; the live `NotificationInboxCard`
and notification screen remain unchanged. The same 107 focused inbox, badges,
acceptance, navigation-matrix and foreground-navigation checks passed before and
after removal. Both existing iOS Patrol notification navigation/resume journeys
passed (zero failures/skips). Focused analysis is clean and development hot reload
succeeded. See [the report](performance/2026-10-09-notification-cleanup.md) for
commands, preserved source, fingerprints and logs. No runtime gain is inferred.

### Settings cleanup — 9 October 2026

`test/features/settings/` covers cancellable username checks, stale responses,
disposal, matched obsolete-request counts, scoped page rebuilds, account changes
during saving and editor scrollability at double text size on phone/landscape/tablet.
Run with existing `settings_country_test.dart`, `settings_tile_description_test.dart`
and `username_reservation_availability_test.dart`: 16 cases pass. The isolated
`patrol_test/settings_editor_test.dart` verifies one fictional bio save, one country
read and return to the original page on the dedicated iOS simulator. See the
[report](performance/2026-10-09-settings-cleanup.md) for commands and evidence.

### Movie Lists overview/editor — 9 October 2026

`test/features/movies/movie_lists/` covers immediate personal-editor opening,
lazy/coalesced relationship reads, retries, late responses, group scope locks,
member deltas, account-switch write guards, duplicate submissions, failed-draft
retention and responsive Save controls. The badge test checks each collaborator's
own border data. Run alongside `list_creation_feedback_test.dart` and
`movie_list_models_test.dart` (18 focused cases). The shared fictional journey
has 40 lists, 12 friends and 3 available groups and is reused by
`patrol_test/movie_lists_editor_test.dart`. Full commands and results are in
[the report](performance/2026-10-09-movie-lists-cleanup.md).

### Community Discussion cleanup — 9 October 2026

Run `test/community_space_test.dart` with `test/features/social/discussion/`:
33 cases cover existing community behaviour plus deterministic loading/focus
baselines, request coalescing, forced post-write refresh, paging deduplication,
retry, disposal and stale moderation/focus responses. Existing enlarged-text
phone/landscape/tablet cases continue to pass. Dedicated native journeys remain
in `patrol_test/community_space_test.dart` (mention/parent reply, and join/reveal/
post/background-resume). See [the report](performance/2026-10-09-community-discussion-cleanup.md)
for final native results and evidence.

### Pick for Us focused checks

Run `flutter test test/pick_for_us_test.dart test/features/pick_for_us` for picker
options, responsive layouts, request budgets, retries and account/disposal guards.
The dedicated native journey is `patrol_test/pick_for_us_test.dart`, using fictional
service fixtures. Evidence and limitations: [Pick for Us cleanup](performance/2026-10-09-pick-for-us-cleanup.md).

### Add to List

Run `flutter test test/features/movies/add_to_list test/features/movies/movie_lists/relationships_test.dart`.
The isolated fixture covers 40 lists, 12 friends, lazy reads, collaborator retry,
creation/selection, saving and undo. Each case has a separate fictional account
to avoid sharing the existing list cache. Native journey:
`patrol_test/add_to_list_test.dart`, on the dedicated Patrol simulator.
Evidence: [Add to List cleanup](performance/2026-10-09-add-to-list-cleanup.md).

### Batch movie membership

Run `flutter test test/features/movies/list_membership test/features/movies/add_to_list`
for ID response contracts, failure-versus-empty semantics, the request budget, account
reset and picker workflows. `patrol_test/add_to_list_test.dart` now includes membership
failure/retry before creation, save and undo. Backend router and real PostgreSQL
benchmark commands and limitations are recorded in
[the batch membership report](performance/2026-10-09-list-membership-batch.md).

### TV lists, overview and Friend Watch Plan

Both list entry points use `add_to_list/media_list_picker.dart`. Focused checks:
`flutter test test/friend_watch_plan_flow_test.dart test/features/movies/add_to_list test/features/movies/list_membership test/features/movies/movie_lists/relationships_test.dart`.
Dedicated native cases are in `patrol_test/lists_and_friend_plan_test.dart`.
Backend tests: `src/controllers/listMembershipController.test.ts` and
`src/services/listOverview.test.ts`. The guarded PostgreSQL comparison is
`FlixieBE/scripts/benchmark-list-overview-tv-local.cjs`; the three performance
reports describe its fixed-order samples, archived mapper and fixture cleanup.

## Group Chat and Review Card cleanup

`test/features/social/group_chat/` covers stable subscriptions, duplicate loading,
account/group rebinding, retry, send failures, stream recovery, pending disposal
and reply-sheet layouts at 320×640, 844×390 and 1024×1366 with doubled text.
The isolated fixture supplies 50 messages and fictional Odyssey/Alien fans.
`test/features/movies/review/` exercises failed optimistic reactions, retry,
card/sheet synchronization and removal. Existing review safety, blocking, spoiler,
privacy and watch-request card/golden tests remain part of focused validation.

```sh
flutter test test/features/social/group_chat test/features/movies/review \
  test/review_detail_safety_test.dart test/review_blocking_test.dart \
  test/media_reviews_test.dart test/watch_request_chat_card_test.dart
scripts/test-patrol.sh -d <dedicated-device> -t patrol_test/group_chat_review_test.dart
python3 scripts/capture-group-chat-before.py
```

The baseline script temporarily adapts the archived widget's data calls to the
same fixture, preserving its original build/loading logic, and removes generated
test files in `finally`. It performs no live database or Firebase writes. Native
journeys also use isolated service/HTTP fixtures; they do not measure live
Firestore transport, authentication, backend latency or production memory.

## Notification inbox lifecycle

```sh
flutter test test/features/profile/notifications \
  test/notification_acceptance_test.dart test/notification_inbox_test.dart \
  test/notification_inbox_navigation_test.dart test/notification_visibility_test.dart \
  test/notification_profile_badges_test.dart
python3 scripts/capture-notification-inbox-before.py
scripts/test-patrol.sh -d <dedicated-device> -t patrol_test/notification_inbox_lifecycle_test.dart
```

The 100-item HTTP fixture and fictional accounts live under
`test/features/profile/notifications/`. Widget-clock tests measure covered-route
and background polling without waiting real minutes. The native target includes
the existing notification Back/Home/resume journeys plus actual app
background/foreground refresh checks and a failed-swipe/retry journey. Its source
imports those existing journeys; run this target alone to avoid duplicate work.
No real account or database writes occur. See the
[baseline report](performance/2026-10-09-notification-inbox-lifecycle.md).

Media sharing: run `flutter test test/features/sharing test/media_chat_share_payload_test.dart test/media_share_card_layout_test.dart`.
The fixture supplies 100 fictional friends/groups, empty-cache request baselines,
account-change guards, send retry, dismiss-during-send and 2× text layouts.
`patrol_test/media_sharing_test.dart` reuses the three critical journeys on the
dedicated simulator through `scripts/test-patrol.sh`; use the demo configuration
wrapper in `scripts/runtime_ios_fixture.py`. No real accounts or live messages.

### Controlled poster memory and scroll frames

`patrol_test/poster_scroll_test.dart` measures Home, the 400-title Watchlist and
Search against the isolated localhost:3007 fixture. Run
`python3 scripts/capture-poster-scroll.py --variant before --output <new-folder>`
(and `--variant after` after the intended source change). The runner is fixed to
the dedicated Patrol simulator and temporarily uses demo Firebase configuration.
It records one warmup plus five measured visits per screen, real scroll offsets,
frame timings, decoded image-cache bytes and API status accounting. Synthetic
local images control decoding dimensions and avoid CDN variability. Results are
debug-simulator diagnostics, not physical-device frame-rate or network benchmarks.
Do not edit production/harness sources during a capture; hashes must match.
See `docs/performance/2026-10-09-poster-scroll/README.md` for limits and evidence.
