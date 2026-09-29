# Flixie information architecture proposal

29 September 2026. Source-based product/navigation review, not a usability study or visual audit. Mode: Operate. Mobile iOS/Android. Proposal only; no route or product changes approved. Assumption pending user response: choosing what to watch and sharing the experience are equally important.

## Main recommendation
Keep five primary destinations and clarify their ownership before renaming or moving them. Current Home / Watchlist / Search / Social / Profile is a workable foundation. The problem is overlapping responsibilities and hidden destinations, not the number of bottom tabs. Prioritise frequent tasks over database entities.

| Destination | User question | Owns | Should only preview/link to |
|---|---|---|---|
| Home | What is useful for me right now? | Contextual dashboard, resume points | Next plan, picks, continuing series, community/public activity |
| Watchlist | What do I want to watch? | Saved films/series, filtering, organising into lists | Title details, choosing together, viewing providers |
| Search | What am I looking for? | Search and browsing films, series and people supported by the current search surface | Title/person detail, picker entry |
| Social | Who am I watching or talking with? | People, activity, groups, communities; access to messages and plans | Shared title and review destinations |
| Profile | What have I watched and what is my taste? | Public identity, favourites, personal library, watch history, ratings, reviews, stats | Relationships; account settings |

Do not rename Search to Discover just for style. A future Discover destination is useful only if it actually combines browsing and search well. Do not rename Watchlist to Library unless moving history/reviews/lists there is separately tested and approved. Avoid a sixth bottom tab.

## Social: make the hierarchy easier to predict
Current Social has People / Activity / Chats / Groups / Communities. It defaults to People. Proposed: Activity / People / Groups / Communities, with a clearly labelled Messages action and unread count in the header. Keep Messages one tap away, not behind an overflow menu. Move Invite and Find friends into People, retaining sensible contextual invites from a group or plan. Returning users can resume their last Social section; new users receive useful browse paths without fabricated social activity.

- Activity: Friends and Around Flixie remain distinguishable feed scopes. Preserve the user-approved Around Flixie label. Do not treat public activity as a joined-community feed.
- People: friends, following and incoming friend requests. Friendship is reciprocal; following is one-way. Do not conflate either with community membership.
- Groups: private/explicit-membership coordination and shared lists. Do not bury groups within People as though they were individual relationships.
- Communities: topic-based browsing, discovery and public discussion. Browsing before joining; explicit membership; no automatic follows.
- Messages: direct and group conversations. New message count belongs here. Public thread replies belong to their original thread, not a duplicate chat.
- Plans: one canonical overview accessible from Social and contextual Home/group/title shortcuts. In the overview use Needs your response / Upcoming / Past. Keep choosing a film, votes, confirmations and scheduled time inside the same plan detail. A notification is an entry point, not the only place to recover a plan.

This is a proposed tradeoff: an explicit Messages action saves one horizontal tab but must remain discoverable and accessible with large text. If real usage shows messaging is the dominant task, retain its current prominence instead.

## Profile: identity first, management second
Current Profile has Library / Activity / Social / Stats. Keep the public identity and taste summary upfront, followed by Library / Activity / Stats. Replace Profile's Social subtab with simple friends/following links to the canonical Social destinations. Preserve public relationship information and profile actions where relevant; remove duplicate management screens, not useful links.

Library should clearly separate favourites, lists, watch history, ratings and reviews. Favourites are identity; a watchlist is future intent; a history entry is an actual viewing. A user should not need to scroll past every collection to find ratings—use clear section anchors or a compact library index. Keep the public-profile view distinct from private account/settings controls.

## The underlying content model users need to understand

