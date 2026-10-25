# Firestore rollout — 21 October 2026

Production project: `flixie-9a8eb` (default database).

The unread-badge rollout uses `firestore.production-compat.rules` and
`firebase.production-compat.json`, mirrored in the backend checkout. It preserves
every previously deployed conversation/message/member read grant and adds only
the mapped owner's positive-count collection-group query. Client writes remain
denied. This avoids requiring already released clients to establish the newer
identity mapping before reading chat.

The existing production grants allow any signed-in account to read those chat
paths; this rollout does not resolve that existing restriction gap. The stricter
`firestore.rules` is exercised locally but is **not the deployed ruleset**. Do not
deploy it to production until released-client identity readiness, backend mapping
coverage and all supported query paths have been verified. A backend deployment
or new app release was not part of this Firebase deployment.

Targeted rules deployment (do not substitute the default config):

```sh
firebase deploy --project flixie-9a8eb --config firebase.production-compat.json --only firestore:rules --non-interactive
```

The additive composite index is `members`, `COLLECTION_GROUP`, with `userId ASC`
and `unreadCount ASC`. It was created individually through the Firebase API, so
existing composite indexes and field overrides were not reconciled or deleted.
Verified serving state: **READY**. Live rules source was fetched after deployment
and matched the compatibility file exactly.
Index resource: `projects/flixie-9a8eb/databases/(default)/collectionGroups/members/indexes/CICAgOi3kJAK`.

`test/firestore_production_compat.integration.mjs` must run against a fresh local
Firestore emulator loaded with `firestore.production-compat.rules`. It checks
legacy reads without a mapping, denied anonymous reads/client writes and the new
owner-only unread query, including count changes and mark-read removal. The
stricter local rules retain their separate existing test suites. Tests reject
non-loopback emulator endpoints and use fictional demo data only.

The new client calls the backend identity-readiness endpoint before the unread
query. That backend capability must be live before the new build ships. These
Firebase changes do not deploy backend code. Current released clients continue
using their existing listeners; read savings begin when users install the new
build. No production messages or account counters were changed during validation.

The previous live source is saved locally at
`.local/firebase/rollout-2026-10-21/previous-production.rules` for rollback. The
compatibility source is precisely that source plus the new owner-only list grant.


## Backend endpoint verification — 21 October 2026

The latest successful production API deployment is commit
`36d043d9543bde77d511296b79cadfc0f33ea573`, workflow run
https://github.com/lauradouglas/FlixieBE/actions/runs/39426072736 (20 October).
Its source includes authenticated `GET /users/me/chat-identity`, deriving the
Postgres ID from the authenticated Firebase identity, syncing the mapping and
returning `{ready:true}`. The Azure deployment step and full regression suite
succeeded. Live `/healthcheck` returns 200/App Healthy; an unauthenticated identity
request returns 401/Unauthorized as expected. No signed-in production request
was made, so account-specific mapping success was not exercised. No deployment
was needed or performed; current builds and backend contracts remain unchanged.

The separate local optimization that avoids rewriting an unchanged identity
mapping is not in that deployed commit. The existing endpoint is available for
the unread-query rollout, but those additional backend write savings remain
pending a separate backend deployment.


## Identity-write optimization deployed — 21 October 2026

User explicitly authorized deployment. Commit
`9941fdca4f41d03d13e3ac0fe27eeb4dc3af5660` changes only
`src/services/chatIdentityService.ts` and its regression test. The release was
isolated from all other working-tree changes, based on the previous production
commit. Typechecking and all 728 tests passed locally, with zero skipped tests.
GitHub's full regression suite and Azure deployment also succeeded:
https://github.com/lauradouglas/FlixieBE/actions/runs/39626164702 .

Readiness still checks the deletion marker inside every transaction. It reads
the existing mapping and writes only when missing or different; five successive
checks create a missing mapping once instead of rewriting it five times. Changed
mappings are repaired, and deleting accounts/storage errors retain their failure
behaviour. This replaces an unchanged write with an additional mapping read, not
a claim of zero Firestore costs. Endpoint response, authentication, request
shapes, chat writes and database schema remain unchanged. Current builds benefit
without an app update. The earlier note that this optimization is undeployed is
now superseded. No production account was used for a signed-in mutation test.


## Message send/read optimization deployed — 21 October 2026

User authorized current-build-compatible release 8dcef76ea8083bf2cd553d49ccf51c39d30b1f3f.
https://github.com/lauradouglas/FlixieBE/actions/runs/39631033329 succeeded, including
full production regressions and Azure deploy. Only messaging service, session
regressions and guarded local emulator verification script shipped. Existing
API routes, payloads, database schema and unread recipient writes are unchanged.
Text sends save the separate sender-membership read (DM fixture 5 ->4 reads).
Repeated mark-read skips a write only when count=0 and latest message is already
acknowledged; newer messages and missing first acknowledgement still update.
Timeline-first/member-second transaction reads preserve consistent counters during
concurrent arrivals. Reads remain billable; contention can cause transaction
retries. Mark-all-read continues calling the same endpoint per conversation.

Release typechecking and 733 backend checks passed, with zero skipped; nine
Flutter unread/badge/mark-all/history-read checks passed. Two final real-emulator
runs each passed 12 concurrent send/acknowledgement races, duplicate write
suppression (unchanged updateTime), direct/group mark-all and later unread arrival.
No production account was used for send/mark-read mutation testing.


## Background polling optimization live — 21 October 2026

User authorized implementation/deployment preserving account deletion, safety
retries and Slack alerts. Commit 51d74a0da52e3d9d31c56425699b8b010bcfe95f deployed
successfully through https://github.com/lauradouglas/FlixieBE/actions/runs/39636515662 .
Typechecking and all 742 local backend regressions pass (zero skipped); GitHub
full regression/build/backup/deployment also succeeded. Only polling-related
services and tests shipped; API payloads and database schema are unchanged.

Independent queues reconcile immediately at startup, then empty scans back off
2/4/5 minutes. Found work and failures restore the active minute cadence; producer
wake-up hints resume a local queue on the next tick and cannot be overwritten by
an in-flight empty result. Slow queues cannot block other workers. Direct deletion
and safety-report delivery attempts remain immediate. Existing durable jobs,
leases, heartbeat, identity revocation, checkpoints, sent receipts, SQL
reconciliation, Slack Retry-After, pacing and deduplication are retained.
Foreign-instance work without a local wake-up and deferred Slack retries can wait
up to about five minutes for reconciliation, plus existing lease/processing time.
Restart scans are immediate; nothing depends solely on the local hint.

The Google Play monitor caches a committed durable lease deadline locally to
avoid the four intermediate minute-tick Firebase reads, retaining cross-instance
coordination, quiet baseline and release-transition retry semantics.
A simulated idle day produces about 289 queue scans instead of 1440 per process
(about 80% fewer affected idle scans, not a measured 80% total-bill reduction).
No real account deletion, safety report or artificial Slack post was used for
production testing. Current builds benefit without an app update.
