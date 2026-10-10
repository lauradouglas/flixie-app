# Guest browsing

Implemented locally on 10 October 2026. No deployment performed.

Guests enter through Explore Flixie and have Home, Discover and You tabs. Existing member navigation remains unchanged. Search, movie/TV/person details, trailers, public watch-provider information and native media sharing remain available without an account.

Home loads popular movies and a bounded public community preview together. `/guest/home` returns six recent movie-review summaries from users who opted into community sharing, excluding deactivated users, plus genre community choices. It preserves avatar badges. It exposes no review bodies, spoilers, email, personal watch history or membership lists. Community conversations require registration; this is a directory preview, not a public discussion feed.

## Account entry points

- Home Sign in, welcome Create account/Sign in, and You.
- Watchlist, favourites, watched/logging, ratings and reviews.
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
- Dedicated Flixie Patrol simulator guest journey passes: Home → Alien → Watchlist prompt → dismiss → You, with no writes or protected review requests.
- Backend guest projection and authentication tests pass (six tests); TypeScript typecheck passed.
- Anonymous local database smoke test returns six summaries and 20 community choices from the isolated runtime fixture database. Existing guarded runtime fixture seeding provides fictional accounts with both sharing preferences.
- Responsive render review caught a wordmark wrap at large text; the decorative wordmark now scales to fit while body text remains scaled.

Native journey uses an isolated mocked API; populated PostgreSQL validation is a separate HTTP smoke check. Actual signup through external identity providers, process-death recovery and production conversion/performance are not verified by these checks. No full regression suite or production benchmarks were run for this feature.
