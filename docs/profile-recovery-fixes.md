# Profile selection, history and recovery — 25 October 2026

User-authorised scope: three P1 fixes from the Profile heuristic review.

- People picker: search, department cues, Directing/Acting plus unknown filter, unrestricted All people, current selection, explicit Save, secondary Clear, retained failed-save draft and Retry. Actor/actress slots remain user-selected; no inferred gender. Department is added to existing backend library/setup selections. No migration.
- History: existing film history/actions preserved; Shows added with search/sort, independent loading/error/retry, removed-entry filtering and `/shows/:id` navigation. Shows use the existing authenticated watched-shows endpoint. Dates are labelled Added to watched rather than falsely claiming episode watch dates. Reads are scoped to the current account.
- Ratings: controller exposes failure, preserving useful ratings on refresh failure. The sheet remains mounted so search survives refresh/retry, distinguishes initial failure from empty, includes Close, and accounts for keyboard inset.
- Diary/calendar, badge icons and earned avatar borders remain unchanged.

Focused checks: 29 Flutter tests across featured_people_test, profile_recovery_test, profile_controller_test and profile_library_totals_test; three backend projection/featured-people tests; focused Flutter analysis clean. Large-text picker cases: 320×640, 844×390 and 768×1024 at 2× text with keyboard inset. Live development hot reload succeeded; Dart runtime reported no errors. Dedicated Patrol verification recorded below.

Local fixtures: guarded rerunnable `../FlixieBE/scripts/seed-dev-profile-highlights.ts`, fictional `dev_profile_casey` only. Adds watched films and a watched Alien show when the local catalogue contains one; never overwrites real users. Applied locally; no production deployment.

Further proposed work: consistent sheet action placement and labels; field-specific validation; retained drafts; account-bound saves; undo for reversible actions; distinguish no results from empty from failed data throughout Profile. These broader recommendations are not implemented by this patch.

Native verification: both Patrol journeys passed on the dedicated Flixie Profile Patrol simulator (favourite-person select/save/clear/View all; watched-show search and detail navigation). Backend TypeScript `tsc --noEmit --incremental false` passed. No production services deployed.
