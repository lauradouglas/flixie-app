# Pick for me / Pick for us

Home opens a scrollable picker using Flixie’s existing dark palette, Manrope typography, and profile avatars with each person’s badge border. No app-wide design changes.

## Flow

- “Just me” is selected by default; no social connection is required. Optionally select one friend or all accepted members of an existing group (2–12 people).
- Choose streaming or cinema, a maximum movie runtime, and a mood. A 300-character request supports common mood/genre phrases, including chill, cozy/cosy, rom coms, and genre exclusions such as “no horror”. Recognized text overrides the mood chip; results explain the interpretation. Unknown wording falls back explicitly to the selected mood and taste.
- Rewatches are opt-in, via the switch or wording such as “even something I’ve watched before”. Explicit “not watched before” or “no rewatches” takes priority. Rejected and poorly rated movies stay excluded.
- Streaming together needs a matching service for at least one viewer. Optional rentals are labelled as paid and used when no subscription offer matches that movie.
- Streaming separately requires the same provider to be saved by every viewer and the film to be available on that provider in each viewer’s saved country. Rentals are excluded.
- Cinema uses the existing TMDB now-playing feed for the organiser’s saved country. It does not guarantee local showtimes. Runtime excludes trailers and adverts.
- Up to three choices show evidence-based reasons. A missing third match is explained, never filled with an unsuitable title.
- Solo results open the movie details. With other viewers, Make a Watch Plan opens the existing form with the movie, friend/group and Cinema venue preselected. The user still reviews and submits the plan.

## Backend

`POST /recommendations/pick-for-us` requires authenticated identity; it never trusts a client user ID. Body: neither `friendId` nor `groupId` for solo, otherwise exactly one, `maxMinutes` (90/120/150/180/240), `mood` (anything/chill/cozy/romcom/thrilling/funny/comforting/moving/adventurous/scary), `venue` (streaming/cinema), `watching` (together/separately), `openToRent` (boolean), optional `request` (string, maximum 300 characters), optional `allowRewatches` (boolean, default false). Rental opt-in is valid for solo streaming or streaming together. Solo uses `watching: together` internally for backwards compatibility.

Friendship or accepted group membership is checked before reading profiles. Ranking combines watchlist overlap, positive genre affinities (including the weakest viewer’s match), previously liked rewatches, TMDB quality and vote-count popularity. Watched titles are excluded unless rewatches are enabled; not-interested and negatively rated titles remain excluded for every viewer. Runtime and mood are hard constraints. Provider lookup failures never count as availability.

The streaming candidate pool is bounded to 500 saved/history movies plus 300 quality discovery titles ordered by audience vote count, with availability checked for at most the top 36. Cinema inherits the existing now-playing feed’s top-12 limit. This first version uses genre-based moods and genre taste affinities; it uses explicit phrase rules, not an LLM, and does not infer arbitrary requests or complex emotional tone. Rom coms require both romance and comedy; chill/cozy exclude horror, thriller, crime and war. Popularity reflects cached TMDB vote counts, not a live trending feed. Streaming availability inherits the existing 24-hour provider cache. No schema migration is needed; deploy the FlixieBE endpoint alongside the app changes.

## Verification

Focused backend tests cover solo identity, rewatch opt-in and exclusions, mood interpretation, popularity, relationship permissions, cinema region/source, provider checks by country, rentals, runtime/mood exclusions, and explanation evidence. Flutter tests cover solo mood/rewatch submission, selection, retry, and scrollable layouts on 320/430-pixel phones, landscape and tablet with 1.8× text. Optional widget-render captures use `--dart-define=PICK_VISUAL_REVIEW=true --update-goldens` and write to `.impeccable/review/`. Live provider calls and device builds are not covered by these fixtures.
