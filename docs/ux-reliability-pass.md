# Reliability and accessibility pass — 26 September 2026

Implemented locally following the whole-app UX review. This closes a first batch
of concrete defects; it is not a claim of whole-app accessibility certification.

## Changes

- Reviews, watch history, lists, direct-chat startup and group invitations distinguish
  request failure from a successful empty response and provide Retry.
- Reviews/history preserve searches on retry. Existing library data remains visible
  when refresh fails. History renders base titles immediately and enriches watch
  entries in batches of four; partial failure is explicit. Unknown watch counts
  say “Watched” rather than inventing a count.
- Wrapped hides internal exception text and handles repeated/immediate failures
  without returning a Future from setState or leaving an unobserved error.
- Primary navigation exposes selected/button semantics. List filters expose selection
  and have 48-point minimum height. Home actions wrap instead of shrinking text.
- Skeleton and Home startup animation respect the reduced-motion preference and
  react when it changes.
- Added missing root-navigator/safe-area options to 22 modal calls. All 103 current
  calls have both options. Growing group action/member menus have bounded scrollable
  bodies. Leaving a list from its root sheet pops the sheet context.
- Group invitation rows preserve each friend’s avatar and badge border, including
  safe initials for a missing username.
- Removed the Groups header action that only instructed users to use another button.
  The actual Groups Create action remains. Help now locates watch plans under Home.

## Verification

- 28 tests passed in the focused hardening + existing regression run. Four additional
  responsive cases were then added: all 17 hardening tests passed, giving 32 distinct
  passing widget tests overall. Existing coverage included rewatch/review sheets,
  unread badges, list creation, compact lists, chat watch plans and social activity.
- Dedicated iOS Patrol simulator: two passing journeys. Friend activity opens film
  detail and survives background/foreground. Failed history retries, opens its watch
  sheet on the root navigator with safe area enabled, closes to history and survives
  background/foreground. Fictional API fixtures only.
- Static analysis: no issues in 26 touched Dart files. Patch whitespace check clean.
- Home rendered and inspected at 320×640, 430×932, 768×1024 and 844×390 with 2× text;
  all shortcut actions remained reachable. Widget captures use app fonts; emoji
  fallback in the test renderer differs from a native device. No golden baselines
  were regenerated.

## Limits and next step

No full regression suite, native screen-reader audit, Android device run, backend
change or production deployment. The remaining findings and concepts stay in
`design/app-ux-review-2026-09-26/review.md` and `mockups.html`.

Recommended next: a bounded Home hierarchy pass, putting ongoing viewing and plans
needing a response ahead of discovery. Then audit rating units and make score sources
clear. Social wayfinding is a larger follow-on; no new navigation model is approved.
