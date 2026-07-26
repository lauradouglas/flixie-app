# Privacy-minimised Firebase Analytics

This document records Flixie's approved Analytics implementation. It is an
engineering inventory, not legal advice.

## Consent

Firebase Analytics collection defaults to disabled in both native apps.
The versioned local preference `analytics_consent_v1` records `accepted` or
`declined`; a missing value is treated as unknown. Unknown and declined consent
keep collection disabled. The initial prompt offers separate, equally sized
Decline and Allow analytics controls. A saved decision prevents the prompt from
being shown again.

Users can change their choice at any time through **Settings → Share anonymous
analytics**. Withdrawing consent disables future collection. Analytics failures
or preference-storage failures never interrupt app actions.

## Approved events

| Event | Trigger | Permitted parameters |
| --- | --- | --- |
| `signup_started` | Valid signup form proceeds to the signup request | None |
| `signup_completed` | Firebase/backend signup and avatar selection succeed | None |
| `onboarding_started` | Onboarding screen is first presented | None |
| `favourite_selected` | A new onboarding favourite is selected | `favourite_count` (1–5) |
| `onboarding_completed` | Onboarding data and completion request succeed | `favourite_count` (1–5) |
| `watchlist_item_added` | A movie/show is successfully added | `source`: `home`, `movie_detail`, `show_detail`, or `watchlist` |
| `watchlist_item_removed` | A movie/show is successfully removed | `source`: `home`, `movie_detail`, `show_detail`, or `watchlist` |
| `movie_favourited` / `movie_unfavourited` | A movie favourite change succeeds | None |
| `show_favourited` / `show_unfavourited` | A show favourite change succeeds | None |
| `movie_added_to_watchlist` / `movie_removed_from_watchlist` | A movie watchlist change succeeds | None |
| `show_added_to_watchlist` / `show_removed_from_watchlist` | A show watchlist change succeeds | None |
| `movie_added_to_list` / `movie_removed_from_list` | A movie custom-list change succeeds | None |
| `show_added_to_list` / `show_removed_from_list` | A show custom-list change succeeds | None |
| `rating_saved` | A movie/show rating is successfully saved | `source`: `movie_detail`, `show_detail`, or `watchlist` |
| `friend_request_sent` | Friend-request API call succeeds | None |
| `friend_connected` | Friend request is successfully accepted | None |
| `watch_invitation_sent` | Friend/group watch invitation succeeds | `recipient_type`: `friend` or `group` |
| `watch_invitation_accepted` | Watch invitation is successfully accepted | `recipient_type`: `friend` or `group` |
| `watch_scheduled` | A proposed watch time is successfully accepted | `recipient_type`: `friend` or `group` |
| `referral_invite_shared` | The native referral share sheet completes | None |
| `referral_qualified` | A referred user completes onboarding | None |
| `reward_unlocked` | The two-sided Movie Match reward unlocks | None |
| `taste_match_viewed` | A user views an unlocked taste match | None |
| `matched_movie_invitation_sent` | A watch invitation is sent from a matched movie | None |

Raw event-name strings are confined to the analytics module. Events are ignored
unless consent is accepted. Lifecycle funnel events are deduplicated within the
running app session.

## Automatic Firebase collection

When consent is accepted, Firebase may collect its documented automatic events
and basic app, device and usage diagnostics, including events such as
`first_open`, `session_start` and `app_open`. Flixie does not manually log those
events. Review Firebase's current documentation and console data-retention
settings before each release.

## Advertising and identifiers

- Android disables Analytics collection by default, advertising-ID collection,
  and default ad-personalisation signals in `AndroidManifest.xml`.
- iOS disables Analytics collection by default, IDFV collection, and default
  ad-personalisation signals in `Info.plist`.
- Flixie does not set Firebase Analytics `userId`.
- Flixie does not add `AdSupport.framework` or request App Tracking
  Transparency permission.
- Google Signals, advertising features, ad personalisation and cross-app
  tracking must remain disabled in the Firebase/Google Analytics console.

## Prohibited Analytics data

Never add account/Firebase/database IDs, names, usernames, email addresses,
movie/show names or IDs, reviews, messages, search terms, friend names or IDs,
exact location, free-form text, or other identifying/sensitive content to
Analytics events or parameters.

## Release-owner review

Before distribution, the owner should review:

- App Store Connect privacy answers for Usage Data/Product Interaction,
  Diagnostics, Device ID or other categories Firebase's current behaviour makes
  applicable.
- Google Play Data safety answers for analytics, app interactions, diagnostics
  and any device identifiers Firebase's current behaviour makes applicable.
- Firebase and Google Analytics retention, data-sharing, Google Signals and
  advertising settings.
- The published external privacy policy, updating it before distributing this
  build so it accurately explains consent and Firebase Analytics.
