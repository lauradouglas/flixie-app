# Flixie architecture

The app is organized by feature. Keep related code together and make each file's
responsibility clear. Use Provider/ChangeNotifier for observable state and
GoRouter for navigation, following existing code. Add a layer when it owns real
logic, caching or coordination; simple API calls do not need a mandatory chain
of controller, use case, repository interface and implementation.

## Ownership and folder convention

| Location | Responsibility |
|---|---|
| `lib/main.dart` | Bootstrap, dependency wiring and app lifecycle |
| `lib/app/` | App-wide routing and theme |
| `lib/core/` | Infrastructure or UI genuinely shared by features |
| `lib/features/<feature>/data/` | Feature API/storage access |
| `lib/features/<feature>/models/` | Feature-specific data and state types |
| `lib/features/<feature>/presentation/pages/` | Screen composition, navigation and widget lifecycle |
| `lib/features/<feature>/presentation/controllers/` | Observable feature state, async coordination and commands |
| `lib/features/<feature>/presentation/widgets/` | Independently understandable UI sections with explicit inputs/callbacks |
| `lib/features/<feature>/presentation/` | Other cohesive presentation logic, such as selection or sheet flows |
| `lib/models/` | Existing models shared across multiple features |

Use this convention as features are added or cleaned up. Create only the folders
needed by the feature. Existing `domain/` folders hold pure rules such as
Watchlist release/availability matching; a domain layer is optional. Keep pure
logic independent of HTTP and widget state. Avoid whole-repo moves just to make
all existing features identical.

Pages/widgets may import their feature controller and models. Controllers depend
on feature data access, models and shared infrastructure. Data services depend
on API/storage infrastructure and models, not widgets. Shared infrastructure
must not depend on feature screens. Existing shared auth caches are a documented
exception to complete feature ownership, not a pattern to expand.

Use named responsibilities rather than `helpers.dart` or miscellaneous buckets.
Move widgets that have a coherent purpose; small private helpers can stay with
their owning widget. Feature-only types stay in the feature. Promote code to
`core` only when multiple features need the same behavior.

## Watchlist reference

Start with the screen, then follow the responsibility you need to change:

| File, relative to `lib/features/watchlist/` | Owns |
|---|---|
| `presentation/pages/watchlist_screen.dart` | Layout, filter controls, row wiring, navigation and lifecycle subscriptions |
| `presentation/controllers/watchlist_controller.dart` | Library snapshots, loading/error state, session changes, stale-response guards and bounded enrichment scheduling |
| `presentation/watchlist_selection.dart` | Pure search/filter/sort projection and movie/show visibility |
| `presentation/watchlist_action_flow.dart` | Action sheets, confirmation, analytics, persisted-action coordination and success/error feedback |
| `data/watchlist_data_service.dart` | Watchlist API boundary, using existing movie/show/user services |
| `models/watchlist_filters.dart` | Filter choices and independent copies for edits |
| `models/watchlist_show_entry.dart` | Saved-show parsing and metadata enrichment |
| `presentation/widgets/watchlist_movie_row.dart` | A movie/show card and its action callbacks |
| `presentation/widgets/watchlist_movie_search_sheet.dart` | Add-movie search UI |
| `presentation/widgets/watchlist_friends_viewing.dart` | Friend previews and detail sheet content, preserving each user's badges |
| `presentation/widgets/watchlist_providers_inline.dart` | Availability previews and provider detail content |

The controller exposes read-only library/cache collections and copies of filter
choices. Apply edits with `updateFilters`, search with `setSearchQuery`, and list
changes with named commands. It has no BuildContext or widget navigation. The
screen owns text controllers, app-lifecycle/auth subscriptions and the
post-frame scheduler passed into the controller; disposing it cancels future
publication. Sheets and action feedback belong to the action flow/widgets.

The controller uses AuthProvider's current library and shared movie-provider
cache rather than adding a second app-wide cache. Its injected data service
provides a small boundary for tests. The older `WatchlistActionsController` is a
shared action facade used by other features; it is distinct from this screen's
stateful `WatchlistController`. Do not copy the facade as a template for a new
state owner.

### Adding or changing behavior

- **Card appearance:** change the owning widget; preserve responsive reflow and
  badge borders. Add a widget regression for changed interaction/layout.
- **Filtering/order:** change selection/rules and test resulting visible titles,
  including unknown metadata and movie/show ID overlaps.
- **Data loading/paging:** change the controller/data service. Keep batches
  bounded, reject stale account/filter results, and test errors/disposal. Normal
  browsing enriches visible cards in 20-item batches; availability/friends
  filters may need to inspect the whole library through that bounded queue.
- **An action:** put confirmation/feedback in the action flow, persistence in
  the data service and owned-list changes in controller commands. Update shared
  auth state only after persistence succeeds.
- **Native paging:** run the dedicated Patrol journey in addition to focused
  controller/widget regressions. It must not reinstall the daily development app.

New focused tests go under `test/features/watchlist/`; existing Watchlist tests
remain under `test/`, with shared fakes in `test/support/`. Use strict fictional
fixtures, not live accounts. See [testing](testing.md) for commands and limitations.

## Movie Detail section ownership

`movie_detail_screen.dart` now composes the page and owns its tab/expansion state.
`MovieDetailController` owns core data, optional sections, refresh generations,
viewer guards and disposal. It uses the existing `MovieService` and delegates
independent retry/retained-section state to `MovieDetailSectionsController`.

`MovieDetailActionFlow` coordinates watchlist, favourites, lists, watch logs and
reviews through the existing services and sheets. Saves check the captured viewer
and load generation before publishing into controller state. Watch-log persistence
stays in this flow; widgets receive explicit callbacks.

