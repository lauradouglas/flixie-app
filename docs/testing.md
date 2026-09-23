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

`.github/workflows/regression.yml` runs Flutter checks and Patrol iOS on pull
requests, pushes to main and manual dispatch. Failure artifacts are uploaded.
Android's native runner is configured for local/device-farm execution; Android
device execution is not yet a CI job.
The GitHub workflow must be pushed before it can run; local validation does not
verify GitHub runner provisioning. Android device execution is not yet verified.

After pushing this workflow, make both jobs required in the repository's branch
protection/ruleset to block merging on failure. Merely adding the workflow does
not change GitHub branch protection.

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
