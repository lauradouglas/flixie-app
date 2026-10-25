# Flixie analytics

`AnalyticsController` is the single entry point for product analytics. Feature
code must not call `FirebaseAnalytics` directly. Event names are
`lowercase_snake_case`, describe a completed product action, and are emitted
only after the corresponding mutation succeeds.

Analytics respects the existing explicit consent choice. Failures are swallowed
so analytics can never interrupt the product. Debug builds print concise
`[Analytics]` lines.

## Privacy and parameters

Never send names, usernames, email addresses, referral codes, user IDs, group
names, message/review text, participant IDs, Watch Plan IDs, or catalogue/person
IDs. Catalogue IDs could reveal the specific titles a user viewed or watched.
The central dispatcher strips them even when a caller supplies them. Other
parameters are filtered by the allowlist; unknown sources become `unknown`.

Canonical content types are `movie` and `show`. Detail-open sources are defined
once by `DetailSource`: `search`, `trending`, `just_for_you`,
`friends_watching`, `friend_activity`, `watchlist`, `watch_history`, `list`,
`group`, `watch_plan`, `person_credits`, `shared_link`, `notification`, and
`unknown`. Other events retain their existing controlled sources where needed.

## Event contract

| Event | Successful trigger | Parameters |
|---|---|---|
| `signup_started` | Signup submission begins | none |
| `signup_completed` | Account creation succeeds | none |
| `taste_signal_added` | Onboarding taste choice is added | `signal_type` |
| `taste_profile_completed` | Taste onboarding succeeds | `signal_count` |
| `content_opened` | Movie/show detail data opens | `content_type`, optional `genre`, `source` |
| `person_opened` | Person detail data opens | `source`, optional `parent_content_type` |
| `watchlist_added` | Watchlist add succeeds | `content_type`, `source` |
| `watch_logged` | A new watch entry succeeds | `content_type`, `source`, optional watch-plan attribution |
| `rating_added` | Rating save succeeds | `content_type`, `source`, optional recommendation attribution |
| `review_created` | Review creation succeeds | `content_type`, `source` |
| `recommendation_given` | A recommendation is successfully sent | `content_type`, `source` |
| `recommendation_impression` | A recommendation card is actually presented | recommendation attribution fields below |
| `recommendation_opened` | Presented recommendation opens | same recommendation parameters |
| `recommendation_saved` | Presented recommendation is saved | same recommendation parameters |
| `recommendation_watched` | A watch is logged from a recommendation | same recommendation parameters |
| `friend_invite_sent` | Referral/friend invite share starts | `invite_method`, `source` |
| `friend_invite_opened` | Referral link reaches signup | `invite_method`, `source` |
| `friend_invite_converted` | Referred user qualifies | `invite_method`, `source` |
| `friend_connected` | Friendship succeeds | `source` |
| `group_created` | Group creation succeeds | `group_type`, `source` |
| `group_joined` | Group invite acceptance succeeds | `group_type`, `source` |
| `group_message_sent` | Group message send succeeds | `group_type`, `source` |
| `watch_plan_created` | Watch request creation succeeds | watch-plan dimensions below |
| `watch_plan_accepted` | A participant successfully accepts | watch-plan dimensions below |
| `watch_plan_scheduled` | A date is successfully agreed/saved | watch-plan dimensions below |
| `watch_plan_completed` | The backend transitions the whole plan to completed | watch-plan dimensions below |
| `share_created` | Generated share image reaches platform sheet | `share_type`, optional media fields, `source` |
| `shared_link_opened` | An attributed shared link opens | `share_type`, optional media fields, `source` |
| `shared_link_signup` | Signup from an attributed link succeeds | `share_type`, `source` |

Recommendation impressions are deduplicated by source, algorithm, version,
content and position. Detail opens and consecutive screen views are also guarded
against rebuild duplicates. The Recommendations area is part of Home, so it is
measured as a recommendation funnel rather than a fake navigation screen.

## Personalised recommendation funnel

The funnel is `recommendation_impression` → `recommendation_opened` →
`recommendation_saved` → `recommendation_watched` → `rating_added`. Every
recommendation event uses the same fields:

- `content_type`
- `recommendation_source` (`just_for_you`)
- `position`
- `recommendation_algorithm`
- `recommendation_version`
- optional `recommendation_reason`
- optional `predicted_score`

