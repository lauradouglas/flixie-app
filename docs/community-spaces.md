# Mobile community spaces

Implemented locally on 28 September 2026 following approval of the Anime mockup.
iOS and Android phones are the primary target. Existing Social → Communities
routes now open the same four-tab experience for Anime and film-genre communities.

## User experience

- Discuss: latest member discussions, general questions or a catalogue-linked title,
  explicit spoiler-free/full-title/through-episode boundaries, paged replies and
  membership required to publish or reply. Spoiler titles and bodies are withheld
  by the API until explicit reveal; replies use the same gate. Deleted or unavailable
  threads cannot accept replies. Authors can delete their own posts and replies.
- Discover: real member-rated titles, one latest public review per author/title,
  average and sample count, film/series distinction, original title navigation and
  existing watchlist actions. Existing rate-first preferences remain enforced.
- Reviews: original public-review feed and original review/comment destinations;
  Anime additionally filters All/Films/Series on the server before pagination.
- People: paged members who opted into public sharing, each author's own badge
  border, existing profile/review navigation and explicit follow actions.
- Join requires a confirmation explaining visibility. Joining never enables public
  sharing. Leaving removes contributions from the space without deleting originals.
- Report/block reuse existing safety controls; mute uses existing community
  preferences. Blocking in either direction, muted authors, deactivated users and
  departed members are excluded server-side. Private reviews and nonmember reviews
  do not contribute to discovery. Explicit public discussions are independent of
  the review-sharing preference; posting copy explains that distinction.

All four tabs use native Flutter controls, scrolling, safe areas, errors/retry,
empty states and bounded pagination. Search is limited to eligible catalogue titles;
episode boundaries must exist in the catalogue. Drafts remain in place after a
failed post/reply. A failed refresh can be retried even when the last complete
feed has no further page. Duplicate taps are disabled; backend rate limits bound bursts.
No automatic follows, notifications, watch-alongs or invented community statistics.
The mockup's editorial beginner collection remains content work, rather than
presenting a fabricated live curation list.

## Backend and local data

New authenticated `/community/spaces/:id` APIs are additive. Community ID -1 is
Anime; other IDs are the existing supported film genres. Existing activity,
membership and old-client request/response contracts remain available.

Migration: `../FlixieBE/prisma/migrations/20260928120000_community_discussions/`.
It adds discussion/reply tables, foreign keys, bounded text and pagination indexes.
Applied to the verified local-only development database. Production must apply
this additive migration before deploying the new API and app; no production
migration or deployment was performed.

Rerunnable fixtures: `../FlixieBE/scripts/seed-dev-community-spaces.ts`.
Requires the existing movie-opinion and Anime seeds; creates only fictional
Casey/Robin/Ellis conversations, Spirited Away and Attack on Titan, with member
and nonmember reply controls. It refuses remote databases and validates fixture
account identities. No real users' content or memberships are changed.

Local SQL/API integration: `../FlixieBE/scripts/test-community-spaces-local.ts`.
Uses guarded fictional accounts and cleans up temporary posts and replies.

## Verification

- 30 focused Flutter tests passed across the final focused runs: community interactions, existing genre/Anime
  behavior and signup community integration. Includes 320/430-point phones,
  844-point landscape and 768-point tablet with 2× text.
- Four focused API tests passed: request validation, member permissions, actor
  identity, hidden spoilers, reply access, author deletion and discovery policy.
- Local database integration passed for discovery, catalogue search, spoiler gates,
  nonmember reply exclusion, posting, replies and owner deletion.
- 14 build-70 compatibility checks passed. TypeScript typecheck and focused Flutter
  static analysis are clean. Full regression suite was not run.
- Dedicated Flixie Patrol iOS simulator passed join → reveal → reply → background
  and resume using isolated fixtures. The same journey also passed on the dedicated Flixie_Patrol Android emulator
  (Android 37.1 image). Both device runs used fictional fixtures, not production
  accounts.

Finish review: spoiler-title context and the 320-point/2× composer selector were
corrected. Reviewer disposition: ship for those two source/test-level fixes; native
visual review covered Discuss, not every composer/detail state.

Android verification completed successfully after creating a separate test emulator;
existing user emulators were not reinstalled. Native captures cover iOS Discuss and
an Android join-dialog transition; they are test evidence, not polished screenshots
or an exhaustive visual audit of every screen.

## All-community local demo fixtures

Run from FlixieBE with the configured local development database:

```sh
NODE_ENV=development node --env-file=.env.local -r ts-node/register scripts/seed-dev-all-communities.ts
```

Requires the existing fictional movie-opinion accounts and catalogue. Populates all
18 film communities other than **TV Movie (10770)**, plus Anime. Each gets three new
discussions, six replies, two public fixture members and a private-review control;
two or three eligible films receive mixed reviews. Existing Anime fixtures remain.
Membership does not alter sharing preferences. No real users are joined or edited.

The script validates local-only database configuration and fixture ownership before
writes, uses stable namespaced IDs, and preserves existing fixture edits on rerun.
It refuses to erase any existing TV Movie content. Post-seed checks exercise actual
review/discovery visibility, public people, replies and the empty state. Executed
successfully twice; counts remained unchanged and private reviews stayed hidden.

## TestFlight upload — 28 September 2026

Flixie 1.0.0 (82) was built with the production API and uploaded successfully to
App Store Connect at 16:41 BST. Fastlane confirmed Apple accepted the binary;
the immediate build-list query still showed 81 as the latest processed build.
Processing and tester availability were not yet confirmed. 65 focused Flutter tests,
release guard/tooling checks and build-70 compatibility tests passed. No external
beta review or App Store submission performed. Community API/schema changes remain
local pending explicit backend rollout approval; uploading this binary does not
make the new community endpoints available in production.

## Mentions and comment replies

Posts and replies accept optional `mentionIds` (maximum five); recipients must be
selected members/friends and their @username must remain in the submitted text.
Public-sharing members and the actor's friends appear in bounded username-prefix
suggestions. Block/mute filters and deactivated-account exclusions apply. Replies
accept optional `parentReplyId`, validated against an available comment in the same
thread. The UI retains flat replies with a linked parent and a cancellable composer
target. Precise reply fetches are scoped to the requested discussion and spoiler gate.

Migration `20260928170000_community_mentions` adds mention arrays and an indexed
nullable parent-reply FK. Applied locally only. Push/inbox events use COMMUNITY_REPLY
with specific events COMMUNITY_MENTION / COMMUNITY_COMMENT_REPLY, the existing reply
notification preference, per-event recipient deduplication, no self alerts and no
spoiler text. Notification route stays compatible with build 70; communityRoute opens
the discussion and selected reply on new clients. Recipients must still be able to
view the thread author. No real notification settings are changed.

Local fixture: `../FlixieBE/scripts/seed-dev-community-mentions.ts` (guarded, rerunnable,
fictional accounts only, no push delivery). Enables the fictional Ellis reply-notification
preference and adds a fictional Casey–Blair friendship for nonmember-friend coverage.
Checks: 30 Flutter tests, four API/notification tests, build-70 suite, local API/SQL
integration and dedicated iOS Patrol. Android native checks not repeated for this
increment. Requires backend migration/API rollout before the newer app; not in build 82.

Final verification: both dedicated iOS Patrol scenarios passed, including selecting
@Ellis while replying to a specific comment and submitting both recipient/parent IDs.
The compatibility command now includes the mention notification tests: 16 passed.
