Method: dual-agent (A: /root/design_review · B: /root/evidence_review)

# Flixie watchlist — design review and proposed improvements

12 September 2026 · Scope: supplied screenshot and relevant Flutter source. This is a design proposal, not a production UI change.

## Recommendation

Make each title answer three questions in this order: **What is it? What did my friends think? Where can I watch it?** Preserve Flixie’s dark violet identity and labelled navigation, but reduce the administrative controls above the list.

The existing screen is recognizably Flixie, with useful posters and clear title emphasis. Its structure feels more like a collection dashboard than a place to choose tonight’s viewing. The strongest product-specific improvement is friends’ viewing and ratings placed directly beside availability.

## What works

- Posters and prominent titles establish the entertainment context immediately.
- Separate movies/shows views plus search, sorting and filtering can support a large collection.
- Labelled bottom navigation makes the current location clear.

## Priority changes

| Priority | Change | Why and proposed treatment |
|---|---|---|
| P1 | Bring titles higher | The first title begins roughly 56% down the supplied screenshot. Remove the statistics panel, use a compact saved-title count, and retain one history link. Replace the second status strip with two useful shortcuts and a filters control. Aim to show two complete titles on a typical phone at default text size. |
| P1 | Show watched friends and actual ratings | “1 friend recommends” does not answer who watched or how they rated it. Show bordered avatars, “3 friends watched”, and “Friends’ average 8.5/10 · 2 rated”. Open individual ratings from that row. Never count unrated watches as zero. |
| P1 | Explain watch offers | Replace unexplained logos/green rings with provider names plus Included, Subscription, Rent or Buy. Prefer the user’s services when known. “All options” reveals other offers, country and any add-on subscription requirement. |
| P2 | Reduce competing emphasis | Reserve violet for selection and actions. Remove the large card gradients, strong repeated outlines and dashboard statistics. Use separators and consistent spacing to establish title → friends → provider hierarchy. |
| P2 | Use card space for decisions | Move added date and removal to overflow/details. Remove the redundant saved bookmark. Include Movie/Show explicitly; use show/season metadata for TV. Let meaningful titles wrap and keep all action targets at least 44 points. |

Relevant follow-up Impeccable commands: `distill` for controls, `clarify` for social/provider copy, `layout` for rows, and `adapt` for text scaling and device reflow.

## Mockup and interactions

Open `mockup.html` for the interactive concept. `mockup-board.png` presents the overall design and an expanded ratings example; `mockup-mobile.png` presents the phone view.

The concept includes working title search, All/Movies/Shows switching, On my services and Friends watched filters, sorting, clear-filter recovery, an Inception individual-ratings panel, and provider-option panels. Add, watch history, watch-status changes, removal and navigation outside this surface are explicitly labelled demonstrations. No real watchlist data is changed.

All names, ratings, provider offers, service memberships and show metadata are sample content. Text tiles represent poster artwork; production retains real posters. The avatar examples have distinct illustrative border treatments. In Flutter, retain each actual user’s `ProfileAvatarView(profileBadges: ...)` and existing `SpecialAvatarFrame` behavior rather than recreating these CSS samples or applying a generic border.

### Friends and ratings

- Summary: watched count, rated count and labelled friend average. Use the existing product rating scale consistently; the concept illustrates a 10-point scale.
- Detail: each friend’s name, own avatar border, watched state and rating. A friend with no rating shows “Not rated yet”.
- TV: distinguish watching, watched to date and completed if supported. Label whether ratings apply to a show, season or episode; do not average different scopes together. Avoid spoilers in the watchlist; keep review text behind the detail view.
- Respect existing privacy/visibility rules. “No friends watched yet” is appropriate only after a successful lookup; errors must not look like zero activity.
- Keep “recommended” as a separate signal if retained. Watching something does not imply liking it.

### Providers

- Main row: one or two relevant named providers, offer type, and remaining-options link. Logo artwork may accompany readable names.
- Details: country, all available offers, subscription versus add-on channel, rent/buy and confirmed price if available. Open the relevant provider destination on selection.
- “On my services” should mean included viewing on selected services; merely offering a rental on a subscribed platform does not qualify.
- With no saved subscriptions, offer service setup rather than silently filtering everything out. Country should be user-selectable and inherited from the account where available.
- Use separate loading, failed lookup and successful-no-offers states. A missing response does not prove the title is unavailable.
- Cache and batch availability/social results; show the list without waiting for every provider logo or friend response.

