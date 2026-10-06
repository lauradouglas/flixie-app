# Four-member group Watch Plan scenarios

Implemented on 4 October 2026. Fictional members: **Casey (creator), Robin,
Ellis and Blair**. Films: **Alien, The Odyssey, Obsession and Spider-Man: No Way
Home**. An additional fictional outsider tests access denial.

## Real HTTP and PostgreSQL — 25 scenarios

These run production Express routes, acting-user authorization, services, Prisma
transactions, stored inbox notifications and diary writes against the guarded
local database. Firebase identity is supplied by the isolated test harness;
external push delivery is captured and Firestore chat transport is deliberately
unavailable. Assertions examine persisted outcomes, not copied service logic.
Every run creates fresh accounts/groups and removes its own data afterwards.

1. Single-film date-only creation invites exactly the other three members.
2. One member declines, their invitation closes and the other three continue.
3. Declined member cannot vote, add films, schedule or log a watch.
4. Rescheduling never reinvites a declined member by push or inbox.
5. Cancellation reaches active members and leaves declined members quiet.
6. Four members join a timed single-film plan without silently approving its time.
7. The initial timed schedule waits for all three invited members and preserves the timezone.
8. One member keeping the current time rejects only the replacement.
9. Replacement requires four approvals and creator confirmation; non-creator finalization is denied.
10. A newer proposal supersedes an older one; stale replies cannot change the schedule.
11. Two initial films retain creator picks; another member adds Obsession and Spider-Man.
12. Votes are per member, editable, deduplicated and preserved across fresh reads.
13. Duplicate titles and a sixth option fail without changing the shortlist.
14. Members cannot remove another member’s option; removing their own clears its votes.
15. Only the creator chooses the final film; votes never auto-select it.
16. Creator reopens choices and adds a film after single-film creation.
17. Declining after voting removes the departed member’s votes and further notifications.
18. A decline during a pending proposal removes that member from required approvals.
19. The last outstanding member declining lets an already agreed proposal proceed.
20. Invalid votes leave the single selected film intact; valid votes do not unlock it.
21. An explicit rejoin restores future notifications without restoring old votes.
22. Outsiders and forged member IDs are denied with no mutation.
23. All three invitees may decline without creating a creator-only scheduled screening.
24. Four members log independent ratings and notes; retries never duplicate diary entries.
25. Completed and cancelled screenings reject further movie mutations.

## Production Flutter screens — 13 journeys

The same journeys run as fast widget tests and through Patrol on the dedicated
iOS simulator. Their HTTP fixtures are strict and stateful: unexpected requests
fail the test. These cover real widgets and API serialization; the separate
HTTP/PostgreSQL suite verifies the server behavior those fixtures represent.

1. Decline an invitation, refresh, and retain the declined state with no joining, voting or scheduling controls.
2. Fail a decline request, preserve the actionable invitation, and retry successfully.
3. Leave an already scheduled screening: three members remain and the departed member has no calendar, reschedule or logging actions.
4. Explicitly rejoin without changing the other three members’ responses.
5. Another member finds and adds Obsession, saves their film votes and preserves everyone else’s choices after refresh.
6. The creator reopens a scheduled single-film plan and adds another film while retaining the agreed date.
7. After one person declines, the creator can choose a film once the remaining three have voted.
8. Propose a date without a time, retaining four required approvals; its reminder policy is morning-only at 9am.
9. Give the final date-only approval: confirm the exact day and never display an invented 1pm time.
10. Propose a date and 19:30 time, retaining four required approvals and the exact local time.
11. Give the final timed approval: confirm the exact timestamp and preserve it after refresh.
12. Reject a replacement time with “Keep current”: retain the original schedule and all four participants.
13. The creator confirms a unanimously approved replacement date without a time.

## Product fixes exercised