`MovieDetailHero` owns poster palette/contrast state and the header. `MovieFriendsSection`
owns the full friends sheet and its search/tab state, preserving each avatar's
badge border. Providers, photos, trailers and watch history remain separate widgets.
Dormant private dashboard/social/list implementations and an unused rating sheet
were removed. Live rating remains available through the watch-log sheet.

The page is 1,199 lines, down from 3,881 before this batch. This improves navigation
and responsibility boundaries; it does not establish a runtime speedup. See
[performance baselines](performance-baselines.md) for recorded measurements.

## TV Detail ownership

`show_detail_screen.dart` composes the page, tabs, expansion controls and spoiler
preference subscription. `ShowDetailController` owns progressive summary/full
loading, independent section retries, viewer generations, episode progress and
save state. `ShowDetailService` provides injectable access to existing services;
it adds no cache or duplicate API implementation.

`ShowDetailActionFlow` coordinates watchlist, favourites/ranking, rating, reviews,
lists and episode/season saves with Undo. Responses belong to the initiating
account and load generation. A partially saved season only undoes its successful
subset; repeated episode taps cannot start another save.

The hero, streaming providers, friends, episodes, episode sheet and metadata
sections live in `presentation/widgets/show_*`. Provider tabs own their selection.
Friends retain each user's badge border. Episode progress and the next episode
are computed once for the episode list, rather than once per card.

The page is 930 lines, down from 3,382 immediately before this batch. This is a
responsibility change, not a measured speedup. See the
[TV cleanup record](performance/2026-10-07-tv-detail-cleanup.md).

## Home loading and subscriptions

`home_screen.dart` composes the page, navigation/sheets, scroll controllers,
image warming and visible recommendation tracking. `HomeController` owns trending,
recommendations, Continue Watching, watchlist state and per-movie friend signals.
`HomeDataService` provides injectable access to existing services; it adds no cache.
`HomeWatchPlansController` owns direct/group plan loading, visibility, ordering and
reminder synchronisation through the existing watch-request cache.

Each section has its own `HomeSection` listenable. A friend response updates only
its movie card. `HomeHeroCard` contains the existing hero presentation and explicit
action callbacks. `home_session_updates.dart` scopes notification counts and
recovery messages. The page subscribes to account identity; greeting/profile
updates have their own selector. Notification/profile-only updates do not reload
Home. Activity changes and explicit refresh still invalidate the appropriate data.

Generation and account guards reject late responses and saves after account
changes. Failed optional refreshes retain useful data; denied sections clear private
content. Same-account snapshots retain activity versions and incomplete-load state
so remounts revalidate when necessary. The resume profile-read fix remains intact.
The page is 1,555 lines, down from 2,723 immediately before this batch. See the
[Home cleanup record](performance/2026-10-07-home-cleanup.md) for verification.

## Own Profile ownership

`profile_screen.dart` composes the header, totals, tabs, routes and scroll
lifecycle. `ProfileController` owns Library extras, ratings, activity filters and
cursor paging, lazy Stats, account/activity subscriptions and review deletion.
Each request checks its account, load generation and section version. Logout
clears private content immediately; old requests cannot restore it.

`ProfileDataService` is injectable access to existing user/show/person services;
it adds no cache. The unused friends load is removed. `ProfileActionFlow` owns
provider/ratings sheets and delayed Continue Watching dismissal with Undo; it
captures the initiating account/load and copies lists before edits. Provider and
Continue Watching loads publish independently and retain useful data on ordinary
refresh failure. Manual profile refresh suppresses duplicate activity-version
reloads while it performs its own explicit load.

Library, Activity, Stats, viewing insights, favourites and tabs have named
widgets. The notification button selects only unread count; notification-only
updates preserve header/Library widget identities and issue no Profile reads.
Stats remains lazy, joins overlapping requests and reuses loaded data on tab
returns; person enrichment remains bounded to four directors. The page is
213 lines, down from 2,160. Existing imports of ProfileFavouritesLibrary remain
supported through the page's export. Friend Profile now has its own owners below.
See [the Profile cleanup record](performance/2026-10-07-profile-cleanup.md).

## Friend Profile ownership

`friend_profile_screen.dart` composes the cover, toolbar, header, totals, actions,
tabs and routes. It updates the existing controller when the viewed user ID
changes, and disposes its listener with the page. The page is 279 lines, down
from 2,142; the unused legacy layout and its private review-card implementation
were removed.

`FriendProfileController` owns the viewed profile, reviews, activity cursor,
fresh/cached friendship status and rating/favourite compatibility. Results are
scoped to both viewer and subject through load generations and section versions.
Changing viewer/subject clears private state, resets tab/paging state and rejects
old responses. Concurrent load-more taps are suppressed. Notification-only
AuthProvider updates do not fetch again. An unavailable initial profile does not
start its additional sections. Same-account ordinary refresh failures preserve
already-useful data; reviews/activity keep their retry state.

`FriendProfileService` exposes existing UserService/FriendService methods without
an added cache. `FriendProfileActionFlow` owns friendship writes, confirmation,
movie search and watch-invite sheets, capturing its initiating viewer/generation.
Old writes cannot publish to a new person/account; stale removal confirmations
cannot start a write. Open shared-rating/invite sheets replace their content when
their initiating profile scope changes. The existing API remains responsible for
permission filtering.

Header/actions/totals/tabs have named widgets, and `buildFriendProfileContent` returns individual
Overview/Activity/Reviews children to the owning lazy ListView. It does not wrap
a whole tab in an eagerly built Column. `friend_shared_ratings_sheet.dart` owns
the bounded comparison sheet. Current badge borders, public-preview list rules,
the incoming-request Accept/Decline exception, milestone access, creator covers,
favourite galleries and rating agreement remain intact. Controller publications
still rebuild the page; extraction is not a claim of section-level rebuild or
retained-memory improvement. See the
[Friend Profile record](performance/2026-10-07-friend-profile-cleanup.md).