## Implementation findings

Source review identified changes beyond styling:

1. `watchlist_screen.dart:235–238` retains only friends whose `recommends` flag is true. The friend model already contains watched state, nullable ratings, average friend rating and profile badges. Preserve eligible watched friends, then derive watched/rated/recommendation counts separately.
2. `_buildShowWatchlistRow` at line 1551 has no equivalent social row. Confirm or extend the show social-data service; copying the movie widget alone will not supply TV ratings.
3. Movie/show cards use fixed poster widths, ellipsized text and 30×30 title actions. Reflow metadata and enlarge effective touch targets.
4. Provider presentation already knows some subscription matching and rental distinctions, but communicates much of that through 34px logos, green outlines and reduced opacity. Surface those distinctions as text. The current inline logo widget has a tooltip but no direct click handler.
5. `_RecommendationAvatars` already carries each friend’s badge data into `ProfileAvatarView`. Preserve this pipeline and avoid double frames.

These references describe the source inspected on the review date. No Flutter source was modified for this proposal.

## Design health score

Scores reflect observable design evidence; untested behaviors are not given invented scores.

| Heuristic | Score | Evidence |
|---|---:|---|
| Visibility of system status | 3/4 | Selections visible; availability state ambiguous |
| Match with the real world | 2/4 | “Watched in list” and offer meaning need interpretation |
| User control and freedom | n/a | Undo and navigation behavior not exercised |
| Consistency and standards | 3/4 | Coherent components; duplicate history entry points |
| Error prevention | n/a | No destructive flow exercised |
| Recognition rather than recall | 2/4 | Provider logos and header icons require interpretation |
| Flexibility and efficiency | 2/4 | Useful tools, excessive vertical overhead |
| Aesthetic and minimalist design | 1/4 | Controls and statistics dominate the collection |
| Error recovery | n/a | Native failure flow not exercised |
| Help and documentation | n/a | Not assessable from supplied screenshot |
| **Total** | **13/24 (54%)** | **Acceptable foundation; substantial hierarchy improvements needed** |

## People most affected

- **Distracted mobile user:** has to scroll before comparing two complete titles. Reduce overhead and give rows a predictable reading order.
- **First-time user:** cannot infer whether green provider borders mean availability, subscription ownership or recommendation. Use explicit offer labels.
- **Low-vision user:** small muted metadata and tiny logos increase reading effort. Verify contrast, VoiceOver and dynamic type in Flutter; the screenshot alone cannot prove compliance.

There is no unusual group with more than four choices apart from conventional five-item navigation. Cognitive load comes from stacking multiple groups, duplicated “All” states and repeated history access.

## Responsive and state requirements for implementation

Test small/large phones, tablet, landscape and increased system text. At narrow widths or large text sizes, stack metadata and provider labels, let titles wrap, and use a scrollable list. Preserve readable touch targets even when fewer items fit.

Present native detail/filter sheets with `useRootNavigator: true` and `useSafeArea: true`, a viewport-relative maximum height and a scrollable body. The HTML dialog demonstrates content and interaction, not final native sheet mechanics.

Also cover an empty watchlist, zero matches with Clear filters, unrated friends, no friends, private activity, unavailable images, loading, offline/failed social or provider requests, long translated text, and undo after removal. Marking a show watched must make the scope clear.

## Prototype checks

Browser checks passed for movie/show filtering (2 shows), subscription filtering (1 matching show), empty-search recovery and opening/closing individual ratings. No page-wide horizontal overflow appeared at 320px, tablet or landscape widths, or in a simulated enlarged-text check. Phone and overview captures were visually inspected. These checks cover the HTML concept, not Flutter device accessibility.

## Verification limits

Two independent assessments were completed. The native detector returned no findings, but its supported extensions exclude Dart: this is unavailable coverage, not a clean bill of health. The HTML detector fell back to regex because parser dependencies were unavailable; its one finding flags the selected-tab underline as a rounded-card accent, a false positive. No browser overlay was injected. Native VoiceOver, device behavior, live provider accuracy and system text scaling remain implementation checks.

Questions skipped: the user already specified the improvement goal and requested a concrete mockup and report. The proposed direction can be reviewed without another discovery step.
