# Flixie performance review — 1 October 2026

Review baseline: app `1b6fe1c`, backend `2f39cf7`, plus the working tree at review time. This reviews current source, not the exact binary downloaded from Apple. No runtime code, production configuration or database was changed for this review.

The largest opportunities are avoiding unnecessary waits and reducing request fan-out. A wholesale Flutter rewrite is not justified by this evidence. Movie detail already demonstrates a useful approach: render core content and let optional sections finish independently. Shows, people and Plans do not consistently follow it.

## Evidence and limits

- Inspected startup/auth, shared HTTP transport, Home, movie/show/person detail, Discover search, profile, lists, watchlists, community entry, chat subscriptions and Plans. Inspected associated backend show/movie/list service and repository paths.
- Ran five focused loading/cache test files: **13 passed, 1 failed**. The Home recovery test fails at `test/home_startup_recovery_test.dart:54`, expecting the absent `Pick for me` text. That prevents its later assertions from being validated. Assertions were not weakened or skipped.
- Device discovery found a physical iPhone and two simulators. No profile build was installed on the user's phone, and no device frame trace was captured. Simulator/debug timings would not establish App Store performance.
- No production latency sampling, SQL execution plans, database pool metrics, memory traces, image decode traces or Apple launch metrics were obtained. Accordingly, priority below is based on confirmed dependency structure and growth characteristics, not measured milliseconds saved.
- Existing startup traces cover token, profile, resume and Home milestones. They are not a complete per-screen performance baseline.

## Priority findings

### 1. High: show details wait for optional information

Evidence: `lib/features/movies/presentation/pages/show_detail_screen.dart:150`. `_load` awaits a seven-branch `Future.wait` for core show data, providers, credits, user providers, rating, reviews and friend summary. Only afterwards does `_isLoading` become false. A slow optional section delays the entire page. Failure of the uncaught user-provider branch can fail the page even when the show itself loaded.

Change: display show identity/core details as soon as available, with independent section loading and retry states, following movie detail. Protect navigation and account changes with generation checks. Keep review/progress visibility rules intact.

Verify: hold reviews, providers and friend summary pending independently; core show must remain visible and usable. Fail each optional branch and retry it. Include a long-running series and a show with no seasons.

### 2. High: Plans performs one extra state request per plan before displaying results

Evidence: `lib/features/social/presentation/pages/watch_requests_screen.dart:309`. `_load` fetches the request collection, then awaits state for every request using `Future.wait`, then publishes hydrated results. This costs one collection request plus N state requests and waits for the slowest state call. Group counts also fetch requests for every group at line 280.

Change: reuse the existing direct/Home projections in `WatchRequestCache`, render the list immediately, and fetch authoritative state when opening or acting on a plan. Where required, add an optional compact overview response instead of full per-plan hydration. Preserve all status transitions and build 70 defaults.

Verify: accounts with 0/10/100 plans and 0/5/25 groups; one slow plan must not block all rows. Check badges, invitations, schedule changes, completion and notification targets.

### 3. High: first-time show import sits on the screen's critical path

Evidence: backend `src/services/showService.ts:41` and `:114`. Missing shows call `findShowAndAddToDb`; this fetches show metadata and every non-special season in parallel, imports their episodes, and only then returns. Those season requests have no timeout supplied at these call sites. Existing shows with a null last-air date additionally wait for an external request with a four-second timeout. The response loads all seasons/episodes at lines 66–70.

Change: separate fast metadata availability from complete episode hydration, with explicit readiness states; bound and deduplicate imports and external calls. Fetch season details on demand or prefill asynchronously. Use a compatible optional lightweight mode/new endpoint so build 70 continues receiving its expected structure. Do not mark partial progress as complete.

Verify: uncached multi-season shows, concurrent requests for the same show, failed season fetches, and resuming an incomplete import. Measure response bytes and database time for large episode counts.

### 4. High: API transport does not reuse an owned HTTP client

Evidence: `lib/core/api/api_client.dart:280` and the mutation methods. Outside tests, requests call top-level `http.get/post/put/patch` or `Request.send`. There is no app-owned client used for connection reuse across calls. This matters especially with the multi-request screens above.

Change: inject one long-lived client into the transport with explicit ownership/close semantics. Retain test overrides, GET coalescing, token-refresh handling and account isolation. Measure before/after network setup and total request time; do not claim every request currently performs a new DNS lookup.