## Existing architecture and remaining work

Watchlist is the reference for this cleanup, not a claim that all features have
already migrated. Group Watch Plan still contains a large screen with mixed
responsibilities. Movie Detail, TV Detail, Person Detail, own/Friend Profile and
Home now have explicit section owners. Several shared action controllers forward
existing services directly. AuthProvider delegates prefetch/polling and account-scoped screen data to named
owners, including session recovery. It keeps account/readiness transitions, auth
operations and screen-facing refresh effects; simplify further only where a clear
ownership boundary exists and relevant regressions protect it.

Shared authenticated screen chrome uses `FlixiePageScaffold`,
`FlixieTitleAppBar` and `FlixieSectionHeader`. Immersive detail layouts can retain
their custom scaffold when justified. Use existing theme tokens and the official
Flixie wordmark/icon.

## Review checks

Check that the state owner and data entry point are obvious, UI widgets receive
explicit inputs/actions, and extraction has not added duplicate caches or altered
request ordering. Protect account isolation, cancellation, retry and save outcomes
with focused tests. Measure before making performance claims. Follow AGENTS.md
for native tests, deployment and compatibility policy; the archived build 70
contract is retired.

## Social ownership

`social_screen.dart` owns tab composition, legacy route IDs, navigation, account
keys and the refresh signal. Activity, People, Groups and Communities mount on
first visit and retain their state while browsing within the same account.
An account change discards both visible and hidden tab state. The message badge
subscribes to the unread total in `SocialMessagesButton`, independently of the page.

| File, relative to `lib/features/social/` | Owns |
|---|---|
| `presentation/controllers/social_people_controller.dart` | Friends loading, stale-read rejection, single-flight request responses and confirmed cache updates |
| `presentation/controllers/social_groups_controller.dart` | Group/invitation snapshot, refresh generations and confirmed creation/invite outcomes |
| `data/social_groups_service.dart` | Groups/notifications projection and four-worker membership enrichment |
| `presentation/widgets/social_people_view.dart` | Directory, pending requests and action feedback |
| `presentation/widgets/social_groups_view.dart` | Group search, navigation, invite actions and create-sheet presentation |
| `presentation/widgets/social_group_controls.dart` | Group search field, invitation summaries and empty states |
| `presentation/widgets/create_group_sheet.dart` | Existing two-step creation form and member selection, bound to its opening account |
| `presentation/widgets/social_activity_view.dart` | First-visit feed mounting, scope retention and feed visibility |
| `presentation/widgets/social_account_sheet.dart` | Close root-navigator feed sheets when their opening account changes |
| `presentation/pages/community_activity_feed.dart` | Community filters/paging/settings, account generations, relationship snapshot and foreground/visible polling |

People loads its own friends rather than prefetching activity and groups. The
Friends feed loads activity when visited. Existing shared auth snapshots remain;
this cleanup adds no global cache or new state-management framework. Membership
workers stop scheduling when their owner becomes stale. Feed timers pause for
hidden scopes, disabled ticker branches and app backgrounding; disposal releases
timers, observers and listeners. Older unused FriendsSubView/GroupsSubView files
and dormant inline friends cards were removed. Use the focused Social tests and
opt-in `social` simulator scenario described in the performance ledger.

## Watch Requests ownership

`social/presentation/pages/watch_requests_screen.dart` composes Watch Plans.
Its public detail-route type is re-exported from `watch_request_detail_screen.dart`,
which owns notification-to-group resolution. The controller holds one viewer/route
snapshot, filters, drafts and busy state; `data/watch_requests_service.dart` owns
direct/state/visibility reads and a four-worker group-count projection.

The `presentation/watch_requests/` flows own creation/responses, scheduling,
completion and movie choices separately. They capture their initiating controller
and page context, guard follow-up work, and keep sheets bound to that account.
Widgets under `presentation/widgets/watch_requests/` own list sections, controls
and the bounded calendar prompt. Existing FriendWatchPlanFlow and the separate
GroupWatchPlanV2Screen retain their responsibilities. Account/request changes reset
the page scope; listener disposal and microtask refresh coalescing stay in the page.
See the [cleanup record](performance/2026-10-07-watch-requests-cleanup.md) for
validation and runtime limits.

## Movie List Detail ownership

`movie_list_detail_screen.dart` is the 348-line composition entry point. The list
scope is keyed by viewer, owner and list ID; changing accounts or routes disposes
its provider, metadata controller and action context. Notification-only profile
updates do not change that scope. The page owns sort/contributor choices and wires
individual cards into the existing lazy sliver grid.

| File, relative to `lib/features/movies/` | Owns |
|---|---|
| `presentation/controllers/movie_list_detail_controller.dart` | Membership, optional owner metadata, refresh generations, account/disposal guards and denied-access state |
| `data/movie_list_detail_service.dart` | Injectable metadata reads through existing UserService; no new cache |
| `presentation/controllers/movie_lists_controller.dart` | Existing item snapshots and writes; list-read versions now reject responses predating a confirmed edit and suppress publication after disposal |
| `presentation/movie_list_detail_actions.dart` | Confirmation, navigation, member reads/writes, account-bound root sheets, duplicate-action guards and feedback |
| `presentation/movie_list_selection.dart` | Nonmutating ordering, contributor/poster projections and list metadata formatting |
| `presentation/widgets/movie_list_detail/` | Header, members, controls, poster cards, empty state, friend picker and movie/show search picker |

API membership remains authoritative over route permission hints. Denied access
removes private page content and edit controls; ordinary refresh failure retains
useful metadata. Late owner/search responses cannot replace newer state. Member
writes dismiss their own root sheet rather than the list route. Movie/show IDs
remain independent, and the title picker stays open for multiple additions.

