# Signup regression suite

The suite separates real local registration from deterministic service contracts.
A passing test is evidence for its stated environment, not a guarantee that an
external provider, production configuration or future release cannot fail.

## Run locally

Start the guarded local backend and Firebase emulator stack described in
[local development](firebase-local-development.md). Use a dedicated iOS simulator
whose name contains `Patrol`; the runner reinstalls the app. Never use a personal
installation. Backend configuration must target the development database.

```sh
scripts/test-signup-patrol-local.sh 3A372E2A-A991-4C81-BD29-E007555B5A01
```

`SIGNUP_API_PORT` optionally selects another loopback backend port. Arbitrary API
hosts and production Firebase are not accepted. Fictional accounts use unique
`sj…`/`soc…` usernames and `example.invalid` emails; real accounts are never used.
The runner first executes focused Flutter signup/social-auth/continuation tests,
then `signup_suite_local_test.dart` through the existing Patrol runner. No new
test harness or Flutter Driver migration is required.

## Native coverage

| Journey / failure | Local native test checks |
| --- | --- |
| Film and TV watchlist | Actual guest action → contextual prompt → real email/password signup → initials avatar → original title persisted before setup → provider step may be skipped |
| Film and TV rating | Actual guest Rate action → signup → explicit score → backend rating read → optional heart favourites |
| Film and TV review | Actual review action → signup → existing editor → exactly one saved review |
| Film review diary follow-up | Review remains single; optional watch/date/companion creates a separate viewing and copyable invitation |
| Film log | Existing editor, no-friends companion path, persisted viewing/invite, lost response after commit and idempotent retry |
| Episode | Actual guest Mark watched action retains and saves exactly the selected released episode |
| Home / Profile | Actual signup entry opens purpose selection / optional favourites and can finish without unrelated setup |
| Providers | Existing country/provider selector saves a real selected service and independently re-reads it |
| Passwords | Weak/mismatched input is rejected before account creation, then corrected signup succeeds |
| Profile API failure | Retrying profile creation keeps the same Firebase identity |
| Bookmark API failure | No false saved state; retry saves original title once |
| Setup completion failure | Original save remains; completion is retriable |
| Review API failure | Draft remains; retry produces one review |
| Cancellation | Leaving signup/dismissing prompt preserves usable guest browsing and creates no profile |
| Referral code / username | Optional expanded input resolves before signup; canonical referral code reaches profile creation |
| Apple / Google credential callback | Replaces external picker with an emulator OAuth credential; native Firebase SDK, profile form, optional avatar, local API and original save remain real |
| Apple / Google cancel / network failure | Original intent remains; email signup can recover without losing the selected title |

`support/signup_local_journey.dart` mounts production `FlixieApp`, router,
`AuthProvider`, `AuthService`, forms and action pages. Analytics is a real
initialized controller with a local no-op backend and declined consent. HTTP
passes through to the local API except for explicitly selected one-shot faults.
The lost-watch-response test commits the real request before hiding its response.
Successful outcomes are verified by re-reading the server, rather than by only
checking a toast or an optimistic local collection.

## Supporting coverage and limits

Focused tests cover account/session switches, exact destination ownership,
privacy/terms, provider SDK error mapping, incomplete-profile recovery,
responsive poster results, same-ID movie/TV deduplication, and existing-editor
handoffs. Existing native feature suites additionally exercise lists, favourites,
season progress, communities, watch plans and game score continuation with
isolated fixtures. Those are not equivalent to a full real email-registration
run for every handoff variant.

Provider presentation also has explicit component coverage in
`test/features/authentication/onboarding_services_details_test.dart`: the signup
route reuses `OnboardingServicesStep` and the existing country sheet; provider
names, correctly wired/decoded network images, 36px logo sizing, missing-logo
fallback, selected checkboxes, search and no-results text are checked at narrow
phone/tablet sizes with 2x text scaling. Image decoding uses fixture PNG bytes;
this does not establish remote CDN availability or every real logo's artwork.
These three tests passed alongside all 16 existing signup-journey tests (19/19).
They are included in the local signup runner's focused checks. This is specific
content/layout coverage, not an exhaustive visual audit of every journey state.

