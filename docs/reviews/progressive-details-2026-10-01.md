# Progressive detail loading and connection reuse — 1 October 2026

Implements the four follow-up performance changes approved after staged preloading.

- Home trending, Search results and Watchlist detail navigation carry public title/poster previews. The preview renders immediately while authoritative data loads; direct links retain a skeleton fallback.
- Show details render an opt-in metadata response independently of complete episode/progress data, credits, providers, reviews and personal rating. Slow/failing sections do not remove the title page. Progress and watch options have explicit loading/error states; retries preserve visible content. A late metadata response cannot replace a completed full response.
- Plans requests lifecycle state already included in the collection response instead of unconditionally fetching each plan. RequestService retains per-plan fallback for older servers missing state fields. Focused plan routes still fetch authoritative state.
- Main initializes one application-owned HTTP client reused across ApiClient verbs. Credentials are applied per request; existing retries, deduplication, account-generation guards and test overrides remain intact.
- Backend `/shows/id/:id?summary=true` returns a bounded public metadata projection without awaiting season imports, personal state or trailers. Full requests still finish imports, and concurrent imports share in-flight work. Metadata/season upstream calls have eight-second timeouts. Missing TMDB titles retain null behavior. The default endpoint response is unchanged for Apple build 70.

## Validation

- 35 distinct focused Flutter tests passed: shared transport, fixture override, progressive show loading and response ordering, episode progress, Plans retrieval/UI/background cache, and API auth recovery.
- 5 backend progressive-loading tests passed; 16 build-70 compatibility tests passed.
- Focused Flutter analysis clean; backend `tsc --noEmit` clean; diff whitespace checks clean.
- Request-count fixture verifies twenty complete plans require one collection request rather than twenty-one. Gated widget fixtures verify visible title content before full/optional responses complete. These prove dependency/request-count changes, not milliseconds saved on a physical release device.
- No production deployment, schema migration or live-account fixture writes. Physical-device profile traces and production latency measurement remain outstanding. Existing full-season import still runs for complete detail requests; this change removes it from the initial metadata response rather than introducing paginated episode APIs.