Poster metadata and controls wrap; grid column count adapts to width and text
size. Each user's badges remain in owner, member and contributor avatars. This
screen still fetches the full item collection: lazy card construction is not API
paging. See the [cleanup record](performance/2026-10-07-movie-list-detail-cleanup.md)
for populated simulator observations and validation.

## Account cache ownership

`lib/core/auth/auth_account_cache.dart` is owned by one AuthProvider instance.
It holds screen snapshots, notification dismissals/unread count, friend identity
versions and region-scoped movie streaming availability/preferences. Its `clear`
operation releases all account data and invalidates pending provider callbacks.
Friend versions remain monotonic so existing screen invalidation contracts hold.

AuthProvider keeps its public cache getters and update methods as the screen-facing
facade. It owns Firebase/profile/session readiness, account transitions, notifications,
badge/platform effects and listener delivery. Its session recovery owner implements
retry and refresh orchestration. It clears the account owner before
account transitions and on disposal. An account switch also resets the cached unread
count; badges still use the existing app-owned sync path.

AuthPrefetchCoordinator retains the existing API implementation and warming budget.
The cache owns on-demand streaming-provider single-flight state, checks its reset
generation and region alongside AuthProvider's session guard, and rejects queued
old-account requests after a reset. It adds no global cache, state-management layer
or eager provider fetch. Watchlist keeps its visible-page loading and active-title
pruning; partial refreshes preserve already loaded sections and notification
suppressions.

## Session recovery ownership

`lib/core/auth/auth_session_recovery.dart` is per AuthProvider, with no separate
notifier or global session state. It owns the bootstrap timeout, recovery error,
three scheduled retries (5/15/30 seconds), foreground retry cancellation, token
and profile timeouts, shared profile/resume requests and the two-minute resume
throttle. Reset invalidates old account work and clears pending references;
completion checks identity so old requests cannot release new requests. Disposal
cancels timers and rejects pending results. Underlying SDK/HTTP work is bounded
and its late results ignored; it is not forcibly cancelled.

AuthProvider supplies the current Firebase user, profile loader and explicit
callbacks. The facade retains initial profile/terms/social-signup readiness,
authentication status, account/cache resets, routing notifications and all public
methods. Recovery applies profile results through the facade; a successful resume
increments activity with its refreshed-profile marker, invalidates friends activity,
and restarts the existing notification poller. Home consumes that marker to avoid
a duplicate profile read. A throttled resume only restarts polling.

Temporary failures preserve saved content and use the existing retry UI/schedule.
The same four invalid Firebase session codes terminate the local session through
the facade. Valid tokens are reused; a newer API 401 token refresh cannot be
replaced by an older SDK result. Recovery never starts broad prefetch on resume.
See [the recovery record](performance/2026-10-07-session-recovery.md).


## Person Detail ownership

The 216-line page composes the route, owns its auth subscription and controller
lifecycle, records opens and navigates to movies, shows and photo routes.

| File, relative to `lib/features/movies/` | Owns |
|---|---|
| `data/person_detail_service.dart` | Existing parallel detail/credits reads, images and favourite persistence |
| `presentation/controllers/person_detail_controller.dart` | Route loading/retry, late-result guards, retained merged credits, viewer library sets and favourite busy/account guards |
| `presentation/person_filmography_selection.dart` | Pure typed credit merge, role/media/year/search/personal filters and sorting |
| `presentation/person_detail_action_flow.dart` | Persisted favourite feedback/latest-list update, external links and bounded root-navigator credit sheet |
| `presentation/widgets/person_detail/` | Hero, biography, photos/grid/viewer, stats, known-for cards, filmography controls and credit rows |

Public detail data survives account changes without refetching. Personal library
sets change with the current User snapshot; personal filters reset on viewer
change. A pending old-account favourite cannot publish into the next account,
and an open credits sheet hides its personal rows when its viewer changes.
Successful favourite writes apply to the latest shared list, preserving unrelated
edits. The page disposes its auth listener and owner; biography/search/photo
controllers stay with their named widgets. No new app-wide cache or state package
is introduced. Controller publications still rebuild the page; the measured
before/after record, rather than extraction alone, determines runtime conclusions.
See [the Person Detail record](performance/2026-10-08-person-detail-cleanup.md).


## Group Watch Plan ownership

The shared 241-line V2 page composes standalone/embedded routes, subscribes to auth
and the two refresh signals, and publishes count/backdrop changes. Its route-owned
`GroupWatchPlanController` keeps plans, per-plan members/names, selected plan and
vote drafts. Same-turn refresh notifications coalesce; newer reads may supersede
stalled ones. Account/route epochs and load generations reject stale publication.
A write invalidates pre-write reads and refreshes without waiting for them.

`GroupWatchPlanService` exposes existing group/plan/member reads and reminder
cancellation. `GroupPlanViewData` in `group_watch_plan_selection.dart` projects
pure stage/membership rules. `GroupWatchPlanActions` owns account-bound root sheets
and persisted-action feedback. Named `group_plan_*` widgets own the collection,
cards, invitation, voting, proposals, scheduled details, member progress and header.
The existing recap/schedule/shared-poster components remain in use.

No additional cache or state framework is introduced. Each request retains its
own group's accepted members and each user's badge border. Account switches clear
private data and remove old-account sheets. Draft picks are pruned when their
plan/candidate disappears. See [the cleanup record](performance/2026-10-08-group-watch-plan-cleanup.md)
for populated measurements and validation limits.

## Watch Request composer ownership

`features/movies/presentation/widgets/watch_request_sheet.dart` retains the public
`MovieWatchRequestSheet` entry point and composes the invitation sections. The
238-line sheet owns its message input, account binding and controller disposal.
`WatchComposerController` owns recipient collections, movie choices, the schedule
and one-shot submission state. `WatchComposerProviders` shares provider reads only
within that sheet/account/region, rejects superseded recipient responses and
clears its maps when the sheet closes. Membership reads remain fresh per selection;
failed provider reads are evicted for retry.

