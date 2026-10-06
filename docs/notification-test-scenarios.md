# Notification regression suite

Run `scripts/test-notifications.sh` from the app repository. Add `--local-db`
to include the guarded real PostgreSQL/HTTP journeys. The database option requires
the backend's local development database and `.env.local`; it creates and removes
fictional accounts and never targets production. Flutter and backend checks fail
the command immediately on failure. Backend-only: `npm run test:notifications`.

## Delivery expectations

| Notification | Foreground app banner | Background remote push |
| --- | --- | --- |
| Friend request, group invitation | Yes; opens notifications | Yes |
| Direct message | Yes, unless that conversation is open | Yes, subject to recipient/mute rules |
| Group chat | Quiet | Yes, subject to recipient/mute rules |
| Watch Plan invitation, acceptance, decline | Yes | Yes |
| Schedule proposed, accepted, declined, kept, scheduled, rescheduled | Yes | Yes |
| Plan location changed, cancelled, title selected, recap ready | Yes | Yes |
| Watch Plan film added or votes saved | Quiet | Existing server delivery policy |
| Community reply or reply mention | Quiet; notifications tab only | Never |
| Community reaction, shared list, referral | Quiet | Existing server delivery policy |
| Unknown or malformed foreground type | Quiet | No new delivery policy introduced |

Foreground FCM dispatch has no system-alert fallback. The OS handles background
notification payloads; data-only background replies are explicitly suppressed in
the client too. The server blocks COMMUNITY_REPLY at the shared push boundary.
This does not retract pushes queued by an older deployed backend. Local changes
must be released before they affect production.

## Automated cases

### New delivery tests

- Every database notification type has an explicit background push expectation;
  adding an enum value requires a deliberate test-policy update. DM and group
  message payloads are also covered.
- Every one of the 15 Watch Plan lifecycle events, for both friend and group
  scopes: refresh the plan, show the expected banner or remain quiet.
- All nine persisted notification types, DM, group chat, accepted-friend and
  unknown foreground messages: expected refresh, banner content and destination.
- Wrong recipient, own actor, own sender and logged-out messages: no banner or
  data refresh. Open DM: refresh without a banner. Missing navigator: quiet
  categories still refresh.
- Community replies cannot reach Firebase even with multiple devices registered.
  Queued data-only replies using either type field and case variant never invoke
  local-notification initialization or presentation.
- Multiple devices, duplicate tokens, shared legacy/device token, legacy-only
  build-70 device, no devices, duplicate recipients and empty audience.
- Exact title/body/data, APNs sound/badge and Android priority/channel.
- Both supported expired-token error formats remove the failed token, preserve
  healthy devices and condition legacy cleanup on the still-current token.
- Transient delivery failure retains the token and other devices still receive
  their messages. Personalised recipient payloads remain separate.

### Existing tests included in the single command

- Notification inbox headings, community summary copy, unread counts, duplicate
  visibility, dismissed/resolved cards and pending invitations.
- Friend acceptance failure handling, group invitation acceptance/stale access,
  transaction rollback when invitation persistence fails.
- Inbox, individual record, link, update and deletion ownership; clients cannot
  create notifications or forge lifecycle actions through inbox updates.
- Foreground banner replacement, deduplication, stale proposal rejection,
  dismissal, logout reset, action navigation and large-text/small-screen layout.
- Current friend/group detail screens refresh after incoming schedule changes
  and ignore stale responses.
- Deep links for plans, chat, community posts/discussions, referrals and lists;
  supported-client destinations; avatar badge preservation.
- Notification opt-in consent; date-only morning reminder and timed reminder
  calculation; Watch Plan contract copy and recipient rules.
- Community mention preferences and deduplication, spoiler-free copy, public list
  follower notifications, request acceptance and all-participant recap delivery.
- Message preview formatting for text, image/share payloads and malformed shares.

### Optional real-database journeys (also verified during this change)

- 100 post replies in concurrent batches produce one visible item and zero pushes;
  legacy cards close, retries preserve read state, new events reset unread,
  dismissed items reopen, separate posts stay separate.
- 100 discussion replies group by discussion and recipient; disabled reply
  preference prevents creation. Discussion batching directly exercises the real
  digest service and SQL, not the complete discussion HTTP path.
- Seven friend/mixed-plan scenario groups covering exact dates/times, reschedules,
  simultaneous proposals, multiple films, ratings/notes/retries and outages.
- 26 four-member group scenarios including declined members receiving no later
  updates, rejoining, voting, dates with/without times, stale/concurrent proposals,
  finalisation and completion. See `group-watch-plan-test-scenarios.md` for each.

## Verification boundaries

These tests execute production dispatch, delivery, widgets and service code with
external Firebase/device boundaries replaced. Real-database runs capture pushes
instead of sending them. They do not prove live APNs/FCM delivery, OS notification
permission behavior, terminated-app taps, Android/iOS reminder presentation, or
all chat mute/block combinations through live Firestore. These remain device /
transport integration checks; do not describe this suite as exhaustive physical
push end-to-end coverage. No production deployment is part of this work.

## Results on 4 October 2026

- Focused Flutter notification suite: 130 passed.
- Focused backend notification suite: 63 passed.
- Full backend test discovery: 510 passed; TypeScript checking and all 17
  build-70 compatibility checks passed.
- Local database: both reply-digest batches, seven friend/mixed scenario groups
  and all 26 four-member group scenarios passed.
- Focused Flutter analysis: no issues; running development app hot-restarted.

The existing Flutter and backend GitHub workflows discover the new test files
automatically. The local database scenarios remain an explicit opt-in command.

## Foreground inbox fallback — 5 October 2026

Foreground inbox refresh now runs every five seconds and sends newly received
items through the same Compact banner policy. It updates the shared inbox cache
and badge from one response. It stops when the app leaves the foreground.
Initial login and resume snapshots are quiet, preventing old unread items from
replaying. Remote and inbox delivery use notificationId as the banner identity,
so delayed pushes do not reopen a dismissed banner. Account-switch, logout,
read/closed/resolved invitation filtering and quiet community reply behavior are
covered by `foreground_inbox_tracker_test.dart` and the real push-service widget
regression in `notification_account_identity_test.dart`. The latter renders a
banner from an inbox response while Firebase is unavailable.

Direct messages still use Firebase delivery; they are not persisted in the
PostgreSQL notification inbox. Polling provides a fallback for persisted events,
not a replacement for all push/chat transport verification.
