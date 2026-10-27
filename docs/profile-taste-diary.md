# Profile taste and diary

The own-profile screen puts Taste and Diary beside Activity and Stats. Taste
contains favourite films/shows, three optional favourite-person highlights, a
small page of the same film diary, and library/account actions. The full Diary
reuses `ProfileDiaryScreen` in embedded mode, including week swipes, calendar,
watch dots, notes, cinema/rewatch markers, companions and undated watches. The
standalone diary route remains available. Badge pills retain their existing icons
and avatars retain the user's own earned border.

## Favourite people contract

`PUT /users/:userId` with `{"featuredPeople":{"director":525,"actor":500,"actress":10205}}`
replaces the highlight map. Roles are optional; omit a role or send null to clear.
Unknown keys and invalid IDs are rejected. Selected IDs must already belong to
the authenticated user's favourite people. Existing user ownership middleware
protects the endpoint. Users choose the labels themselves; missing role/gender
metadata never creates an inferred selection. Removed favourites no longer render
as highlights, even if their ID remains in the stored map.

The additive migration is `20261025150000_profile_featured_people` in FlixieBE.
Apply that migration before deploying backend code that reads the field. Old
clients can ignore it; new clients accept missing fields as empty highlights.
The localhost development database has the migration recorded as applied.

## Local fixture

From FlixieBE, with the existing local database environment:

```sh
NODE_ENV=development node --env-file=.env.local -r ts-node/register scripts/seed-dev-profile-highlights.ts
```

This refuses remote databases and identity collisions. It creates only fictional
`dev_profile_casey`, favourites and diary entries; reruns preserve choices and
existing fixture entries. It uses local catalogue entries for Alien, Spider-Man
and The Odyssey, and four favourite people so View all has more than three.
It does not create a Firebase login. The isolated widget/Patrol fixtures exercise
the flows without needing a real account.

## Focused checks

```sh
flutter test test/features/profile/featured_people_test.dart test/features/profile/profile_screen_test.dart test/features/profile/diary/diary_test.dart test/profile_library_totals_test.dart test/profile_favourites_library_test.dart test/features/profile/tablet_profile_test.dart test/profile_lazy_stats_test.dart
flutter analyze lib/features/profile lib/models/user.dart
scripts/test-patrol.sh -d <dedicated-simulator> --target patrol_test/profile_screen_test.dart,patrol_test/profile_gallery_test.dart,patrol_test/profile_library_totals_test.dart,patrol_test/profile_featured_people_test.dart
```

Backend: `npm test -- src/services/featuredPeople.test.ts src/services/usersService.startup.test.ts`
and `npm run typecheck`. Visual fixture renderer: `flutter test tool/profile_review/render_test.dart`.
The renderer writes phone/tablet screenshots to `output/profile-review/` without
changing golden baselines. Its people and poster fallbacks are isolated test data.

## Verified 25 October 2026

36 focused Flutter checks (including the render fixture), 7 backend regression
checks, backend TypeScript checking and focused Flutter analysis passed. Four
native Patrol journeys passed on dedicated `Flixie Profile Patrol`: choosing/
clearing/viewing favourite people, large-text gallery access, combined library
totals and navigation, and profile tabs/lazy Stats. Report:
`build/ios_results_1792935295492.xcresult`. The first native attempt could not find
the previous simulator; a fresh dedicated device completed all four journeys.
Final compact-header/show-entry refinements were also checked in the Flutter
layout suite and phone/tablet renders. Local highlight save/startup reload was
verified through the real backend service using only the fictional fixture.

A user-reported 401 during a separate simulator build was investigated with
`scripts/verify-firebase-local.cjs`: fresh local sign-in, backend, Firestore access
rules and avatar Storage all passed. The saved simulator session still needs
sign-out/sign-in; no authentication bypass or production configuration was added.

## Diary refinements — 26 October 2026

The diary retains its lavender paper, serif heading, Pip, week paging, and
month/year calendar. Day buttons filter actual watches with a whole-week reset,
and the calendar previews the selected day, including multiple watches. Very
narrow screens reflow the day controls to preserve touch targets.

Log a film opens a film-only debounced search with stale-response guards and
loading/error/retry states, then the existing watch editor. The add icon and
label share a compact horizontal button. Entry menus open that editor directly,
also for undated watches. Diary edits support the existing watched-with picker,
retaining linked companions and individual badge borders. Friends receive their
existing prompt to log their own watch; external companions retain the existing
invite flow. Existing server ownership and shared-watch rules still apply.

`DiaryEntryService` owns API access; diary presentation owns search and sheet
coordination. Writes reuse one draft ID through retries, retain failed edits,
guard account changes, and refresh diary data after save. New logs update the
local watched-film collection only after a successful write. Diary notes remain
separate from public/spoiler review text. Logging, sharing controls and the
viewing recap use Diary note terminology.

Checks:

```sh
flutter test test/features/profile/diary/diary_test.dart test/features/profile/diary/diary_editing_test.dart test/rewatch_log_sheet_test.dart test/features/movies/watch_log_keyboard_test.dart test/features/movies/watch_companion_log_test.dart
flutter test tool/diary_mockups/implemented_diary_render_test.dart
scripts/test-patrol.sh -d B49E1266-AB60-400F-B213-8AB3365CA331 --target patrol_test/diary_memory_test.dart
```

The dedicated simulator journey passed (companion addition plus retained note
and retry), report `build/ios_results_1793019040689.xcresult`. Responsive fixture
captures are in `output/diary-update/` and do not replace golden baselines.
The separate `watch_review_continuation_test.dart` run produced three failures
from its strict unexpected-request assertion for `GET /movies/id/348`. The
watch-editor change in that flow is label/hint text only; the assertion remains
intact and the failure is reported. Existing guarded fictional Casey fixtures
from `seed-dev-profile-highlights.ts` support manual diary testing.
