# Guest browsing

Implemented locally on 10 October 2026. No deployment performed.

Guests enter directly into browsing on Home; Explore Flixie is an optional tour and have Home, Discover and You tabs. Existing member navigation remains unchanged. Search, movie/TV/person details, trailers, public watch-provider information and native media sharing remain available without an account.

Home loads trending titles, cinema releases and a bounded public community preview independently, with section-specific recovery. `/guest/home` returns six recent movie-review summaries from users who opted into community sharing, excluding deactivated users, plus genre community choices. It preserves avatar badges. It exposes no review bodies, spoilers, email, personal watch history or membership lists. Community conversations require registration; this is a directory preview, not a public discussion feed.

## Account entry points

- Home Sign in, welcome Create account/Sign in, and You.
- Favourites, watched/logging, ratings and reviews. Watchlist picks can be saved locally without an account or a two-title cap.
- Lists, watch plans, streaming preferences and collection progress.
- Community conversations and other protected destinations.

Action prompts can be dismissed to keep exploring. Selecting authentication retains the destination and supported action through the existing terms/onboarding flow. After authentication, watchlist/favourite intents save only if needed; editor intents reopen their editor without automatically submitting a rating or review. TV episode/season actions return to the title without automatically marking it watched. Pending intent is session-only and does not survive process death. Choosing Keep exploring from authentication clears it.

## Ownership and rollout

`GuestAccess` owns public-route classification, contextual prompts and the single pending intent. Guest Home owns its public load; existing authenticated controllers keep their account data. Guest detail loads skip account-only review endpoints. Private routes and writes retain their existing backend authentication.

Deploy the backend containing `/guest/home` before releasing this client: guest Home expects that endpoint. No schema migration or anonymous account creation is required. Existing authenticated API contracts were not replaced.

## Validation

### Visual evidence and incumbent design

Guest Home, welcome/You and the account prompt reuse the existing theme text styles, button themes, `context.colors.background` and `FlixieWordmark`; the wordmark retains white **flix** and `FlixieColors.primary` purple **ie** on dark surfaces. Community rows use `ProfileAvatarView` with each user's `profileBadges`. This is an extension of the native app's incumbent design, not a new visual system.

The welcome/You body is scrollable and constrained to 460 logical pixels; its decorative wordmark scales down to fit. Home community choices wrap, and the movie rail measures title height with the current text scaler. The account sheet uses the root navigator, safe-area handling, an 80%-of-viewport maximum height and a scrollable body.

Fixture captures in `/tmp/guest-review/` cover Home, You and the account sheet at phone, tablet and small-phone/large-text sizes. These temporary render artifacts support composition and overflow review; they do not verify native safe areas, production font metrics, gestures or performance. The responsive review's wordmark-wrap finding was resolved. No project-wide design-system files or new visual rules were introduced.

### Functional checks

- Ten guest action/router/responsive widget tests pass, including 320px width at 2x text, phone and tablet layouts.
- Focused existing movie/TV action, detail-loading, person and setup-destination tests pass (17-test and 32-test runs overlap; do not sum them as unique coverage).
- Dedicated Flixie Patrol simulator guest journey passes: Home → Alien → local watchlist confirmation → dismiss → You, with no writes or protected review requests.
- Backend guest projection and authentication tests pass (six tests); TypeScript typecheck passed.
- Anonymous local database smoke test returns six summaries and 20 community choices from the isolated runtime fixture database. Existing guarded runtime fixture seeding provides fictional accounts with both sharing preferences.
- Responsive render review caught a wordmark wrap at large text; the decorative wordmark now scales to fit while body text remains scaled.

Native journey uses an isolated mocked API; populated PostgreSQL validation is a separate HTTP smoke check. Actual signup through external identity providers, process-death recovery and production conversion/performance are not verified by these checks. No full regression suite or production benchmarks were run for this feature.

## 25 October 2026 update

Discovery now leads, with a compact Pip introduction, films/shows search and full-artwork posters. A clearly labelled example of the original paper diary/calendar appears below browsing. Member diary and badge icons are unchanged. The first guest save explains device-local storage; subsequent saves use brief feedback. The collection shows saved posters before an optional account invitation. Tour signup initializes the shared signup journey, and leaving the tour clears stale intent. Progressive signup-method disclosure from the concept board remains a separate proposal.

Review requests require a signed-in user with completed setup, seven days since the first recorded meaningful action, three active days and five distinct completed actions. Successful title saves, film logging and completed watch plans contribute; repeat toggles do not inflate the total. A new action must occur in the current session, followed by eight idle seconds on Home without another route/sheet. A device-wide 120-day cooldown applies. These thresholds are product choices, not OS requirements; the OS can suppress the actual prompt. No rating sentiment gate is used.

