# Watchlist improvements

Implemented against `design/watchlist-review/report.md`, `mockup.html` and `mockup-board.png`.

## Behavior

- Compact saved-title count and one history link; search, media filters, sort, viewing-state filters, refresh and existing movie actions remain available.
- “On my services” matches explicit included offers on selected services, not rentals or unknown offer types. With no services selected it opens existing subscription preferences. “Friends watched” works for movies and shows. Clear filters recovers empty matches.
- Shared movie/show rows retain network posters, wrap titles and metadata, and move added dates/removal to overflow. TV watched management opens the existing show detail/progress controls instead of implicitly marking every episode watched.
- Friend summaries count explicit watched states separately from recommendations, exclude null ratings from averages, preserve profile badges and use `ProfileAvatarView`. Details show each friend’s name, watched state, rating scope, individual rating or “Not rated yet”.
- The backend movie query now retains unrated watches and excludes blocked/deactivated users. A bounded authenticated TV batch endpoint reuses that query for show-level ratings. Episode/season ratings are not mixed into show averages. Private custom-list activity is not queried.
- Provider offers retain names, offer types and source watch links. TV lookups no longer fall back to Taiwan when a country has no offers. Movie fallback requests preserve the selected country and parse the nested response correctly. Malformed responses and failed lookups remain errors, not confirmed empty results.
- Movie provider caching is reused. TV providers use a bounded country/title cache and batches of at most six concurrent lookups. Social requests use batches of 25 titles, with generation guards and partial-failure recovery. Subscription removal updates matching immediately.
- Watchlist sheets use the root navigator, safe areas, bounded viewport-relative heights and scrolling. Existing bottom navigation is unchanged.

## Validation

- Targeted Flutter analysis: no issues.
- TypeScript `tsc --noEmit`: passed.
- 32 Flutter tests passed across watchlist rows, screen states, batching, provider matching and movie cache regressions.
- 9 backend tests passed across viewing/rating semantics, privacy selection, badge preservation, movie batch regression, authenticated TV batching and regional offers.
- Responsive tests cover 320×568, 430×932, 834×1194 and 844×390 at 1× and 2× text scale. Full-screen shortcut tests require successful hit testing. Row/detail-sheet tests check overflow and scrollability.
- Local widget render captures inspected. They use fixture users/offers and poster fallbacks; these fixtures are confined to tests. Production uses API data and real poster URLs.
- Impeccable’s detector returned no findings, but it does not provide Dart coverage; Flutter tests provide the relevant layout checks.

Run:

```sh
flutter analyze lib/features/watchlist lib/features/movies/data/movie_service.dart lib/features/movies/data/show_service.dart lib/models/watch_provider.dart lib/models/friend_recommendation.dart test/watchlist_movie_row_test.dart test/watchlist_screen_states_test.dart test/watchlist_recommendation_batch_test.dart
flutter test test/watchlist_movie_row_test.dart test/watchlist_screen_states_test.dart test/watchlist_recommendation_batch_test.dart test/watch_provider_match_test.dart test/movie_detail_cache_test.dart
```

For optional local PNG captures, run the widget tests with `WATCHLIST_CAPTURE=1`; they write `/tmp/watchlist-*.png`.

## Integration limits

The app and backend changes must be released together for the new TV social endpoint. No deployment was performed.

TMDB supplies a title/country watch-options URL, not verified individual-provider deep links, current prices or plan entitlements. The sheet opens only the supplied HTTPS TMDB watch destination and labels it accordingly; absent destinations are explicitly unavailable. Channel subscriptions and separately paid rentals/purchases are explained without inventing prices or entitlement guarantees. Cached offers created before the backend update may lack links until refreshed.

TV watched status represents the explicit show-level watched record; it does not claim every episode is complete or infer progress from episode ratings. Episode/season progress remains in show details.

Live signed-in data, native device navigation and VoiceOver/TalkBack were not exercised. Flutter reports pre-existing Swift Package Manager compatibility warnings for three dependencies.