The Apple/Google emulator tests intentionally bypass the external provider picker.
They cannot verify live provider consent, Apple entitlements, Google client IDs,
redirect URLs, revocation, real MFA or release signing. A release smoke check on
physical iOS/Android devices is still needed for those integrations. The guarded
runner currently supports iOS simulators; Android execution is not implied.

## Evidence

24 October 2026: the complete suite passed **23/23 with zero failures or skips**
on dedicated Flixie Review Patrol, using local Firebase Auth and the local API.
Report: `build/ios_results_1792856048725.xcresult` (11m 6s). The same runner passed
all 53 focused supporting tests. This is local iOS evidence; the provider and
platform limits above still apply.

### Live-provider check started — 24 October 2026

User requested real Apple/Google signup verification. Launched normal `lib/main.dart`
on dedicated Flixie Review Patrol with `USE_FIREBASE_EMULATORS=false` and
`USE_PROD_API=true`. Guest Home loads against the live API. Source inspection
confirms the iOS Apple sign-in entitlement and a matching Google reversed-client
URL scheme; neither establishes successful live OAuth.

Live completion remains **pending**. Simulator automation could observe the app
but could not reliably activate Flutter controls. A temporary manual driver
experiment was removed, including its SDK dependency; the normal app is left at
guest Home for manual authentication. No live Apple/Google credential callback,
new account, first-action save or relaunch persistence has been verified in this
pass. Do not count the launch or configuration checks as a provider test pass.
The next step is user-assisted authentication with fresh test provider accounts,
then profile/avatar completion, the original action and relaunch verification.
The user subsequently confirmed successful live Google sign-in with their
existing account. This is user-reported sign-in evidence, not a fresh Google
signup test; live Apple signup remains unverified.

### Opt-in live email/watchlist checks

`patrol_test/bookmark_signup_live_test.dart` is separate from the local aggregate.
It skips unless `ALLOW_LIVE_SIGNUP_TEST=true`, rejects emulated Firebase and any
API other than the expected live HTTPS backend, and verifies the Firebase project.
Use only the dedicated Patrol simulator with the existing runner:

```sh
scripts/test-patrol.sh -d 3A372E2A-A991-4C81-BD29-E007555B5A01 \
  --target patrol_test/bookmark_signup_live_test.dart \
  --dart-define=ALLOW_LIVE_SIGNUP_TEST=true \
  --dart-define=USE_FIREBASE_EMULATORS=false \
  --dart-define=USE_PROD_API=true
```

This deliberately creates two fictional live accounts, one each for Alien and
Breaking Bad. Passwords are generated securely at runtime and never recorded.
The normal guest bookmark, email/password signup and avatar UI are exercised;
server reads verify the original title is saved before optional setup and after
signing out/back in. User-authorised cleanup targets only the exact newly created
email/username, uses normal account deletion, checks username removal and verifies
that Firebase rejects the deleted credentials. Teardown also attempts cleanup if
a journey fails. No existing accounts or credentials are used.

24 October 2026: **2/2 passed, zero failures/skips**, against live Firebase
`flixie-9a8eb` and the production HTTPS API. Evidence:
`build/ios_results_1792865751535.xcresult` (2m 8s native execution).
Both titles were independently read from the backend before optional setup and
again after signing out/back in. Both newly created accounts were deleted through
normal account deletion; the test verified username removal and Firebase
rejection of the deleted credentials. No test accounts from this run remain.
This verifies email/password registration and watchlist persistence, not email
delivery, inbox verification or first-time Apple/Google signup.

Patrol writes `build/ios_results_*.xcresult`. Record the exact report and passed /
failed counts in [testing](testing.md) after executing a run. Do not count a build,
started run, fixture-only test or intercepted failure as an end-to-end pass.


### Native signup visual review — 24 October 2026

`patrol_test/signup_screens_review_test.dart` captures actual production widgets
on dedicated iOS simulators with isolated fixture state and locally cached real
posters, avatar artwork and streaming-service logos. No accounts or activity are
created. It skips unless explicitly supplied a screenshot host. The capture server
is `tool/signup_review/capture_server.py`; use Patrol `--no-label` for clean images.

