# Two-account safety test — 17 September 2026

## Environment

- iPhone 17 Pro Max: @Dougasaur; iPad (A16): @User. Both iOS/iPadOS 26.5.
- Local API at `http://localhost:3000`, local development database, authentication enabled.
- User signed into both accounts. Latest local app build installed on both simulators.
- Xcode Device Hub used for actual UI interactions. Dependency deployment targets aligned to the app's existing iOS 15 minimum.

## Interactive results

| Scenario | Result |
| --- | --- |
| Verify separate account identities | Passed |
| Send/accept a friend request | Passed: recipient sees correct wording and Accept/Decline |
| Send direct message before blocking | Passed: User's `test before block` received by Dougasaur |
| Create private group and accept invitation | Passed after fixes below; `safety test 1709`, only these two members |
| Exchange group messages | Passed: `group test` and `group reply` received on opposite devices |
| Block Dougasaur from User | Passed: confirmation, unfriending, existing group messages hidden immediately |
| Attempt friend request while blocked | Rejected; no pending request created in recipient inbox |
| Open existing direct chat while blocked | Denied; composer unavailable |
| Group preview hides blocked message | Passed: generic blocked-message placeholder |
| Group activity hides blocked actor | Passed after cache fix; repeated block verified without restart |
| Restart with block active | Passed: friendship absent, direct chat hidden, group message/activity hidden; blocked-users list retains Dougasaur |
| Unblock | Passed after sheet fix; immediately shows empty blocked list |
| Reconnect and resume direct messages | Passed: fresh friend request accepted, User's `after unblock` received by Dougasaur |

## Fixed during this test

1. Optional group abbreviation was omitted by the app but required by storage. Server now supplies an empty string when omitted.
2. Group invitations were classified as activity rather than pending actions. New recipient notifications use RECEIVED; legacy SENT group invites normalize by actual recipient and pending status. The invitation preview no longer requests the protected member list before joining.
3. Cached group activity remained visible after blocking. The activity tab now listens to safety changes, immediately filters blocked actors, and refreshes. A stale in-flight response cannot restore their content.
4. Unblocking removed the server record but the UI threw because the setState callback returned a Future. Fixed synchronous state update, duplicate-tap prevention, unblock error feedback, and failed-list retry.

## Validation

- 17 notification inbox/destination tests passed.
- 6 group activity/safety service tests passed, including immediate hiding while refresh is pending and after a stale response.
- 5 backend group moderation/creation tests passed, including omitted abbreviation.
- Backend TypeScript check passed; changed Flutter files analyzed cleanly.
- Final simulator builds succeeded and both devices run the fixes.

## Remaining scope and observations

- This does not verify real push delivery, report delivery/moderation operations, account deletion, or Apple's required physical-device recording.
- Existing direct chat rows can briefly show `Direct chat` when friend-profile cache is stale; opening the chat resolves the correct participant. The sender's profile can retain `Request Pending` until reloaded after acceptance. These cosmetic refresh issues were observed but not changed in this blocking pass.
- Both test accounts are unblocked and friends again. The private test group and four test messages remain for reference; no accounts or unrelated content were deleted.
- Changes are local only: production backend deployment and a new store build remain necessary.