`WatchComposerService` exposes the existing friends/groups/provider/search/send
operations. `WatchComposerActions` owns root/safe/bounded sheets, navigation and
feedback, with account guards before callbacks. Confirmed sends cannot be retried
because analytics failed. Named `watch_composer/` widgets own recipients, movie
choices, location/provider matching, scheduling controls and submission UI. Avatar
badges are preserved. No new app-wide cache or state framework is introduced.
See [the composer record](performance/2026-10-08-watch-composer-cleanup.md).

## Group Insights ownership

`features/social/presentation/widgets/insights_tab.dart` composes the tab and binds
its group and account to `GroupInsightsController`. The controller owns the period,
loading/error state, overlapping-read sharing, stale-result guards and disposal.
It calls the existing `GroupService.getGroupInsights` through an injectable function;
there is no added repository/service wrapper or persistent cache. The shared API
client already coalesces identical HTTP reads.

Live content, period controls, loading placeholders, pulse metrics, highlight,
review, member and watcher widgets live in `widgets/group_insights/`. Unused signal,
genre-cloud, movie-rail and variant-card implementations were removed after checking
callers. Review identity/content changes reset spoiler disclosure. Empty/error
states keep period selection accessible. Account changes clear private state and
reset the period; unrelated account notifications do not reload.

Keep rating eligibility in the existing `MovieRatingPrivacy` owner and each user's
avatar border in `ProfileAvatarView`. Watcher mappings preserve optional avatar and
badge fields, including legacy URL rendering; reviewer/contributor fields retain
their existing API mapping. The tab is 61 lines (previously 1,489); its 11 owning
files total 1,077 lines, largest 234. See the
[cleanup measurements](performance/2026-10-09-group-insights-cleanup.md).

## Search ownership

`features/movies/presentation/pages/search_screen.dart` owns composition, focus and
navigation. `SearchScreenController` owns the query/mode, 400 ms debounce, loading,
paging and retry state for one mounted screen. Query/mode changes and disposal
invalidate older completions; identical pending work shares its future. Refresh
supersedes old pagination, and failed refresh retries page one while retaining
visible results. Existing SearchService and TrendingService remain the data API;
there is no additional catalogue cache or repository layer.

`data/search_history_store.dart` owns the existing five-entry device-local history
key and serialises writes. It is deliberately not account-owned data. The
`presentation/widgets/search/` folder contains query/mode controls, default content,
results and movie/show/person/collection tiles. Each content view passes its scroll
view directly to FlixieRefresh so native iOS refresh keeps a single scroll owner.
The notifications button selects only its unread count; account notifications do
not rebuild the Search body. Rating privacy stays with MovieRatingPrivacy.

See the [Search cleanup record](performance/2026-10-09-search-cleanup.md) for the
final validation and populated runtime comparison.


## Onboarding ownership

The six-step setup flow keeps its existing `SetupService` data boundary.
`authentication/presentation/pages/onboarding_screen.dart` composes the steps and
owns account binding, text/scroll controllers, country/import sheets, completion
routing and analytics. Its controller is replaced when the account changes;
async page callbacks retain their original owner and cannot finish a new account.

`presentation/controllers/onboarding_controller.dart` owns private selections,
setup loading/errors, 350 ms title debounce, stale-result generations, picks and
bounded availability batches, save/add coordination and partial community joins.
Views receive read-only selection collections and invoke named commands. Public
favourites remain in the existing `SetupProfileFavourites` component; private taste
never publishes them implicitly. No extra repository/cache layer was added.

`presentation/widgets/onboarding/` has focused taste, services, picks, preferences
and communities widgets, plus the frame and footer. Change the relevant step's
presentation there; change asynchronous ownership in the controller; change routes,
sheets and app-wide completion effects in the page. Preserve the six-step order,
explicit sharing/join consent, saved-choice retries and invitation destination.

Focused regressions are in `test/features/authentication/` alongside the existing
`test/setup_*` suites. Native setup, favourites-consent and community/resume journeys
remain under `patrol_test/`. See the [dated cleanup report](performance/2026-10-09-onboarding-cleanup.md)
for the populated-catalogue benchmark boundaries and results.

## Notification inbox ownership

`features/profile/presentation/pages/notification_screen.dart` owns inbox loading,
polling, filtering and action coordination. Its rendered card is
`widgets/notification_inbox_card.dart`, including the inbox visibility/headline
rules. `core/utils/notification_destination.dart` owns destination selection;
`core/utils/notification_profile_badges.dart` resolves each sender's badge data.
Keep changes anchored to these live owners and their focused navigation tests.

The unreferenced legacy `notification_request_card.dart` was removed on 9 October
2026. Do not recreate its separate schedule/action rules: actual Watch Plan
responses belong to the current plan destinations. The evidence and original
source are retained in `docs/performance/2026-10-09-notification-cleanup.md`.

## Settings ownership

`features/settings/presentation/pages/settings_screen.dart` composes settings
sections and navigation. It selects only displayed authentication values rather
than subscribing to every AuthProvider change. `widgets/settings_edit_profile_sheet.dart`
owns the editing session and its save feedback; the public
`showSettingsEditDetailsSheet` entrypoint remains exported from the page for
existing callers. `controllers/settings_username_check.dart` owns cancellable
username validation and stale-response protection. The existing
`SettingsController` remains the API facade.

Country selection, blocked-user management and the episode-spoiler preference
live in `settings_country_picker_sheet.dart`, `blocked_users_sheet.dart` and
`episode_spoiler_setting.dart`. Country reference data is loaded once per editor
opening (retry on failure); no new global cache is introduced. Profile writes
stop before subsequent fields and cache publication when the account changes.

