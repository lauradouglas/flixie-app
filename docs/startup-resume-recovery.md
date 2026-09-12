# Startup and resume recovery

## Scope and confirmed findings

Both working trees were clean before this change. No production services, database changes or load tests were used.

The previous implementation fetched a token during sign-in, then forced another refresh before profile loading. Shared forced refresh had no deadline. `handleAppResumed` had no lifecycle caller; Home separately refreshed watch plans. Resume recorded freshness before success and started broad prefetching. Temporary initial profile failures could discard authenticated state. Prefetch and Home used different friends-feed limits (100 versus 200), preventing request sharing. Home secondary sections awaited one combined future. Backend Firebase verification classified transport failures as 401.

These are verified code paths; the reported physical-device freeze has not been reproduced.

## Behaviour

Essential startup data is a Firebase session/token, backend profile (including onboarding state), and Home trending/featured content. The existing splash and Home loading screen remain until these stages finish; essential failures expose Retry. Recommendations, friends activity, watchlist, continue-watching and watch plans are secondary. Their failures preserve existing content and expose a retry action.

Firebase's ordinary token lookup reuses a valid token and refreshes an expired one. HTTP 401 still invokes a shared forced refresh. Token waits are bounded to eight seconds, profile waits to ten seconds, HTTP requests retain their fifteen-second deadline and existing bounded retries. Backend verification has an eight-second deadline and returns 503 for temporary verification failures, preserving 401 for invalid credentials.

AuthProvider now owns lifecycle recovery. Content stays visible. Successful profile refreshes are throttled for two minutes; failed attempts do not advance freshness. Recovery attempts run after 5, 15 and 30 seconds while foregrounded; after that, Retry or another foreground event can recover. There is no continuous connectivity watcher or unlimited retry loop.

Session/request generations, token revisions and ownership checks prevent old token/profile/prefetch/Home results from updating newer state. Timeout does not cancel Firebase or HTTP operations: late completions are ignored rather than assumed cancelled. Profile refreshes and token refreshes coalesce; pending authenticated GETs are scoped to the session. Notification polling avoids overlapping ticks. Broad startup prefetch no longer runs on every resume/profile refresh. Startup prefetch prioritises trending and uses Home's friends-feed parameters so overlapping requests share work.

## Validation and measurements

- 26 Flutter tests passed across recovery, request sharing, actual Home loading/retry, onboarding, Home watch-plan projection, movie cache and search stale-response tests.
- Two backend middleware tests passed: credential/transport classification and hung verification with late completion.
- Flutter analysis of all twelve changed implementation/test files: no issues. Backend TypeScript check and both diff whitespace checks passed.
- Tests cover restored/sign-in sessions, missing initial auth event, repeated resume, hanging token retrieval, offline profile recovery, account switching/logout with pending work, late prefetch, essential Home gating and independent secondary failure/manual retry.

Controlled virtual-time comparison, using fixed mock delays: original forced-token/profile readiness **500 ms**, cached-token/profile readiness **210 ms** (token 300 versus 10 ms; profile 200 ms in both). This is not measured Flutter rendering or device performance.

Actual service calls through a mock HTTP client: overlapping friends prefetch/Home requests **2 → 1**; overlapping trending requests use **one** request. Hanging token recovery reaches a recoverable state after **8 seconds** in controlled tests, then a subsequent attempt succeeds; late completion cannot replace the newer token. Home widget tests prove useful content appears before held secondary requests complete. No numeric device time-to-Home or endpoint latency claim is made.

## Remaining evidence and manual validation

Real profile/release-mode timings and the reported device freeze remain unverified. No build was installed over the user's personal app. Use an isolated development build and DevTools timeline markers `Flixie.sign-in`, `Flixie.session-token`, `Flixie.profile`, `Flixie.usable-home-frame`, `Flixie.home-secondary-complete`, and `Flixie.resume-recovery` to measure authentication, profile, useful Home, complete secondary loading and recovery separately.

On that build, exercise cold sign-in/restoration, long background periods, airplane-mode resume followed by reconnection, Retry after the bounded automatic retry budget, notification deep links, onboarding and account switching. Native Firebase expiry/network behaviour and push-navigation integration still need device validation. Local tests do not establish those platform behaviours or real-world speedups.