Reference: [Dart HTTP package](https://pub.dev/packages/http) recommends Client for persistent connections to the same server.

### 5. High: startup prefetch loads many screens' data immediately

Evidence: `lib/core/auth/auth_prefetch_coordinator.dart:58`. After trending it starts activity, friends, up to 200 friend activities, groups, ratings, reviews, now-playing, lists, notifications and watch providers. Provider warming can add 20 movie-provider calls in batches of five, following the user-provider fetch. Separate `WatchRequestCache.syncUser` starts Home and direct-plan preloads; chat starts its subscriptions too.

This runs after authentication and should not be described as an intentional splash-screen wait. The risk is network/database contention with the screen the user actually opens. The ten-second prefetch Future timeout does not cancel the underlying work.

Change: budget background concurrency, prioritise above-the-fold Home requests, and defer profile history, full reviews and offscreen provider enrichment until needed. Publish useful cache entries progressively rather than waiting for the complete snapshot. Stop obsolete queued work after sign-out/account changes.

Verify: record requests started in the first 2/5/10 seconds, simultaneous request count and bytes; compare small and large libraries under slow mobile networking.

### 6. High: old plan links scan groups sequentially before opening

Evidence: `lib/features/social/presentation/pages/watch_requests_screen.dart:80`. `_resolveGroupPlan` loads groups and then each group's watch requests sequentially until a matching request is found. Even a direct-plan link can wait for this search to finish.

Change: use a permission-checked request-ID resolver or an optional explicit destination for new notifications, retaining the legacy route for build 70. Avoid downloading every group's requests to resolve one plan.

Verify: old and new direct/group notification routes, many groups, missing/deleted plans and membership changes.

### 7. Medium: list summaries fetch every list item to count and preview

Evidence: backend `src/data/users.db.ts:444` includes all non-removed items and their poster references. `src/services/usersService.ts:522` calculates counts using those arrays and then slices only four posters for the response. Database result and server processing therefore grow with the entire collection even though the UI displays a small preview.

Change: keep permission filters identical, get accurate aggregate counts and a bounded ordered preview per list, and paginate the directory if its size warrants it. Do not merely limit items to four and accidentally report four as the total count.

Verify: many lists with hundreds/thousands of titles, mixed films/shows, joint lists and all privacy variants. Compare database rows read, response time and preview/count correctness. No index prescription is justified without execution plans.

### 8. Medium: show list membership uses a serial list-by-list scan

Evidence: `show_detail_screen.dart:231`. After loading the show, the client fetches all show lists then downloads every list's shows sequentially to find which contain this show. It does not block the initial page but delays the list action and grows with the user's collection.

Change: a permission-filtered 'lists containing this title' query/projection. Preserve private and collaborative access. Fetch only when needed or reuse a correctly invalidated membership cache.

### 9. Medium: person detail has an all-or-nothing credits dependency

Evidence: `person_detail_screen.dart:285` waits for both person and credits before displaying either. Images already load separately.

Change: render the person first and load filmography independently, with a local retry. Verify a slow/failing credits response never hides the biography and favourite action.

### 10. Medium: profile eagerly loads work unrelated to the visible Library tab

Evidence: `profile_screen.dart:152–267`. Activity, friends, ratings and extras load together; extras start reviews, groups, requests and yearly wrapped statistics even when the user only opens Library. Wrapped results subsequently load up to four director profiles. Refresh also fetches user data, then lists, then `_loadAll` sequentially.

Change: defer Stats-only work until Stats is visited and reuse appropriately fresh section caches. Keep refresh semantics explicit. Avoid a global spinner and preserve current scroll position. Use account-scoped invalidation after user actions rather than longer cache lifetimes alone.

Verify: Library renders with stats blocked, list changes appear on return, ratings update immediately, and Stats loads/retries when selected.

### 11. Medium: chat subscriptions grow with total conversation count

Evidence: `chat_service.dart:90` subscribes to the user's full conversation query; `chat_unread_controller.dart:77–106` attaches one member unread subscription per conversation. Each stream also awaits chat identity, with only concurrent HTTP GET deduplication available. This is an O(conversations) listener design even outside the Messages screen.

Change: measure 10/100/500 conversations first; consider an aggregate unread projection and a paged conversation summary feed. Keep individual active-chat listeners where needed. Session-cache identity readiness without bypassing identity verification or account resets.

Verify: unread accuracy while backgrounded/reconnected, mark-all-read with new incoming messages, listener disposal on account switch and Firestore read counts.

### 12. Medium: the cold-start gate has multiple serial phases

Evidence: `main.dart:60–134` awaits Firebase, App Check activation, analytics initialisation and preferences before `runApp`. Auth then serially waits for token, backend profile and terms verification (`auth_provider.dart:473–488`, timeout limits 8/10/10 seconds).

Change: instrument each phase before moving it. Render a responsive startup shell earlier where safe; defer nonessential initialisation. A compatible profile response might eliminate a separate consent lookup, but do not bypass terms/auth checks for speed. Startup deadlines need clear retry/offline states.

The timeout limits are not observed launch times and are not a reliable total wall-clock calculation because recovery/bootstrapping also exists.

### 13. Medium: retries and Future timeouts can keep background work alive

Evidence: ApiClient uses a 15-second request timeout and two DATABASE_ERROR retries, delayed 600/1200ms. Those retries are only for qualifying server errors, not every timeout. With three near-timeout error responses, the retry chain can approach 46.8 seconds before auth recovery; this is a code-derived scenario, not a measurement. Outer timeouts do not cancel already-started HTTP work.

Change: per-interaction total budgets, optional-work cancellation/queue invalidation, and visible local retries. Preserve safe mutation semantics; do not blanket-retry writes or weaken auth recovery.

### 14. Profiling candidate: broad rebuilds, blur and image decode sizes

Evidence: Home and Profile watch the entire AuthProvider; unrelated auth notifications can rebuild substantial screen trees. Home trending paints a w780 image as both blurred background and foreground (`home_screen.dart:1394–1424`). Neither call supplies a decode-size hint. The URLs match, so this is not evidence of two separate downloads. Full-resolution movie images also exist in intentional full-screen viewing paths and should not be blanket-reduced.

Change only after tracing: use Selector for specific state; isolate expensive/static sections; size decoded images to actual physical-pixel requirements; measure whether blur or build/layout dominates. Keep visual identity, avatar borders and accessibility text behaviour.

### 15. Reliability/performance candidate: metadata cache lifetime and size

Evidence: `movie_cache_service.dart` is in-memory, day-based and has no entry-count eviction. `getMovie` removes an expired entry, so `getStaleCachedMovie` cannot then provide that same entry after a failed request. Warm navigation benefits from the cache; process restarts do not retain it. Shows do not have the same core-detail cache in `ShowService.getShowById`.

Change: bounded metadata caching with an explicit stale policy. Consider disk-backed public metadata only after measurement. Keep viewer-specific ratings, privacy and progress separate, and invalidate after mutations. Test day rollover, account switches and prolonged browsing.

## Keep the good parts

- Movie detail renders core data independently; optional section failures have local retry controls and generation guards.
- HTTP GETs coalesce concurrent identical reads and share token refresh.
- Router construction is retained instead of being rebuilt on every auth update.
- Home sections load independently and existing content survives partial failures.
- Discover has a 400ms debounce and response-generation checks; do not replace these with fetch-on-every-keystroke.
- Watchlist already batches/enriches around visible pages; avoid reverting this to full-library eager loading.
- Existing WatchRequestCache projections and freshness checks are useful foundations for Plans.

## Measurement and acceptance plan

Use a physical iPhone in profile mode with a fictional fixture account and a controlled non-production backend. Installing the profile build needs a deliberate device/build destination so the user's installed app/account is not accidentally replaced. Compare against the same device, backend revision and network conditions. [Flutter profiling guidance](https://docs.flutter.dev/perf/ui-performance) explicitly recommends physical devices/profile mode.

Cover cold launch, warm resume, tab switching, existing/new movie and show detail, person, community, Plans, notification deep links, Messages, large watchlists, list creation/back navigation and Profile Library/Activity/Stats. Exercise fast Wi-Fi, constrained mobile networking, offline, one slow optional endpoint and endpoint failure. Run cold/warm cases separately; at least 30 iterations for meaningful initial p50/p95 estimates, keeping samples and outliers.

Capture tap-to-route-frame, tap-to-useful-content, optional-content completion, request count/bytes/concurrency, client and server duration, cache hit/miss, UI/raster frame timings, memory before/after repeated navigation, active listeners, and backend query/pool waits. Correlate anonymised request IDs; never record tokens, search contents, chat text or personal identifiers in performance events.

The existing `usable-home-frame` mark happens before trending resolves (`home_screen.dart:302`). Treat it as shell readiness; add a separate first-content milestone. Rename/define milestones before building dashboards around them.

Proposed initial budgets (targets to validate, not achieved results):

| Interaction | Initial target |
| --- | --- |
| Navigation feedback / shell | p95 under 100ms where locally available |
| Warm cached useful content | p95 under 300ms |
| Uncached stored-title useful content on controlled Wi-Fi | p95 under 1.5s |
| Cold launch to useful Home on controlled Wi-Fi | p95 under 2.5s |
| Frame work | inspect missed 16.7ms/8.3ms deadlines for 60/120Hz devices |
| Slow optional request | must never block available core content |
| Repeated navigation | memory/listener counts should settle rather than climb indefinitely |

Do not average server import latency into normal cached navigation and declare either healthy. Report new-title import as its own journey. Validate the lowest supported representative device, not just a recent Pro phone. Backend tuning should follow query plans and production telemetry, with build 70 compatibility checked for every API change.

## Suggested implementation order

1. Add trustworthy screen/content/request timings and capture a physical-device baseline. Repair the stale Home test to assert the actual meaningful controls while preserving the delayed-data checks.
2. Fix show/person loading gates, Plans hydration, legacy plan resolution and HTTP client reuse. Add failure/delay regressions for each.
3. Stage startup prefetch, lazy-load Profile Stats and replace list summary/membership overfetching. Measure request reductions and cache correctness.
4. Separate show metadata import from episode expansion with compatible API support. Then use frame/memory traces to decide which rebuild/image/blur changes are worthwhile.

No estimated percentage improvement is credible until the baseline and revised build are measured under the same conditions.