## Movie Lists overview and editor

`features/movies/presentation/pages/movie_lists_screen.dart` owns overview filters,
sort/search and route/menu wiring. Its list provider is keyed to the selected
account ID; existing `MovieListsProvider` retains collection/cache/API ownership.
`widgets/movie_lists/movie_list_grid_card.dart` owns previews and each
collaborator's badge avatar. `movie_list_editor.dart` owns the editor session,
submission feedback and created-list navigation; `list_collaborator_picker.dart`
owns relationship selection/search; `list_editor_layout.dart` keeps actions
reachable while the body scrolls.

`controllers/list_editor_relationships.dart` loads friends/groups only when that
scope is chosen, coalesces overlapping reads and reuses successful results for
that editor session. Errors are retryable, not disguised as empty relationships.
It introduces no global cache. Late responses after disposal/account change are
ignored. The editor stops follow-up member writes/navigation on account changes,
disables repeated save while saving and retains failed drafts for retry.

## Community Discussion ownership

`features/social/presentation/pages/community_discussion_screen.dart` owns route
composition, draft/actions, membership confirmation, moderation and focused-reply
scroll/highlight behaviour. `controllers/community_discussion_controller.dart`
owns thread/membership reads, reply paging and request generations. It exposes a
read-only reply-list view, coalesces overlapping first-page reads, and rejects
stale membership/paging responses. Writes explicitly request a fresh reply page.

`widgets/discussion/` contains the standalone discussion composer, author/menu
row, reply display and reply input. The page exports `CommunityDiscussionComposer`
to preserve existing imports. Author widgets retain each user's badge data.
Focus uses a loaded reply before fetching it separately, waits for layout when
needed, and ignores old results after refresh/moderation. No new global cache.
Thread and reply loading indicators are independent; spoiler-hidden discussions
still do not fetch replies until explicitly revealed.

## Pick for Us ownership

`features/pick_for_us/pick_for_us_screen.dart` owns the flow and recommendation/
Watch Plan actions. `data/pick_for_us_service.dart` retains the API contract, with
response types in `models/`. `controllers/pick_people_controller.dart` loads only
the selected viewer type, reuses successful results for this flow and isolates
retry errors. Disposed flows ignore late responses; account/service replacement
resets the flow. `widgets/` owns the viewer search/rows and result card. The screen
exports service/models for existing imports. There is no global relationship cache.

## Add to List ownership

`widgets/add_to_list_sheet.dart` and `widgets/add_show_to_list_sheet.dart` are
compatibility entry points for the shared `add_to_list/media_list_picker.dart`,
which owns selection, membership loading, partial saves and undo. Creation lives in
`widgets/add_to_list/create_media_list_sheet.dart` and reuses
`ListEditorRelationships` for lazy collaborator reads, retries and lifecycle guards.
Personal creation makes no relationship request. Picker state resets on account or
movie replacement. Movie and TV membership now use the ID-only batch endpoint for their media type.

## Batch movie-list membership

`UserService.getMyListsContainingMovie` fetches matching IDs from the authenticated
`/users/:userId/lists/containing/movie/:movieId` endpoint, then intersects those IDs
with list metadata. It never downloads each list's contents or caches membership.
The backend reuses the signed-in overview visibility predicate and selects IDs only.
`MovieListsProvider` propagates membership errors; Add to List shows retry/cancel
rather than presenting failed reads as empty selection. Backend-first rollout is
required. See [the benchmark report](performance/2026-10-09-list-membership-batch.md).

## List overview and Friend Watch Plan

The overview repository returns at most four poster items per visible list and
gets movie/show/item counts through one grouped aggregate. Counts do not depend on
the poster limit. Collaborator and group-member badge data remains in metadata.

Friend Watch Plan keeps stage selection, local review state, compact/header UI and
callback wiring in `friend_watch_plan_flow.dart`. Choices, recap and invitation/
scheduling/attendance have separate widgets; button styling and text styles are
shared. No new cache, subscription or state-management layer was introduced.

### Group Chat and shared reviews

`GroupChatTab` owns composer state and watch-request actions. Its
`GroupChatSession` owns initialization for one account/group and retains the
message stream across rebuilds. Rebinding clears data and invalidates late async
results; repeated notifications for the same owner do not start another load.
`GroupChatService` is the small injectable data boundary, with no shared cache.
`group_chat/group_chat_messages.dart` renders the conversation and routes cards;
`group_chat_request_sheet.dart` owns the fallback detail/reply composer and
its disposal. The 50-message Firestore limit and existing read observer remain.

The public `review_card.dart` entry point retains the card and exports the existing
sheet API. `review/review_detail_sheet.dart` owns expanded content, safety/delete
and optimistic reactions. `review/review_reactions.dart` owns reaction presentation
and chip animation. Safety caching and reaction persistence keep their existing
owners; this is a structural extraction, not a new caching layer.

### Notification inbox lifecycle

`notification_screen.dart` owns app/route visibility and auth subscriptions,
refresh composition, navigation and feedback. `NotificationInboxController` owns
account-scoped loading, its visible-only polling timer, request coalescing,
dismissal/read state and mutation-generation guards. The page publishes its
results to the existing AuthProvider cache only for the current account.
`notification_inbox_actions.dart` coordinates invitation responses and preserves
success when secondary sync fails. `widgets/notification_inbox/` contains the
inbox/filter view and bounded options sheet. Existing NotificationService and
notification destination/visibility/badge helpers remain the shared data rules.

Group Members: `GroupMembersScreen` keys its page by account/group. Its
`GroupMembersController` owns coalesced loading and cached sorted selection;
`widgets/group_members/` owns the member tile, role menu and invitation sheet.
Mutation follow-ups and invitation completion must verify the original page owner.

