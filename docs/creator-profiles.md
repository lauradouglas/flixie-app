# Creator profiles and interview content

Implemented as optional editorial content for the shared other-user profile.
No creator is verified yet. Normal profiles work without this payload and empty
interview sections never appear. Earned badges are independent of verification.

## First creator workflow

The backend `src/services/creatorProfiles.ts` contains the initially empty approved
registry keyed by user ID. Verify the person's identity and their role manually,
obtain their actual answers and approval to publish, then add an entry in code
review. Do not generate answers on their behalf or accept verification from
editable profile fields. Remove the registry entry to withdraw the editorial
profile. This deliberately needs no public verification signup or migration while
there are no verified users. A future admin workflow can replace the registry.

Each entry has `verified: true`, a role such as `director`, optional HTTPS
`coverUrl`, optional `credits` (movieId, title, credited role, posterPath), and answers:
`question`, `answer`, and optional `movieId`, `title`, `posterPath`. Confirm TMDB
movie IDs so film links open the right title. Repeat a question with different
films if needed, or provide a single introductory answer. Only actual answers
render. The optional `creatorProfile` API field is additive for older clients.

## Interview prompts to offer

- Films that shaped me — which film changed how you see or make cinema, and why?
- The scene I wish I'd made — a craft-focused choice; avoid revealing spoilers.
- A film I changed my mind about — what became clearer on a later viewing?
- My comfort rewatch — the film you return to, and the feeling it gives you.
- An overlooked film everyone should see — a discovery with a personal reason.
- A first-time filmmaker's essential watch — a concrete lesson, not just a title.
- The best cinema experience I've had — the room, the audience and why it mattered.
- A perfect double bill — two films and what makes them speak to each other.
- What I'm watching next — an optional current answer, with an editorial refresh.
- A collaborator who changed my approach — only publish verified credited claims.

“Films that shaped me” is the user's preferred anchor. Offer a small selection,
not a mandatory questionnaire. Film choices and written explanations are more
valuable than a wall of empty questions. Only populate credits and cover imagery with verified information and approved
assets. Contact, website and commercial claims need separate review.

## Profile behavior

- Friends show Friends · Following and Message / Plan a watch; no redundant Follow.
- Nonfriends retain their current friendship request action plus Follow when
  entered through Around Flixie.
- Short bios don't show Read more. Long bios expand in place.
- Zero-only totals are hidden; empty Activity/Reviews tabs are omitted when both
  have no loaded content. Actual public lists can still appear independently.
- Quiet profiles explain visible activity, not whether someone has private data.
- Shared-taste/watchlist sections are shown for friends. Existing privacy,
  report/block actions and the user's own avatar badge border are retained.
- Earned milestones are a quieter action below profile content, restricted to
  the existing owner/friend access policy.

Approved creator cover imagery and film credits render when supplied in the
registry. Personal cover-photo uploads and a self-service filmography editor
remain future extensions. No random imagery or fake credits are supplied.

## Local demo accounts

Seed with `NODE_ENV=development node --env-file=.env.local -r ts-node/register
scripts/seed-dev-creators.ts` from FlixieBE. It requires explicit local mode and
matching loopback PostgreSQL URLs; it refuses remote databases and identity
collisions. Reruns are idempotent. No Firebase accounts, messages or pushes are
created. Existing user content is not overwritten.

- `dev_director`: Maya Chen, fictional director.
- `dev_actor`: Alex Rivera, fictional actor.

Both are accepted friends of local Dougasaur, with favourites, watchlists,
sample film credits and three interview answers each. Shared picks are copied
from Dougasaur's existing watchlist into the fixtures only. Creator editorial
data is stored in the ignored backend `.local/creator-profiles.json` file and
loaded only after the local seed safety guard passes. Database identities use
`dev-creator-fixture:` external IDs, so they cannot be mistaken for real sign-ins.
Demo credits against catalogue titles are explicitly fictional, not real credits.
Restart the local backend after pulling the creator registry loader changes,
then refresh Dougasaur's friends and open either profile.

## Follow preference correction

Friends follow by default, but the compact Following control can be tapped to
unfollow without unfriending. The relationship label stays Friends; Follow can
restore inclusion later. Explicit choices persist in CommunityFollow.following.
False overrides automatic friend inclusion in Following, without hiding that
person from Discover or removing messaging/watch plans. Mute remains separate.
Apply migration `20260926140000_friend_follow_preferences` before deploying this
backend; it defaults existing follow rows to true and was applied locally.