Regression coverage: guest widget/router/responsive tests, film/show collecting, isolated review eligibility/service/idle-gate tests, and TV action tests. Native fixtures use fictional mocked catalogue responses and local artwork on the dedicated Patrol simulator; they do not use production accounts or verify live OAuth. Screenshot output: `output/guest-discovery-implementation/phone/`.

Final validation: 68 focused tests passed; both dedicated native guest journeys passed. All 28 changed Dart files pass targeted analysis. Whole-project analysis still reports 58 existing issues in archived performance harnesses and untouched tooling/tests. Development app hot-restarted with no reported runtime errors. Native captures include Patrol/debug overlays; these are test-harness chrome, not release UI.

## Full homepage approval — 25 October 2026

User approved the full homepage and specified films-only Trending overall. Guest and signed-in Home now use `/trending/movie/day`; film/show/person search stays available. Header Sign up and Sign in remain visible, with a stacked header on narrow/large-text layouts. Guest signup with local picks preserves the existing guest-watchlist intent. Discovery and personal-value content use columns only with sufficient width/text space. Cinema remains the working catalogue, not a new unimplemented route. Diary/calendar, contained artwork, independent retries, public activity and games remain. Badge information uses the existing safe bottom-sheet primitive. Rating drafts before signup remain a separate proposal.

Validation for the approved full homepage: 51 guest tests passed; focused film-only/header/service tests passed, including exclusion of a TV item from a mixed fixture. Responsive/tour checks passed at small-phone, phone, landscape and tablet sizes with increased text scaling. Both dedicated native guest journeys passed after updating games navigation to its lower-page location. Changed files pass targeted analysis; development app restarted successfully. One existing signed-in Home subscriptions test still fails because it expects no friend-activity requests; this was reproduced with the original mixed Trending endpoint and left intact. No full regression suite or deployment was run.

## Guest film diary drafts — 25 October 2026

Film Rate and Log actions now open a device-local draft before requesting an account.
Rating-only drafts do not mark a film watched. Log drafts allow an optional score,
watch date, recommendation and note; an omitted date remains unknown. Edits persist
as they are entered. Preview offers optional signup/sign-in; leaving retains the
entry. Home links to device drafts, and the account diary has a device-drafts action.
Discarding an unsubmitted draft requires a bottom-sheet confirmation.

An explicit signup handoff persists the draft ID across restarts. After the existing
identity/terms requirements, the router binds the selected draft to that account and
opens a prefilled editor. Saving requires a further explicit action. Existing release
confirmation applies before account logging. Submitted log payloads are locked during
uncertain retries and reuse the draft UUID; the existing server idempotency prevents
duplicate watches. Local removal happens only after the remote operation succeeds.
Other drafts are preserved, not silently published. No backend changes or deployment.

Verification uses fictional accounts and Alien (348), with no production writes:
store restoration/account isolation, rapid edits, unknown/invalid dates, leaving the
editor, guest entry/preview/signup handoff, exact field preservation, explicit save,
failed-save retry, and 320/390/834px increased-text layouts. Native Patrol covers
signup continuation and retry on the dedicated Flixie Profile Patrol simulator.
External OAuth/provider UI and a production TestFlight build are not part of this check.

Validation result: 44 focused guest/signup tests passed, plus two dedicated iOS
Patrol journeys (guest entry/preview/signup and post-signup failed-save retry).
Native report: `build/ios_results_1792955947184.xcresult`. A further account-switch
regression checks that signing out immediately hides bound notes while preserving
them for the owning account. Development hot restart/reload succeeded. No TestFlight
upload was performed for this feature.


## External watch invitations — 25 October 2026

Recipients can draft an independent score, date and note before signup. The device draft is bound to the signing-in account and restored on the invite route; an explicit save claims the invite then confirms the entry. A stored request ID makes confirmation retries reuse the same claim. Unsubmitted drafts can be kept as separate diary entries when the invite is unavailable. Optional connection/referral consent uses existing attribution without replacing it. Sender notes and scores are not exposed by public previews.

Referral progress and poster/referral metadata require the matching additive backend changes. No production or TestFlight deployment was performed. Existing badge qualification remains setup completion, not first watch.

Validation: 26 focused Flutter tests; 11 focused backend tests; backend typecheck; targeted Flutter analysis; small-phone 200%, phone and tablet 150% render checks; native Patrol external guest/signup/failed-save retry journey. Local fictional fixtures are provided by `../FlixieBE/scripts/seed-dev-referral-watch.ts` (guarded local database only, rerunnable preserving edits). The fixture account `dev_referral_casey` has two joins, one qualified, plus active and expired Alien invitations.
