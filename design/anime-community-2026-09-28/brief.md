# Anime community concept

28 September 2026. User requested a community mockup using Anime as the example,
then explicitly chose an equal mix of discovery and discussion. This authorises
a design prototype, not production feature implementation.

## Direction

Operate mode; extend Flixie's incumbent UI. Dark purple surfaces, Manrope,
purple primary actions, mint member-score accents, personal avatar badge borders.
Source authority: lib/app/theme/app_theme.dart, genre_community_feed_screen.dart,
and design/pick-journey-2026-09-26/results.png. No new brand identity is proposed.

Thesis: come for an anime recommendation, stay for the people and conversations.
Discuss and Discover have equal navigation prominence; Reviews retain the original
public review model; People makes discovery of authors intentional. A compact header
gets out of the way. Mobile stacks the supporting discovery and community information;
desktop places it beside the discussion feed.

Existing facts: Anime uses exact catalogue anime keywords, not Animation genre
membership. Films and series coexist. Reviews must be public and by joined members.
Joining doesn't change sharing preferences. Low member ratings remain valid.
Member averages use one latest public rating per person per title, with count and
community scope distinct from global scores. Original posts own review comments.

Proposals: new title-scoped discussion threads and replies, explicit episode spoiler
boundaries, a member-rated discovery query, member directory, film/series filtering,
contextual watchlist shortcuts and editorial beginner collections. Dedicated threads
need authorisation, moderation/report/block/mute handling, pagination, visibility and
spoiler-safe titles/previews. Later notifications must be opt-in. No assumption that
these endpoints exist, no online-member or activity-count claim.

The standalone HTML prototype simulates joins, follows, watchlist state and replies.
No network mutations or account access. Member names, reviews, counts and scores are
fictional. The composer is a flow sketch, not a working discussion backend. Existing
app bottom navigation is illustrative. Series art uses a labelled placeholder.

## Asset provenance

Manrope and Flixie wordmark reused from the repository. Film posters sourced from
TMDB image CDN on 28 September 2026, HTTP 200 confirmed:
- assets/spirited-away.jpg: https://image.tmdb.org/t/p/w500/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg
- assets/princess-mononoke.jpg: https://image.tmdb.org/t/p/w500/cMYCDADoLKLbB83g4WnJegaZimC.jpg
- assets/your-name.jpg: https://image.tmdb.org/t/p/w500/q719jXXEzOoYaps6babgKnONONX.jpg

Verification: isolated headless Chrome, 1440px desktop and 390px phone; no horizontal
overflow or missing images. Checked explicit joining, spoiler gate before discussion,
local reply and series-only filter; no JavaScript errors. Screenshots alongside HTML.
This is browser prototype verification, not native Flutter/device validation.

Finish review: two contrast/legibility findings corrected in one batch (white
primary text/darker hover; 11px avatar initials). Reviewer disposition: ship for
those scored fixes. Final desktop/phone captures and interaction checks passed.
No global PRODUCT.md or DESIGN.md was created: this is a scoped prototype extending
the existing visual system, not a brand definition or a production UI change.

## Mobile-first correction
User clarified iOS and Android apps are primary. The browser now presents a
maximum-430px phone canvas even on desktop, with stacked content and sticky bottom
navigation. This remains a web interaction sketch, not a native iOS/Android build.
Future implementation must use native safe areas, platform back behavior and text
scaling; desktop composition is secondary and is not the recommended app layout.
