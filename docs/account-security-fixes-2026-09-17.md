# Account access and invitation fixes — 17 September 2026

## Changes

- Username profile lookup selects public profile fields only, preserving avatar badges without exposing email, Firebase identity or push token.
- Username sign-in uses the new `/auth/username-session` endpoint. It verifies the password with Firebase and verifies the returned token's project and account before resolving the email. Responses are not cached, passwords are not logged, and attempts are limited. Email sign-in remains unchanged.
- Notification reads, updates and deletion require the owning account. Client updates can only change read/closed state; clients cannot create notifications, forge request actions or mutate notification links.
- Person favourite mutations require authentication, current terms and the matching account.
- Group creation/invitation persists membership, request and notification together in a serializable transaction, after block checks. Both invitation response paths require a matching pending request and membership. Acceptance checks blocking again. Blocking closes pending group invitations and their membership/notification state.

## Verification

- TypeScript compilation passed.
- Backend suite: 329 tests passed across the initial run and a successful rerun of two tests that required permission to open a local server.
- Focused security suite: 21 tests passed, including ownership, private field projection, failed invitation persistence and blocked/stale acceptance.
- Flutter authentication, registration, recovery and prefetch tests: 34 passed.
- Flutter analysis of the changed authentication provider passed.

## Release checks

Deploy the backend before releasing the app that uses the new username sign-in endpoint. These changes have not been deployed.

The new username password-verification flow has unit coverage but has not been exercised against live Firebase. Check username and email sign-in on a release-like build, including a wrong password. Repeat group invite/accept/block checks on the rebuilt app. The earlier two-simulator safety pass predates this change set.

Apple's requested recording must still be captured on a physical device. These fixes do not guarantee App Review acceptance.

## Follow-up: public profiles, maintenance and analytics copy

- The user directory now selects public profile fields explicitly. Friend creation, updates and listing also select public profiles. Pending request profiles use the same selection, and the friend response mapper strips any unexpected private fields. Avatars and profile badges are preserved.
- Bulk people/movie/show imports, updates and refreshes, including the legacy show-media GET operation, require authentication plus a verified Firebase custom claim `admin: true`. The general maintenance router has the same restriction. Request bodies and headers cannot grant administrator status. Normal browsing and favourite operations retain their existing access rules.
- The consent prompt and Settings now say “Share usage analytics”. The prompt explains that the app-instance identifier associates events from an installation without describing the data as anonymous.

Verification: all 334 backend tests and 19 Flutter analytics tests passed; TypeScript compilation and whitespace checks passed. New tests cover the public directory selection, accepted and pending friend payloads, badge preservation, strict verified admin claims, and installation of the guard on each bulk route.

Operational change: authorized maintenance operators need the Firebase custom claim `admin: true`, assigned through a trusted server-side administrative process, followed by a refreshed sign-in token. Without that claim, maintenance requests return 403. No account has been granted this claim by this task, and no production deployment was performed. Do not place administrator credentials or claim-setting functionality in the app.

## Follow-up: review blocking, rating writes and utility maintenance

- Review cards wait for a successful block-list lookup before displaying content. Failure shows a retry action without revealing the review. Cards respond to block/unblock/session changes, discard superseded lookups and remove their listener when disposed. Safety cache invalidation now happens before notifying listeners.
- Both movie and TV rating write routes require authentication, current terms, a database account matching the submitted user ID, and a finite numeric rating from 1 to 10.
- All eight utility mutation routes now require authenticated administrator access, including legacy GET imports: countries, languages, time zones, watch providers, colour creation/update/deletion and provider display-priority sync. Public read-only utility lookups remain available for registration and browsing.

Verification: all 336 backend tests and 10 focused Flutter review/safety tests passed. TypeScript compilation, Flutter analysis of the changed code and whitespace checks passed. Tests cover pending/failed block-list loading, retry, live block/unblock changes, forged/anonymous ratings, invalid ratings, and route guard ordering. Changes remain local; this pass did not repeat the physical-device or simulator end-to-end tests.

## Name visibility and website wording

Directory, username and shared friend/request profile responses now omit both first and last names. Detailed profiles retain the existing viewer-aware rules: first names for the owner or friends, surnames for the owner only. Public usernames, avatars and badge borders remain available. Twelve focused backend tests and TypeScript compilation passed after this change.

The separate `flixie-corp/flixie/src/components/PrivacyView.tsx` website source now uses “Share usage analytics”, explains installation-level event association without calling the identifier anonymous, and shows 17 September 2026 as its update date. Website type checking and production prerendering passed; the generated privacy page was checked for the new wording. Neither the website nor backend has been deployed by this task.

## Expanded review reporting

The shared expanded review sheet now includes visible Report review and Block user actions for signed-in viewers of someone else's review. Reports include the review type, review ID, author and preview. Successful blocking closes the sheet; cancellation leaves it open. Actions wrap on narrow screens and are disabled while an action is running. Owners retain their existing deletion control.

All 14 focused review/safety widget tests passed, covering movie and TV report payloads, block cancellation/completion, owner and signed-out visibility, and narrow screens with increased text size. Flutter analysis passed. This app change is local and still needs to be included in the release build.