Media sharing: `MediaChatShare` coordinates the destination chooser and composer.
`MediaShareSession` binds a flow to its originating account, uses existing nullable
recipient caches and checks ownership between send preparation steps. The friend
and group composers under `features/sharing/presentation/widgets/` own their text
controllers. `models/chat_share_media.dart` owns the shared movie/TV wire payload;
its model remains exported from the original entry point.

## Watch logging and watch-together plans

`movies/presentation/widgets/rewatch_log_sheet.dart` owns the account-bound editor draft, responsive full-height phone/bounded tablet layout and persistent Save footer. `showMovieWatchLogSheet` is the common presentation entry point; caller action flows retain API writes and cache publication. `watch_companion_picker.dart` reuses `FriendSearchScope`/`StarredPeople` for private favourite-first search and preserves every selected user's badges. `models/watch_log_details.dart` carries the additional editor fields to its owning flow. Movie Detail, Watchlist, History and direct-plan completion share the editor.

Direct single-title plans use the additive `lightweight` flag and exist without an acceptance/date step; multi-title and group planning keep their existing agreement flows. Retrospective companion logs and standalone/edited movie logs use `/watch-requests/log-watch`, with a stable draft ID and a transaction for the actor's watch, rating, spoiler-aware review and optional shared-plan link. Notification log routes point to the precise plan/person viewing, never an unrelated watch of the same film. Backend migration must precede client rollout.

External companions use `movies/models/external_watch_invite.dart`, `data/external_watch_invite_service.dart`, the shared companion picker, and the post-save `external_watch_invite_sheet.dart`. Backend `ExternalWatchInvite` links to the actor’s permanent viewing; it does not model a fake user. Only an authenticated owner can retrieve its sharing token. Recipient preview/claim routes return limited film/date/inviter context, and claiming atomically reserves a single recipient and creates the direct-plan link without creating their watch. `ExternalWatchInviteScreen` then hands off to existing plan completion. `PendingWatchInviteStore` retains the token across account setup/restarts; `/invite?watch=…` reuses the installed app’s existing universal-link path and `/watch-invites/:token` is an internal setup destination. App-store deferred-link attribution is not provided; share copy tells new installs to reopen the link.

Invite-first onboarding: `/guest/watch-invites/:token` is an anonymous read-only preview of the explicitly shared film and inviter; it is not a watch-history endpoint. `WatchInviteSignupContext` keeps that context alongside the established signup form. `PendingWatchInviteStore` retains the explicit Rate now intent, then binds the claimed request ID to the actor account. Required auth/profile creation and current terms still precede claim. The router permits only the invite, its exact viewing and its saved confirmation before optional onboarding; it never marks setup complete. `WatchInviteSavedScreen` hands back to ordinary onboarding afterwards. Other app destinations keep their existing setup guard.


Multi-companion retrospective logs now use one direct Request with explicit
`WatchRequestParticipant` membership, independently of permanent Groups. Single
companion logs retain their existing direct identity; adding another person upgrades
that same viewing. List/state reads include member profiles and badges. Completion
serializes responses per Request and waits for every participant's own response.
`WatchRequest.viewingPeople`/`viewingPersonIds` unify direct and ad hoc membership
for recap, Home and watch-history projection. Existing separately linked historical
requests are preserved; no automatic historical merge or permanent group creation.


## Signed-out Home discovery

`features/guest/presentation/guest_home_screen.dart` owns existing guest feed loading, refresh, title/signup/search routes and section order. `guest_home_welcome.dart` owns the compact hoodie Pip introduction; `guest_signup_section.dart` owns the lower account-benefit explanation and existing account actions. `guest_trending_carousel.dart` owns guest catalogue presentation and complete-image poster slots, using existing MovieShort metadata only. Both trending and regional cinema releases use this presentation; InCinemasSection accepts an optional media builder while preserving its existing loading/region/retry behavior and signed-in renderer.

Keep guest posters and Pip fitted with BoxFit.contain. A reserved poster slot does not change the source aspect ratio or crop the image; do not stretch a portrait poster into a wide hero. Narrow/large-text featured titles stack, and meaningful titles wrap. Guest Home retains the existing public community projection and badge pipeline; no personalised recommendations or invented mood collections are implied.

Cinema list presentation is owned by Home at `features/home/presentation/widgets/cinema_list.dart` and shared by signed-in and guest Home. It consumes the existing InCinemasSection region feed and caller-owned action callbacks, saved IDs and pending IDs. It shows optional source-labelled TMDB scores, contains complete posters and provides a three-item preview with expansion. The guest alias preserves existing imports; no friends data is loaded for this list.

Initial signed-in Home reveal is owned by HomeStartupGate. It covers shell navigation while Home starts its existing independent requests, releasing when plans/trending are usable and bounded image warming settles, or after six seconds. It never reopens for background refresh, ignores inactive Home branches and keeps normal error/retry UI reachable. Auth SplashScreen still owns session recovery; no catalogue requests were moved into router/auth. Native launch assets are rendered from the actual reduced-motion first pose with `tool/render_startup_brand_test.dart`; iOS uses PipLaunchBrand to avoid stale LaunchImage identity.


Startup account data: AuthProvider loads an opt-in compact identity response before Home. The existing full-profile loader remains the source for library hydration and explicit profile refreshes. User.hasLibrarySnapshot distinguishes omitted collections from real empty collections. HomeController waits for initial Home reveal before coalesced hydration; LibraryReadinessGate protects collection-dependent routes from mounting with incomplete data. Session generations and collection revisions prevent late hydration overwriting another account or a newer edit. Released clients retain the full-profile endpoint default.


### Own-profile weekly film diary

