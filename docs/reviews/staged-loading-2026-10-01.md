# Staged loading implementation

Implemented the approved preload discussion following the performance review. The account snapshot already contains movie/show watchlist membership and favourites; these stay the source of truth for saved-state mutations rather than adding a second private-data cache.

- After a frame: warm notifications, active plans and a bounded set of public show summaries.
- After Home content: decode at most six watchlist posters sequentially.
- On destination entry: use preloaded summaries immediately, share in-flight metadata requests, then enrich visible rows.
- On Stats selection: load full reviews and yearly statistics, then director details. Re-entering Stats uses the same screen state; pull-to-refresh/retry can update it.
- Old activity remains paged; provider enrichment remains viewport driven.
- Plans publish collection results before all detailed state responses finish. Focused plan routes retain their authoritative state lookup.

Startup no longer requests full activity history, a 200-item friends feed, ratings, reviews, now-playing, list directories and twenty title-provider lookups through AuthPrefetchCoordinator. Home still owns the requests required for its visible content.

Public show summaries have a ten-minute lifetime and 200-entry cap. Concurrent batches share per-ID futures, omitted/failed entries remain retryable, batches are bounded to 25, and an account reset prevents late writes. These summaries are never substituted for full show-detail/episode responses.

Validation: 44 distinct focused tests passed; `scripts/test-patrol.sh -d D4255A47-A9F1-4BFB-A770-557608119574 --target patrol_test/watchlist_paging_test.dart` passed on the dedicated simulator. Analyzer: no new issues; four existing unused profile declarations remain. The running development Flutter process was sent its supported hot-restart signal because startup behaviour changed. No release-device speed percentage is claimed.

No backend deployment, database migration or build-70 contract change. The wider review's transport, import and database proposals remain pending.
