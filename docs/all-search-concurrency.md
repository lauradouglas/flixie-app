# All search uses multi-search only

Following the clarified product direction, All search now makes one app request to `/search?type=all`, which makes one backend TMDB `/search/multi` request. Movies, TV shows and people come from that mixed result page. The additional dedicated TV search and client-side merge have been removed.

Dedicated TV filtering and `searchShows()` still use TV search. Search screen debounce, submission, stale-response guards and display ranking are unchanged. Backend search implementation is unchanged.

This intentionally stops supplementing All with shows from a separate TV page. Multi-search's page, totalPages and totalResults are now retained directly instead of replacing totalResults with a merged page length.

Validation: controlled HTTP mocks verify one request, mixed movie/show/person results, pagination metadata, empty results, error propagation and dedicated TV calls. Widget tests verify debounce, submission and stale-response handling with one call per All query. Existing ranking tests remain applicable.

In the prior controlled fixture, sequential 300 ms multi + 700 ms TV requests completed in 1,000 ms; concurrent requests completed in 700 ms. The final multi-only test completes at 300 ms and asserts no second request. These are virtual-clock mock timelines, not device or production latency measurements.

Existing limitations: the screen still applies its own grouping/popularity ordering; no pagination redesign was made. Its stale-response guard advances when the next search starts or input becomes shorter than three characters, leaving the existing brief stale-display possibility during a new longer query's debounce interval. No new caching, timeout policy or production changes were introduced.