The current primary algorithm is `weighted_taste_profile`, version `v1`. That
name reflects the backend's weighted taste-profile scorer. Legacy responses are
identified as `legacy_tmdb_similarity` or `popular_fallback`; all current
implementations use the centrally defined baseline version `v1`.

`recommendation_reason` comes only from backend machine-readable `sourceTypes`:
`taste_profile`, `rewatch`, `popular_exploration`, `legacy_tmdb_similarity`, or
`popular_fallback`. Human-facing explanation strings are never sent to
Firebase. `predicted_score` uses the backend's existing recommendation `score`
and is omitted when the backend does not provide one.

Attribution is carried in the movie-detail route, so watchlist, watch and rating
actions during that detail journey retain the original recommendation context.
Quick watch/rating actions directly on Just For You retain it as well. It is not
persisted across sessions: reopening a saved movie later from Watchlist is a
Watchlist journey because the current API/schema does not store recommendation
provenance with the saved item.

## Watch-plan funnel

The funnel is `watch_plan_created` → `watch_plan_accepted` →
`watch_plan_scheduled` → `watch_plan_completed` → `watch_logged`.
Watch-plan events include `content_type`,
`plan_type`, `participant_count`, and `source` whenever the successful API
response provides them. The opaque plan UUID is safe for funnel correlation;
participant user IDs are never sent.

- `plan_type` is `friend` for a direct one-to-one request and `group` for a
  group/conversation request.
- `participant_count` is the total intended audience including the creator.
  Direct plans therefore have 2 participants. Group plans use the creator plus
  every invitee response row, including people who have not responded yet.
- `source` describes the action surface. Creation normally uses
  `movie_detail` (or `recommendations` for the movie-match shortcut), direct
  notification actions use `notification`, and lifecycle actions use
  `watch_plan` or `group`.

Acceptance, scheduling, and completion events are emitted only from successful
mutations, never while loading existing state. Completion is emitted only when
the returned request changes to the completed state. A final `watch_logged`
with `source = watch_plan` is emitted only when the optional follow-up actually
creates a movie watch entry; merely confirming a plan as watched is not treated
as a library watch entry.

## Friend-invite acquisition funnel

The consented-user funnel is `friend_invite_sent` → `friend_invite_opened` →
`shared_link_signup` / `friend_invite_converted` → `friend_connected`.

- `friend_invite_sent` means the native share sheet was opened for an invite.
  `invite_method` is `referral_link`; `source` identifies settings, social, or
  the movie share journey.
- `friend_invite_opened` and `shared_link_opened` mean the installed app
  received `https://www.flixie.co.uk/invite?code=...`. Router-level
  deduplication prevents repeated redirects from logging duplicate opens.
- `shared_link_signup` means signup completed with a validated referral code.
- `friend_invite_converted` means that signup was associated with the referral.
- `friend_connected` is separate: the backend transaction successfully created
  or found the inviter/invitee friendship.

The referral code is an opaque random backend identifier. It is carried in the
link and signup request but is deliberately not sent to Firebase Analytics.
Before signup completes it is stored in SharedPreferences so a cold-start
redirect or ordinary app restart can restore the signup route. It is cleared
after successful referred signup and whenever an existing account becomes
authenticated, preventing attribution from leaking into a later account.

The backend validates that the referral code belongs to a real user and creates
the friendship in the same database transaction as the new profile. Existing
friendships are checked first, so retries do not create duplicates. Current
referral codes are reusable inviter codes rather than individual expiring
invites; consequently Flixie cannot distinguish two separate shares made by
the same inviter or report invite expiry/replay.

Installed-app universal/app links are configured in the iOS entitlement and
Android manifest. Deferred deep linking is not currently implemented. If the
app is absent, the website must preserve the code through App Store/Play Store
installation using a supported deferred-link provider or an Android Install
Referrer plus an equivalent iOS attribution solution. No such client SDK or
install-referrer handling exists in this repository, so invite → install
attribution must not be reported as complete. The deployed website must also
serve valid `apple-app-site-association` and `.well-known/assetlinks.json`
files; those deployment assets are not present in this repository.

Live verification on 11 August 2026 found that both
`/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json`
return the website HTML shell with `content-type: text/html`, not association
JSON. Universal Links and verified Android App Links therefore cannot be
considered configured in production yet. The website deployment must serve the
real files directly, without an SPA fallback or redirect. The AASA file needs
the production Apple Team ID/bundle ID and `/invite*` path; `assetlinks.json`
needs package `com.flixie.app` and every production Play signing SHA-256
certificate fingerprint.