The clean iPhone run passed 1/1 native tests (zero failures/skips), producing 124
screenshots: `build/ios_results_1792867609173.xcresult`. Ten routes cover film/TV
watchlist, film/TV rating, film/TV review, watch logging, episode watched, Home and
Profile. Each includes account/referral/avatar screens and relevant editors,
optional follow-ups, poster search, providers/country/selection and companion
invitation controls. Overlapping scroll captures expose content below the fold.
Gallery: `output/signup-screen-review/index.html`; detailed findings in
`output/signup-screen-review/review.html`. These are visual fixture captures,
not an additional live authentication test or exhaustive accessibility proof.
Focused analysis of the capture target passed.


### Approved action-first refinement

The user approved all visual-audit findings on 24 October. Registration now
completes with the existing initials avatar and continues directly to the
selected action. Avatar artwork uses the existing optional ChangeAvatarSheet
after the useful action. Historical results above describe the earlier
mandatory-avatar sequence; they are retained as dated evidence. The live-email
test target has been adapted but has not been rerun against production for this
refinement. New local-native results and revised screenshots are recorded below.

Additional regressions cover Home → film selection → real log editor → save,
leaving an unfinished rating without saving, selected episode labels, no-friends
name entry, default-avatar completion without an avatar API call, and all three
editors at small-phone, landscape and tablet sizes with 1.8x text.


The pre-refinement visual audit also completed on iPad (92 captures), with
`build/signup_review_tablet.xcresult` reporting a successful native capture test.
The original 216 phone/iPad images are preserved under
`output/signup-screen-review/before/`.

The first refinement native run (`build/ios_results_1792868860654.xcresult`)
was superseded after two automation issues: a review retry tapped behind its
error toast, and a generic Continue finder could match the previous signup
form during transition. The test now uses the visible Retry action and scopes
Continue to SignupJourneyPage. That interrupted run is not counted as a pass.
The corrected full signup suite and screenshots share
`patrol_test/signup_review_and_regression_test.dart`.

The revised iPhone capture test completed successfully with 128 screenshots
across 11 routes, including Home → film selection → log editor. New avatar
selection captures show the existing optional picker after the first action.
Additional companion/guest checks passed (16 companion/invite tests and five
guest/router tests), including preserving an existing companion if a friend
lookup returns no rows. The final native suite result is recorded after the
combined run completes.


24 October 2026 refinement verification: **24/24 native tests passed, zero
failures/skips** in `build/ios_results_1792869609313.xcresult`. This is the full
23-case local signup suite plus the revised iPhone screen-capture test (128
screens across 11 routes). Registration uses initials; explicit avatar artwork
is optional after the first action. Movie/TV saves, scores, reviews, exact episode
progress, provider persistence, referrals, cancellation, profile-create retry,
review Retry and idempotent watch retry passed. Apple/Google callback credentials
are emulated; native Firebase SDK and local API persistence remain real.

Focused Flutter verification passed 69/69. Subsequent targeted companion/invite
checks passed 16/16, guest/router checks 5/5, and final journey/referral layout
checks 28/28 (these sets overlap; do not sum them as independent coverage).
The companion empty-state regression also preserves an existing selected friend
when the friend response is empty. Home → film picker → log ID/save is covered
by a widget regression and native visual interaction; native API persistence is
covered through the shared film-log journey. External provider consent UI and
fresh live provider/production email registration were not rerun for this change.

Final native iPad confirmation passed 1/1, completing all 11 iPad routes and
refreshing the centred editor contexts/provider country selection after the fixes.
The gallery contains 225 unique native screenshots: 128 phone + 97 tablet.
Every manifest image exists and every route has captures on both devices.
No further UI changes followed the final visual confirmation.

Final iPad confirmation report: `build/ios_results_1792872346251.xcresult`,
1/1 passed, zero failures/skips (95s capture body). This focused confirmation
covered the corrected film/TV rating/review contexts and the TV watchlist
country/provider selection that had failed in the initial iPad scan.


## Guest watchlist before signup (24 October 2026)