1. Film or series is the common reference. Series can contain seasons and episodes. Rating scopes must be explicit; never mix episode and full-series scores in an unexplained average.
2. Watchlist entry means saved for later. A list groups references to titles; it does not create another title or imply watched status.
3. Viewing means one dated watch. Rewatches are multiple viewings, not duplicate films. Rating alone must not silently imply a viewing.
4. Rating is a score with an owner and scope. Review is written opinion that may be linked to a viewing and score. Prefill an existing rating, never an arbitrary 5. If a historical review score differs from today's rating, label that distinction rather than overwriting history without consent.
5. Review comments stay attached to that review. Community discussions have their own posts and replies. Surface an original review in a community without creating a second comment thread for the same review.
6. Community membership, friendship, following and group membership are different relationships with different visibility consequences.
7. Plan is the coordination object: people, shortlist/selected title, decision state, date/time, responses. Messages and notifications point into the plan; they do not own independent versions of it.
8. Activity is a view of actions on these objects; notifications are attention signals. Neither should become a second source of truth.

These are product distinctions, not a proposal to expose database terminology in the UI or rewrite the schema.

## Information order inside a title
Title and essential facts → viewing availability where reliable → your state (saved, rating, viewing) → friends' opinions → wider reviews/community context → cast and deeper metadata. Actions: Save, Log a watch, Rate, Write a review, Plan together. Show a few primary actions and put secondary actions in a clearly named menu; do not give every action equal visual weight. Keep the user's score, friends' scores, community average and external aggregate separately labelled with sample sizes where applicable.

## Navigation contract
- Bottom tabs retain their own position, filters and navigation history. Repeated entrances to one object should resolve to the same detail behavior.
- Back returns to where the user came from: Home preview, community feed, notification or search. Preserve that origin and scroll position.
- Close exits a multi-step journey to its launch destination. Do not make it another single-step Back when the user is trying to leave the whole journey.
- From a notification, open the exact comment/review/plan, highlight the target and provide a meaningful parent destination when there is no prior stack.
- Keep full discussion reading on a page; reserve sheets for bounded actions such as filter, select, report and join. Respect native back gestures and safe areas.
- Content-type filters and sort controls are different groups. Films/Series is not a peer choice to Latest/Popular.
- Badge counts represent actionable unread events, not all existing items. Avoid repeating the same count across multiple ambiguous controls.
- After a saved mutation, all affected views converge without relaunching. The recent ratings refresh bug is a concrete example of a cross-surface consistency problem.

## Home correction and guardrails
Keep Find tonight's film lower down, as previously requested. Keep Around Flixie. The earlier backlog explicitly records removing the Home watchlist section, so the new saved-film Home rail in the previous mockup is an assistant suggestion that conflicts with that preference; withdraw it from the default proposal pending explicit user approval. Do not expand the Home feed merely to represent every feature. Show contextual summaries with clear destinations and omit empty sections.

## Suggested sequence
1. Canonical destinations and navigation behavior: plans overview, return paths, preserved tab state, notification target handling and consistent save refresh. Medium scope; fewer labels change, highest immediate reliability value. Inspect existing navigation/tests before implementation and preserve old deep links.
2. Social/Profile consolidation: label Messages, reduce Social's peer tabs, move duplicated relationship management out of Profile. Medium scope; validate discovery of Messages and Plans before committing. Keep Groups and Communities distinct.
3. Rebalance Home and title information: compact personalised previews, explicit rating ownership/scope, fewer equally weighted actions. Small-to-medium UI scope; new community preview queries are separate work.

Validate with five tasks: find a saved film; rate it and find the rating; respond to a plan invitation; reply to a community comment and return; find a friend's review. Measure completion, wrong turns and ability to resume—not just preference for a screenshot. No user testing has yet validated these recommendations.

## Implementation update — 29 September 2026
The user subsequently approved implementation. The navigation and consolidation
pass is now implemented locally: retained bottom tabs, Social's four sections and
Messages/Plans entry points, Profile's three sections and library links, legacy
plan route aliases, and Home reorder/Trending compaction. No Home watchlist section
was introduced. The title-detail hierarchy discussion and new personalised data
queries remain future work; this pass preserves existing content semantics.

Focused checks and an isolated iOS navigation test passed. Small-phone Social
checks include double-size system text. Optional removal of legacy Profile loaders
was blocked by automatic approval review, so those remain with analyzer warnings.
Not yet uploaded to TestFlight; no Android device verification in this pass.