Because analytics collection requires explicit consent, an invite open that
launches the first-run consent prompt is held only in memory and emitted if the
user accepts. It is discarded if they decline. Firebase reports therefore
represent the consented subset, while the backend referral relationship remains
the source of truth for acquired accounts and friendships.

Detail attribution is carried explicitly in the route query and parsed by
GoRouter. Missing or unrecognised values resolve to `unknown`; the app never
infers attribution from global previous-route state. Person links from movie or
show credits additionally carry the parent catalogue ID and type.

## Screens

The GoRouter observer centrally records meaningful names such as Home, Search,
Watchlist, Social, Friends Activity, Group Detail, Profile, Notifications,
Lists, Watch History, Movie Detail, Show Detail, and Person Detail.

## Firebase setup

In Firebase Analytics, register useful event-scoped custom dimensions such as
`content_type`, `source`, `recommendation_source`, `recommendation_algorithm`,
`recommendation_version`, `recommendation_reason`, `invite_method`,
`group_type`, `plan_type`, `share_type`, and `parent_content_type`. Register
`position`, `participant_count`, and `signal_count` as custom metrics only if reports need them. Do not register
free-text titles as custom dimensions.

To validate Android DebugView:

```sh
adb shell setprop debug.firebase.analytics.app com.flixie.app
flutter run
# Disable afterwards:
adb shell setprop debug.firebase.analytics.app .none.
```

For iOS, open `ios/Runner.xcworkspace` in Xcode and add
`-FIRAnalyticsDebugEnabled` under Scheme > Run > Arguments Passed On Launch,
then run the app. Replace it with `-FIRAnalyticsDebugDisabled` afterwards.
Events may take a short time to appear in Firebase DebugView; the local
`[Analytics]` debug lines confirm the app-side contract immediately.

Privacy hardening (17 September 2026): the event dispatcher strips `watch_plan_id`, `content_id`, `parent_content_id`, and `person_id` from every event. Callers may keep those values for local app logic; they are not sent to Firebase. Historical events are unaffected by this code change and must be considered when updating published privacy disclosures.

## PostHog configuration and Slack

The existing event contract is sent to both Firebase and PostHog. PostHog is a
no-op without a project token. Release builds default to the configured EU project
311417 public ingestion token; debug/profile builds require an explicit token so
local testing does not pollute product metrics. Pass an empty
`--dart-define=POSTHOG_PROJECT_TOKEN=` to disable PostHog in a release build. Native mobile setup is configured manually after
consent; do not add a native token or automatic screen observers. Flutter web
PostHog setup is not included (it requires a separately configured JS SDK).

Build/run with your project's public ingestion token (never a personal API key):

```sh
flutter run --dart-define=POSTHOG_PROJECT_TOKEN=phc_YOUR_PROJECT_TOKEN --dart-define=POSTHOG_HOST=https://eu.i.posthog.com
```

Use `https://us.i.posthog.com` for a US project. A new native build is necessary
after adding the plugin; hot reload cannot install native dependencies or change
compile-time defines. Test in a separate development PostHog project: decline and
check no events, allow then complete a signup/watchlist action, inspect the live
events, withdraw consent in Settings and verify later actions emit nothing.
No database fixtures are needed: use existing fictional local test accounts.

Requested Slack setup (pending project/channel connection):

- Create a Flixie dashboard with daily signup completions, taste-profile
  completions, watchlist additions, watches logged, ratings and completed watch
  plans. Add a daily Slack subscription; agree its delivery time with the owner.
- Create a Slack destination filtered to `signup_completed`,
  `taste_profile_completed` and `watch_plan_completed`. Suggested message:
  `Flixie: {event.event} completed`. Include no account or content identifiers.
- Authorize PostHog's Slack app and invite it to the chosen channel. Test with
  fictional local activity and confirm delivery. Keep webhook/bot credentials
  in PostHog, never in the mobile app.