Guest film/TV bookmarks now persist locally rather than opening the immediate
account gate. Home links to `/guest-watchlist`; collection CTA opts into account
merge for either signup or sign-in. Signup preserves Apple/Google/email/password
options. Device picks are removed only after acknowledged account saves and local
write success. Account changes stop the merge. Member Watchlist exposes retained
picks for explicit recovery after restart/postponement. Signup previews at most
three picks plus the remaining count to avoid a long pre-form collection.

Focused coverage: `guest_watchlist_store_test.dart` (including rejected disk
writes, partial save retry, serialization, account changes, repeated removal),
`guest_watchlist_page_test.dart` (320/844/1024 widths with increased text and
member recovery), `guest_access_test.dart`, `bookmark_signup_context_test.dart`,
`bookmark_signup_test.dart`, `signup_journey_test.dart`, existing film/TV action
regressions and guest layout checks. Preferences use isolated platform fixtures.

Native `patrol_test/guest_watchlist_local_test.dart` passed **1/1**, no skips,
on dedicated Flixie Review Patrol, using local backend + Firebase Auth emulator:
Alien and Interstellar are picked as a guest, signup is cancelled/reopened,
and backend membership is asserted exactly once each before optional setup.
Report: `build/ios_results_1792873868873.xcresult`.
Earlier attempts `1792873335458` and `1792873627461` failed while navigating
quickly between title pages; the final test returns through guest Home and waits
for the target title, and the collection now listens for completed local writes.
They are retained as failures, not counted as passing runs.

The existing local/live email and emulator-provider test entrypoints have been
updated for the new guest collection CTA. The live-provider/live-email tests
were not rerun for this change. Previous 225-image signup gallery predates this
feature; it is not a visual verification of the guest collection.


Guest journey native screenshot update: `guest-watchlist.html` now shows the
current actual iPhone screens, including guest picks, all signup scroll positions,
saved-pick suggestions, optional providers, country picker, loaded provider logos
and the resulting two-title account watchlist. Transient snackbars are dismissed
before capture. Clean capture run passed 1/1, zero failures/skips:
`build/ios_results_1792874422766.xcresult`. Screenshot fixtures use isolated local
accounts/backend and Auth emulator; these are native screenshots, not HTML mockups.


## Native optional Build your taste (24 October 2026)

Implemented route `/build-your-taste`, Home invitation after acknowledged activity
or existing library evidence, and permanent Profile entry. Per-account device
progress/dismissal, six-film starter selection, full film search, real favourite
save/removal and the existing rating editor. Both steps skip without a minimum;
no automatic favourite/rating writes. Existing ratings load before editing,
ten-favourite cap and profile visibility wording are preserved. Saves invalidate
recommendation cache and notify the existing Home refresh path. No TV-personalisation
promise, fake recommendation results, backend migration or deployment.

Focused regression set passed **66/66** (taste controller/page, signup journeys,
film/TV action flows, guest watchlist persistence and signup routing). After the
native-discovered scroll/focus fix, all **14 taste checks** passed again, including
320px phone, landscape and tablet layouts with increased text. Targeted analysis
is clean. A deterministic slow-progress regression reproduced and fixed a race
where default results could replace a new search after changing steps.

Final device run **1/1 passed**, no failures/skips, on dedicated Flixie Review
Patrol against local backend and Firebase Auth emulator:
`build/ios_results_1792877276349.xcresult`.
The test checks original Alien watchlist persistence before setup, Home invitation
and dismissal, Profile entry, saved Alien favourite membership, Interstellar
8/10 + recommend=true persisted through the real API, return to discovery,
persisted Profile resume and skipping both steps. Source:
`patrol_test/build_taste_local_test.dart`. Patrol's supported text-entry helper
and explicit visible-field scrolling handle reuse of the same iOS search field.

Earlier failing device reports are retained: `1792875675340`, `1792876063790`,
`1792876424914`, `1792876716785`, `1792877014089`. They are not counted as passes.
Failures exposed step/query ordering and scroll/focus issues and the raw tester's
repeated-field input problem. Final confirmation used unchanged app/test sources.

Native screenshots: `output/signup-screen-review/build-your-taste-native.html`;
all four screens were refreshed by the final passing run. The earlier
`build-your-taste.html` remains the interactive HTML mockup. Live provider signup
and a native iPad run were not part of this feature validation.
