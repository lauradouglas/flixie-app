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

Fast/full Flutter check:

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
