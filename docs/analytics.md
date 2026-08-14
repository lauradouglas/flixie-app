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
names, message/review text, or participant IDs. `content_id` is the public media
catalogue identifier, not a user identifier. Parameters are filtered by the
allowlist in `AnalyticsController`; unknown sources become `unknown`.

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
| `content_opened` | Movie/show detail data opens | `content_type`, `content_id`, optional `genre`, `source` |
| `person_opened` | Person detail data opens | `person_id`, `source`, optional `parent_content_id`, optional `parent_content_type` |
| `watchlist_added` | Watchlist add succeeds | `content_type`, `content_id`, `source` |
| `watch_logged` | A new watch entry succeeds | `content_type`, `content_id`, `source`, optional watch-plan attribution |
| `rating_added` | Rating save succeeds | `content_type`, `content_id`, `source`, optional recommendation attribution |
| `review_created` | Review creation succeeds | `content_type`, `content_id`, `source` |
| `recommendation_given` | A recommendation is successfully sent | `content_type`, `content_id`, `source` |
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

- `content_id`, `content_type`
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
Watch-plan events include `watch_plan_id`, `content_id`, `content_type`,
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
`position`, `participant_count`, `signal_count`, `person_id`, and
`parent_content_id` as custom metrics only if reports need them. Do not register
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
