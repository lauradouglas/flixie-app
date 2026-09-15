# IMDb and Letterboxd library import

Entry point: **Settings → Import ratings & watchlist**.

## User flow

- Letterboxd: choose the account export ZIP, or ratings.csv and watchlist.csv.
- IMDb: choose ratings and/or watchlist CSV exports (multiple selection supported).
- Files are parsed on the device. Only normalised title lookup fields and selected rating/watchlist data reach Flixie. Profile, reviews and other ZIP contents are not uploaded.
- Matching produces a review before any user-library writes. Users can correct a match with title search, or skip it. Ready entries can be imported while unresolved entries remain for later.
- Existing Flixie ratings are preserved. Watchlist additions are upserts, including reactivation of removed entries. Repeated requests are safe.
- Progress is checkpointed per Flixie user on this device. Leaving during a request pauses after that request, then closes. Reopen Settings to resume; this is not a background import service.

## IDs and missing catalogue records

IMDb `Const` values are external IDs (e.g. `tt0133093`), **not** TMDB primary keys. The backend calls TMDB `/find/{imdbId}?external_source=imdb_id`, chooses movie or TV results as appropriate, and returns the TMDB ID. There is no title-search fallback for a missing external ID; the user can search explicitly.

Letterboxd title/year searches require one exact title or original-title match and exact year for automatic selection. Missing years, multiple matches, or imperfect matches need user confirmation.

Before saving **each** entry, `LibraryImportService.commit` calls `MovieService.ensureMovieExists` or checks `Show` and calls `ShowService.findShowAndAddToDb`. Missing catalogue data is imported through the existing catalogue services. Failed hydration prevents that entry's rating/watchlist transaction. Users can retry or skip it.

## Backend contract

Deploy migration `20260915170000_undated_import_watches` before the accompanying FlixieBE change. It allows a null movie watch date; existing viewing dates and normal logging defaults are retained.

- `POST /users/me/library-import/resolve`: title, optional year / IMDb ID, mediaType (`movie` or `show`). Returns `match` and `candidates` with TMDB IDs.
- `POST /users/me/library-import/commit`: selected TMDB id, mediaType, optional integer rating (1–10), optional ratingDate (ISO date), watchlist boolean. Returns separate rating/watchlist outcomes: `added`, `kept`, or null.
- Both routes derive ownership from the authenticated Firebase user. The app also sends its checkpoint's userId through the existing ownership guard to reject an account switch during a request.
- User writes happen in a transaction. Unique constraints and createMany/skipDuplicates protect existing ratings. Movie community aggregates and recommendation invalidation are updated in that transaction. Imports do not submit votes to TMDB.

## Scope and limits

- Letterboxd half-stars multiply by two; IMDb scores remain unchanged.
- Ratings preserve valid original rating dates. Unknown/invalid rating dates use the date of import. Each rated movie also gets an undated watch entry (`watchedAt: null`) if no active watch already exists. The entry uses the retained Flixie rating when one already exists. Rated series get series-level watched status, without creating episode watches. Watchlist-only imports never mark a title watched. Re-imports do not add rewatches or replace existing viewing dates.
- IMDb film and series types are supported. Individual episodes and unsupported title types are reported and skipped.
- Maximum 20 MB of selected files, maximum 20 MB expanded ZIP, and 30,000 parsed rows. ZIP contents are never extracted to disk.
- Unrecognised files fail with an actionable message. Invalid rows and conflicting duplicate ratings are reported in the preview.
- Existing ratings cannot be overwritten by this first version. To import a deselected category later, start another import with the same export.
- Catalogue matching and native file pickers need a real-device/backend smoke test before release. Automated coverage uses representative synthetic exports and mocked backend dependencies, not private user exports or live database writes.

## Sources

- [Letterboxd account export](https://letterboxd.com/user/exportdata/)
- [IMDb ratings export help](https://help.imdb.com/article/imdb/track-movies-tv/faq-for-imdb-ratings/G67Y87TFYYP6TWAV)
- [IMDb list export help](https://help.imdb.com/article/imdb/track-movies-tv/faq-for-the-list-feature/GNQMN47VZSE7KW38)
- [TMDB external-ID lookup](https://developer.themoviedb.org/reference/find-by-id)

## Automated checks

Flutter: `library_import_parser_test.dart`, `library_import_controller_test.dart`, `library_import_screen_test.dart`.

Backend: `libraryImportMatching.test.ts`, `libraryImportService.test.ts`, plus the existing user ownership middleware tests. Coverage includes ID translation, strict matching, missing movie/show hydration, safe retries, account-scoped checkpoints, ZIP parsing, scale conversion, malformed data and responsive text layouts.
