# Watchlist: What fits tonight?

Compact Time, Mood and Services controls open safe-area, bounded sheets. Experience goals are independent from genre: Switch off, Feel good, Have a laugh, Get hooked, Feel something, Escape somewhere, Be challenged and Get scared. Romantic comedy is an advanced genre filter requiring comedy and romance together.

Experience matching calls authenticated `/recommendations/watchlist-fit` in batches of at most 25 titles. The server reads title-level evidence and an editorial catalogue; movie taste uses the existing profile built from ratings, watch entries and favourites. Movie preferences are not falsely attributed to shows. The watchlist ranks confidence first, then personal taste, then audience popularity. Pick one chooses the highest-ranked visible experience match; without an experience filter it remains random. Each experience result names its confidence and reasons alongside existing service offers. Request failure offers retry and never falls back to genre-based mood matching.

Unreviewed title evidence stays provisional internally and is explained with cautious, title-specific wording. Optional avoidances cover bleak stories, horror, violence and heavy themes. Unknown content is withheld when an avoidance is selected. The user is told when missing information limits results; the app does not offer confidence or unchecked-content switches. The reviewed catalogue is initially empty; verified-absence searches may return no titles until editorial coverage is added. See the backend's `docs/title-experience-review.md` for the review workflow.

Time, selected services, search, media type, viewing status and advanced filters remain mandatory. Unknown/zero runtimes cannot meet a time limit. Shows use the longest known positive non-special episode duration, labelled as an estimate, not a promise about the next episode.

Services starts with saved subscriptions. “Add another service” loads the regional catalogue. Guest selections apply only to this search and never write profile settings. Apply commits local selections; dismiss cancels; Any service disables the restriction; Clear filters discards guest services. Included offers must match a selected service. Rentals are opt-in; purchases and unknown offers do not qualify. Availability rows use the same temporary selections. Live accuracy depends on the provider cache.

Deploy the backend before the app (including `/shows/by-ids` and `/recommendations/watchlist-fit`). No migration is needed. Tests cover misleading mood assumptions, confidence, unknown content, genre combinations, authenticated ownership, error/retry, time and service restrictions, temporary providers, and responsive layouts with enlarged text.


## Plain-language watchlist search (September 2026)

The watchlist entry is now **Find a pick** → **What do you fancy?** → **Find in my watchlist**. A blank request still ranks the saved titles using taste and audience signals. Users can type a description or tap examples. Mood and avoidances are collapsed optional sections. “Chick flick” means romance or friendship stories, with optional rom-com, friendship and emotional-romance refinements. Refinements preserve the rest of the request, including exclusions. Time and guest services still narrow the resulting watchlist.

The previous confidence switches and reviewed/possible labels are no longer presented to users. The app automatically includes supported provisional suggestions, keeps their uncertainty in plain-language title reasons, and never relaxes explicit avoidances. Unknown content coverage is withheld and explained in empty results. Confidence remains internal for ranking and review provenance. Legacy API confidence fields remain compatible, but the app always sends includePossible=true and includeUnknownContent=false.

The description parser is bounded, not general AI conversation. Unsupported descriptions receive helpful examples and no falsely matched results. Both watchlist search and Pick for me use the same interpretation and evidence rules.