`ProfileDiaryScreen` is a private, independently loaded profile route at `/profile/diary`. `ProfileDiaryController` owns the current account, request generation, loading/retry and watch index. `ProfileDataService.movieWatches` uses the existing own-watch endpoint only after the diary opens. This route consumes no library collections, so it bypasses the collection-readiness gate while retaining ordinary authentication/onboarding routing. `diary_selection.dart` owns local calendar grouping, same-day rewatches and undated separation; UTC calendar-day arithmetic keeps week jumps stable across DST. The calendar and watch-entry widgets own presentation, bounded root sheets and existing title/profile links. Controllers reject stale account loads and sheets observe cleared selection on logout. Group attendees are read-only diary context (`groupCompanions`) rather than direct-plan companion edit selections. No public diary contract, TV logging change or startup fetch is added.


Release awareness: `features/movies/domain/release_status.dart` owns validated calendar-date/status rules shared by film and TV detail heroes. `unreleased_status_label.dart` renders the visible state; `unreleased_movie_prompt.dart` owns the root, safe-area confirmation. `showMovieWatchLogSheet` accepts movie identity and optional release metadata and checks new logs before mounting the editor, loading cached metadata for compact payloads; existing edits bypass this new-log prompt. Callers still own persistence and account validity. Whole-show status uses first-air date, separately from episode-level Continue Watching filtering.


## Optional taste setup

`features/taste` owns the post-action Build your taste flow. `TasteService`
uses existing film favourite/rating APIs and recommendation cache invalidation;
`TasteSetupStore` keeps account-scoped device dismissal/progress and activation
notifications. `TasteController` owns search generations, save state and viewer
guards. The page reuses the signup poster grid and existing rating editor. Home
hosts an invitation only after a saved action/library evidence; Profile always
links back. Signup and title action flows only mark eligibility after successful
activity; taste setup never intercepts or delays the original action.


### Pip collection

`features/pip` owns collection API access, account-scoped cached state, refresh on activity/resume, and the shared My Pip sheet. The navigation shell, Settings, diary and shared-watch success screen consume its widgets. Auth changes reset collection state synchronously and reject late responses. Backend entitlements are authoritative; cached data only preserves the last look. `core/app_icon/AppIconService` serialises native changes, combines founder and Cinema Club eligibility, and reports success only after the native callback. See docs/pip-collection.md.

## Referral visibility

`features/referrals/data/referral_prompt_store.dart` owns the account/device frequency cap. `presentation/saved_film_invite_prompt.dart` coordinates an optional post-save companion action through the existing movie-watch API and sharing sheet; `social_invite_empty_state.dart` supplies the Social entry point. It does not duplicate referral award logic. Signup availability drafts live with `OnboardingController` and persist after country/providers; the existing settings/availability services remain the API owners. `core/widgets/preference_switch.dart` represents unknown state without asserting a false saved choice.

Resume refresh presentation: automatic token/profile failures keep saved content
and allow the existing 5/15/30-second recovery attempts to finish quietly. The
persistent saved-content retry status appears only after that sequence fails in
the foreground. Explicit profile refresh, bootstrap and expired-session handling
retain their existing feedback. This does not classify every backend/SDK failure
as a user connectivity problem.

## Tablet Home composition

`features/home/presentation/widgets/home_tablet_layout.dart` owns signed-in
Home's continuous discovery/companion columns. It uses available width (900+
logical pixels), a 600+ shortest-side viewport and text scaling up to 1.4 to
activate the tablet composition; narrow windows and larger text keep the existing
single-column order. Its feature-local inherited scope selects compact trending,
recommendation and cinema treatments without changing shared phone or guest UI.
All sections share Home's existing vertical scroll and refresh lifecycle.
`home_community_preview.dart` is a spoiler-safe projection of existing public
activity, preserving per-user avatar badges and rating privacy. It navigates to
existing posts/profiles rather than duplicating reaction, moderation or discussion
state. Responsive and action regressions live under `test/features/home/`.

Tablet Home refinement: Home owns its 16px outer gutters directly rather than
stacking the shared adaptive-page gutters. Wide Home uses a 65/35 split, a unified
trending feature/poster surface and a single highest-priority watch-plan preview;
See all opens the existing plans screen. Companion sections and poster/card sizes
adapt within the feature-local tablet scope; phone and other page gutters retain
their existing layout.


## Collectible milestone badges

Profile owns `models/milestone_badge.dart`, `data/milestone_badge_service.dart` and the badge picker/display widgets. `ProfileMilestoneBadges` binds requests to viewer/subject generations, refreshes own-profile awards after activity changes and persists at most three ordered selections through the badge endpoint. It is separate from role badges and avatar borders. Guest Home reuses `BadgesExplainer` with labelled synthetic examples. The backend derives film eligibility from the existing lifetime milestone rules, persists awards independently of later diary edits and enforces earned-only selection, owner writes and existing milestone visibility. See `scripts/seed-dev-milestone-badges.ts` in the backend for guarded local display fixtures.


Guest community discovery: `features/guest/presentation/widgets/guest_communities_section.dart` owns the genre preview, responsive tile rows and bounded browse-all choice sheet. Guest Home still owns the existing community request/retry and join/signup intent. The widget receives catalogue records and a selection callback, uses shared visibility/icon/palette rules and derives the count from the available catalogue. It introduces no new API, membership write, cache or account state.


Guest watch-together education is owned by `features/guest/presentation/widgets/guest_watch_together_teaser.dart`: a labelled fictional plan, bundled poster, individually badged avatar examples and a bounded explanatory prompt sheet. It performs no API reads, membership writes or live invitations. Guest Home only composes the widget.


Around Flixie page entry uses the existing `_pushPage` route policy (instant iOS entry with interactive back). Like its previous direct builder, it does not wait on private library hydration: the feed reads only `/guest/community/activity`. Full feed rows are created by ListView.builder; the embedded preview remains bounded to three. Pagination, retry, public visibility and each activity owner’s profile badges retain their existing pipeline.
