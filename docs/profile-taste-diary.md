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