References: [Flutter SDK](https://posthog.com/docs/libraries/flutter),
[Slack event destination](https://posthog.com/docs/cdp/destinations/slack),
[dashboard subscriptions](https://posthog.com/docs/product-analytics/subscriptions).


### Connected setup status — 19 October 2026

- Connected EU project: `311417` (currently named Default project), with approved
  timezone **Europe/London**.
- Dashboard: [Flixie product analytics](https://eu.posthog.com/project/311417/dashboard/1035487).
- Daily report insight: [Flixie daily activity summary](https://eu.posthog.com/project/311417/insights/v5IupSUU), six consented event totals over the last day.
- Existing private Slack channel: `analytics` (`C0CB4GVB35W`).
- Owner selected daily delivery at **09:00 Europe/London**, with a test delivery
  and an AI-written summary (AI credits approved).
- PostHog-to-Slack integration `91025` is connected. PostHog was added to the
  private analytics channel with explicit owner approval.
- No app events have arrived yet. Saved queries follow the app's documented
  event contract; live ingestion and native delivery remain unverified.
- Daily insight subscription `53375` is enabled with an AI summary. Next delivery
  verified as **20 October 2026 at 09:00 Europe/London** (`08:00Z`).
- Test delivery `01a15379-ca7f-7f7e-b6bb-56b2255f13db` completed; report and AI
  summary were verified in Slack:
  [test report](https://flixieworkspace.slack.com/archives/C0CB4GVB35W/p1792401868796669).
- Key-event destination `01a1537a-52f2-0000-2776-f694422af070` is enabled for
  `signup_completed`, `taste_profile_completed`, `watch_plan_completed`. Its exact
  message configuration passed a simulated invocation before enabling. No fake
  product events were ingested or posted as real milestones. The default person
  name/link template is replaced with an event-name-only message.
- Live app ingestion remains unverified: no updated release has been deployed.
  The native simulator build verifies compilation, not event receipt.

Native verification: arm64 iOS simulator build succeeded on 19 October 2026 via
Xcode after Flutter's generic simulator command hit a multi-architecture parsing
failure. No app was deployed, installed or relaunched. Focused analytics tests:
23 passed; targeted Dart analysis clean.


### Release distribution — 19 October 2026

Analytics-enabled 2.0.5 (128) was built and submitted to Apple and Google Play
production. Both signed artifacts contain the expected EU project token and
native automatic initialization remains disabled. Apple is WAITING_FOR_REVIEW
with automatic release after approval; Google production submission was accepted.
Public availability is not yet verified. Internal TestFlight build 128 is
IN_BETA_TESTING and can generate real events after the tester allows analytics.
The external privacy disclosure was updated and independently verified live before
store submission. See `docs/fastlane.md` and the retained per-store release records.


### Feature usage and product benefit — 19 October 2026

Owner requested search/movie/show usage, most-clicked controls and most-used
functionality, with emphasis on actionable product benefit. The existing PostHog
dashboard now has verified seven-day charts for screen visits, movie/show opens,
discovery source, and completed watchlist saves/watches/ratings/favourites.
Real app ingestion is verified (initial sample: 5 movie opens, 2 show opens,
2 saves, 2 ratings, 1 watch); too small to infer feature popularity. Prior setup
notes saying no events have arrived are superseded by this check.

New local app instrumentation, pending a release after build 128:

- `search_completed`: successful current first-page search responses only;
  `search_mode`, bounded `result_count`, `has_results` (0/1). Includes debounced
  searches, resubmissions, mode changes and refreshes, not every keystroke.
  Stale responses, failures and pagination do not count as completed searches.
- `search_result_opened`: movie/show/person result tap or collection/studio
  selection, with mode, result type and one-based result position. Collection
  opens count after guest access succeeds. No query, title, catalogue ID or
  account identifier is sent. Studio selection means switching the search,
  rather than opening a studio detail page.
- `detail_action_tapped`: enabled movie/show action-row buttons (watchlist,
  favourite, list, plan, share, show rating) and movie activity rate/log-watch
  controls. This measures intent, separate from successful mutation events.
- `detail_tab_selected`: explicit change to overview, reviews, activity,
  details or episodes; tapping the already-selected tab does not count.

Three prepared dashboard charts for search results, detail actions and detail
tabs clearly state that they require the next build. Existing 09:00 Slack
subscription still sends its original six-metric daily summary; no extra
scheduled Slack messages were created by this change.

Consent gating and privacy allowlists remain in force; no replay/coordinate
heatmaps or automatic input capture enabled. Screen visits are not unique
accounts. Content IDs remain stripped, so an anonymous-installation journey
cannot establish conversion for the same film/show. Existing data cannot
backfill missing search/tap events. No new local database fixtures required:
controller tests use fictional Alien search results and in-memory services.


**Release follow-up — 19 October 2026:** Extra feature analytics shipped in signed
2.0.5 (129) artifacts and submitted to both stores at the owner's request.
Apple129 VALID and internally available in TestFlight; public submission is
WAITING_FOR_REVIEW with release after approval. Google production129 submitted
with UK/US changelogs, independently verified. Public rollout remains pending
verification; no claim of new-event ingestion yet. Hourly monitor updated to129
and will notify here/#analytics per existing authorization. See docs/fastlane.md.


### Weekly Slack report — 19 October 2026

Owner requested adding search activity/most-used features to the summary, then
changed cadence to weekly. Active subscription53397 sends the weekly dashboard
1036187 to private #analytics (C0CB4GVB35W), Monday09:00 Europe/London, first
26October2026 09:00Z. Seven-day dashboard filter applies to all eight exported
insights: activity outcomes, screens, movie/show interest, successful actions,
discovery sources, search/empty results, detail buttons and tabs. AI summary
retained as previously approved, with guidance on consent, sample size, taps vs
completed actions, build129 coverage and evidence-based product improvements.
Consumes PostHog AI credits as before. Daily subscription53375 is paused and its
AI summary disabled; its history remains. No immediate test report was requested
or sent. All eight dashboard queries verified; new search/tap charts currently
empty pending rollout/usage. Key-event destination and store-live notifications
remain separate from this weekly reporting change.


### Search-result/iOS diagnostic — 19 October 2026

No production search_result_opened or search-origin content_opened events observed
in fresh24-hour queries; only two search responses received (one empty).
PostHog has no active ingestion warnings. No runtime tracking defect reproduced:
added actual Search screen movie/show/person tap regression in the existing
Patrol journey harness; verifies navigation, type/mode/position payloads and
withdrawal blocking events while retaining navigation. Focused journey/analytics
suite31 tests passed; diagnostic code analysis clean.

Native iOS SDK verification passed on a newly created disposable simulator via
`tool/verify_ios_analytics.dart`: real platform plugin sends screen,
search_completed, search_result_opened and detail_action_tapped after consent,
none before consent or after withdrawal. Receiver is loopback with a fake project
token; no synthetic production events ingested. SDK uses $os_name=iOS in native
payloads; the diagnostic checks that field. Simulator was cleaned up afterwards.
Production source/plugin registration and signed129 configuration were checked;
no production code changes or release needed by this diagnostic.

**Remaining verification:** Fresh production query including both $os and
$os_name still contains Android traffic only. Physical iPhone unavailable to
local tooling. Requested owner update/opt-in/search/result tap on iPhone to verify
actual production receipt. Prior acceptance of Firebase-only consent does not
auto-accept the newer PostHog consent. Native loopback success does not establish
production iOS receipt, installed-version correctness or the phone's consent.


### Store downloads alongside signups — requested 23 October 2026

Owner explicitly requested Apple/Google download imports in PostHog311417 and
weekly #analytics subscription53397. No warehouse sources or stored source
credentials existed at preflight. Apple connectorAppStoreConnect supports analytics
download reports but needs an Admin key; existing release configuration is
documented as App Manager. Secure connect URL prepared:
https://eu.posthog.com/project/311417/data-warehouse/connect?kind=AppStoreConnect
Limit app_ids to6779375028. Owner requested help creating the key. Await user
creation/entry through secure PostHog form; never collect private keys in chat.

GooglePlayConsole native source covers quality/vitals, not acquisition. Download
CSV reports require the Play developer reports bucket and report-read access.
GoogleCloudStorage source exists but requires HMAC credentials; no stored ones
found. Google exports may require UTF16 conversion before warehouse ingestion.
Play Console browser currently signed out. Need authenticated console/report
bucket discovery before configuring a verified import. Do not import upgrades or
re-downloads as new downloads; avoid double-counting country/device dimensional
exports and monthly restatements. Apple's connector retains report restatements:
select latest processing date per report date/dimensions before summing.

**Status:** Pending store report authorization. No connector or download chart
created, no fake download events, no change to weekly delivery yet. Signups remain
consent-only activity outcomes, not total server account creation. Final report
must label definitions, freshness/delays and aggregate comparison limitations.


### Download connection progress — 23 October 2026

The new Apple Admin key C837DJ432Q was moved beside the existing release key and validated with read-only Apple API requests: app access and analyticsReportRequests both returned HTTP 200 (no report requests yet). The release key remains unchanged. Automatic approval review blocked passing private-key contents as a PostHog tool argument because of credential logging risk. The secure PostHog connection page is open with Issuer ID, Key ID and App ID populated; the user must enter the private key and save credentials there. No warehouse source has been created yet.

Google Play Console independently exposes the Flixie October install exports in bucket `pubsite_prod_8927337084708858516`, including `stats/installs/installs_com.flixie.app_202610_overview.csv` and the country breakdown. Prefer one export family only to avoid double counting. Programmatic bucket access and recurring ingestion remain to be configured. The weekly subscription has not yet been changed to claim download coverage.


### Secure Apple source created — 23 October 2026

User approved standard secure setup. Created AppStoreConnect source `01a16a36-34e0-0000-bb3b-79f4888e42ca`, prefix `flixie_apple`, restricted by App ID `6779375028`. Metadata tables completed their first sync. Standard setup left analytics tables disabled; enabled `analytics_app_store_downloads` (`01a16a36-3537-0000-c197-83098ff99141`) explicitly with incremental processing_date/date, primary keys app_id/processing_date/_line, seven-day lookback, daily sync. Initial reload accepted and Running; no table/columns yet. Detailed analytics and sales remain disabled. Do not claim downloads ingested until actual rows verified.

Google service account read-only bucket check returned HTTP403 storage.objects.list denied. Console confirms existing app-level permissions only; account-wide “View app information and download bulk reports (read-only)” is unchecked. Requested action-time approval to enable this specific account-wide read permission (includes future apps, excludes financial data); no permission changes made yet. Weekly Slack subscription unchanged pending verified data and charts.


### Latest verified state — 23 October 2026

Apple first download sync completed without error but has no table/rows yet. Read-only Apple API now lists two analytics report requests (previously zero), confirming report generation was requested; no download counts are claimed. Daily polling is enabled.

User explicitly approved the Google account-wide read-only bulk-report permission. Enabled and saved it for the existing flixie-play-upload service account; reopened the permissions screen and verified it remains checked, with financial/admin/edit permissions unchanged at account level. Evidence screenshot: `/private/tmp/flixie-google-report-permission-saved.png`. Both storage.objects.list and direct storage.objects.get still return HTTP403 after save and a subsequent retry; propagation delay is possible, not proven. Google recurring import remains unconfigured; it will also need a secure supported credential/normalization route after access succeeds. The weekly dashboard and Slack subscription have not been changed to imply download data is available. Next: verify Google bucket access, configure ingestion, wait for Apple rows/columns, validate latest-revision deduplication and metric definitions, then add download chart(s) to weekly reporting alongside consented signup counts.


### Recheck and weekly signup summary — 23 October 2026

Apple API independently confirms both ONGOING and ONE_TIME_SNAPSHOT requests have App Downloads Standard report definitions, but both report instance lists are empty. This establishes a report-generation wait, rather than a zero-download count. Triggered another PostHog download-schema reload; do not claim imported download rows. Google bulk report bucket listing still returns HTTP403 after the approved account-wide read-only permission. No extra access changes made.

Verified weekly subscription 53397 exports insight6672261, whose first series is signup_completed. Updated and re-read its summary_prompt_guide (495 characters) to explicitly summarize consented signup totals and require verified download charts, dates, definitions and freshness, treating unavailable download data as unavailable rather than zero and prohibiting person-level conversion claims from store aggregates. Eight chart selections, Slack #analytics, Monday09:00 UK schedule and AI summary remain enabled; next delivery 26October2026 09:00Z. No test delivery requested or sent. Actual download charts remain blocked by missing Apple report instances and denied Google report access; existing source is configured but the acquisition-reporting task is incomplete.


### Contextual signup first actions
The contextual signup route retains `signup_started` / `signup_completed` from
the real auth flow and uses existing `watchlist_added`, `rating_added`,
`review_created` and `watch_logged` events with `source: onboarding` after
successful persistence. Episodes use the parent show ID and content type `show`
(the existing content contract supports movies/shows). Optional extra saves use
the same action event. `onboarding_started` is retained; a skipped taste step
does not emit `taste_profile_completed`.

Measure signup completion first, then conversion to a useful action by the same
identified account within the session/24 hours. Compare first-action time and
7-day return using existing app/session activity, and segment by the first action
event. Signup alone is not activation. Existing event fields do not identify every
entry-point variant; avoid claiming a precise entry-point comparison without an
explicitly approved analytics contract extension.