- Declining closes existing plan notifications, removes that person’s votes and pending approvals, and filters them out of subsequent inbox and push recipients.
- Rescheduling no longer automatically reinvites people who declined. Explicit rejoining restores later updates.
- Remaining participants can finish agreement even when the final outstanding member declines. Three declines cannot create a creator-only scheduled screening.
- Declined members cannot vote, add films, propose a time or log a watch. Screens offer a clear declined view and an explicit rejoin action.
- Accepted members can leave a scheduled screening. The creator can reopen a single-film plan and add options.
- Declined and archived plans cancel local reminder registrations when loaded; cancellation waits for an in-flight scheduling operation.
- Invalid votes do not unlock a single-film selection, and valid sole-title votes preserve it.
- Completed/cancelled plans reject later movie mutations with a useful conflict message.
- Final participant logging can be retried after completion without duplicate diary entries.

## Run commands

From the app:

```sh
flutter test test/group_watch_plan_journeys_test.dart
scripts/test-patrol.sh -d D4255A47-A9F1-4BFB-A770-557608119574 -t patrol_test/group_watch_plans_test.dart
```

From the backend:

```sh
npm run test:group-watch-plans:e2e:local
```

A native run only counts when Patrol discovers and passes all 13 tests. A runner
exit code of zero with zero discovered tests is not a pass.

## Persistent local examples

The guarded, rerunnable backend script preserves existing fixture plans:

```sh
NODE_ENV=development node --env-file=.env.local -r ts-node/register scripts/seed-dev-group-watch-plans.ts
```

It creates private **LOCAL DEMO · Four Film Friends**, fictional accounts
`dev_group_casey`, `dev_group_robin`, `dev_group_ellis`, `dev_group_blair`, a
single-film date-only screening with Blair declined, a single-film timed
screening with all four accepted, and four film options with overlapping votes.
These database-only identities do not create Firebase login credentials.

## Verification boundaries

Captured push dispatch and stored inbox state are verified against real SQL.
Actual APNs/FCM delivery, a live Firestore conversation, Firebase login and
background operating-system alarm delivery are not exercised by these suites.
Date-only 9am reminder calculation is tested; cancellation wiring is implemented,
but this run does not prove removal from a physical device’s OS notification queue.
The native and database suites are complementary, not one continuous device-to-
database run. No production deployment or production data changes.

## Verified results — 4 October 2026

- **25/25** real HTTP/PostgreSQL group scenarios passed.
- **13/13** native iOS Patrol journeys passed; zero skipped. Result bundle: `build/ios_results_1791150317705.xcresult`.
- **13/13** shared widget journeys passed.
- **43/43** focused backend regressions and **17/17** build-70 compatibility tests passed.
- **15/15** focused date-only, calendar and API-error Flutter regressions passed.
- The previous six real local watch-plan scenario groups passed again.
- Backend and script TypeScript checks passed; focused Flutter analysis found no issues.
- Four-member local fixtures were seeded and rerun; the development app hot reload succeeded.

## Follow-up: competing proposals and foreground notifications

Added a 26th real database group scenario: two members submit different proposals
concurrently; only one remains pending, a reply to the replaced proposal gets 409,
and concurrent approvals confirm the surviving proposal with its exact date/time
and date-only flag. Push payloads include proposal identity and occurrence time.
The friend runner also sends two concurrent proposals and verifies one pending
proposal, stale-reply rejection and agreement on the surviving date/time.

A 14th shared group screen journey verifies an incoming watch-plan refresh updates
the already-open detail from a timed proposal to the latest date-only proposal.
`test/foreground_watch_plan_notice_test.dart` covers friend/group navigation,
account/actor filtering, deduplication, replacement, delayed older pushes,
dismissal/logout and small-phone/landscape/tablet layouts at 2× text scale.
`test/watch_plan_notice_preview_test.dart` renders the real banner widgets.

Both friend and group detail screens also have delayed-response tests in
`test/watch_plan_foreground_refresh_test.dart`: a newer refresh must make a fresh
HTTP request, display the latest server state, and retain it when the older
response finally arrives. Both passed. Banner and preview tests: 10 passed;
shared group widget journeys: 14 passed. Final group database runner: 26 passed;
friend concurrency runner passed; build-70 compatibility: 17 passed.

Final native follow-up: **14/14 passed**, zero skipped, including the incoming-update
journey. Result: `build/ios_results_1791151422069.xcresult`. Development app
notification initialization was hot-restarted, then final screen changes hot-reloaded.
