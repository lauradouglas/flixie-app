# Second App Review pass — fixes completed locally, 17 September 2026

The three confirmed findings from the second review are fixed in the repositories. No production deployment, migration, account changes or App Store submission was performed.

## Changes

1. **Removed the fabricated PG-13 film label.** Movie details now show the known release date and runtime. The API does not currently provide a verified regional certification, so no certification is invented. This is separate from Flixie's App Store age rating.
2. **Account deletion is available before accepting updated terms.** The legacy-account terms screen shares Settings' password-and-DELETE confirmation flow. Deletion remains accessible when the terms lookup is missing, fails or stays loading; no acceptance is recorded by opening or completing deletion. Small phones, large phones, tablets, landscape and doubled text size are covered by widget tests.
3. **Group and Watch Plan permissions are enforced against the signed-in account.** Group, direct Watch Plan and general request routes bind actor IDs to verified identity. Group reads require accepted membership; pending invitees receive only a basic group preview. The general group listing is scoped to the viewer. Group edits/invites require owner/admin status; deletion and ownership transfer require the owner. Members can leave themselves and answer only their own pending invitation. Ownership transfer updates the authoritative owner and both member roles in one transaction; the app now sends one transfer request.

The permission work also closes related bypasses:

- Creation and invitation payloads cannot grant ownership or pre-accept another user's membership. Arbitrary nested database writes are rejected or stripped.
- Generic invitation endpoints cannot forge a sender, accept another person's request, reuse a closed invitation or accept a group invitation after membership removal. Group invitations must originate through the authorized group workflow.
- Group-scoped Watch Plan IDs must belong to the indicated group; responses must belong to the actor. Existing creator/participant lifecycle rules remain in place.
- Group member profiles expose public profile fields rather than email, authentication and consent fields, while preserving avatars and badge borders.
- Removing or leaving a group revokes its linked live-chat membership before the API reports success. Revocation failures abort the removal so it can be retried. Legacy chat membership endpoints cannot bypass a linked group's invitation/role controls.

## Verification

- **319 backend tests passed**, including nested suites, forged actor/request checks, member/admin/owner permissions, atomic ownership transfer, membership revocation and public profile projection.
- **23 focused Flutter tests passed**, covering terms, deletion without agreement, movie details/cache, group activity and Watch Plan tabs.
- TypeScript compilation passed. Flutter analysis of all changed screens/widgets and the new deletion tests reported no issues.
- No physical-device test or iOS archive was performed in this pass. Existing unrelated work in both repositories was preserved.

## Rollout and manual regression checks

Deploy the updated backend and ship a new app build together, following the existing [deployment order](app-review-fixes-2026-09-17.md#deployment-order). This pass adds no database migration or Firestore rule change. Earlier migrations, chat mappings, indexes and rules are still required. Use the latest app build for ownership transfer.

Use disposable accounts with owner, admin, accepted member, pending invitee and outsider roles:

1. Open several movie detail screens. No movie should display a guessed PG-13 label; runtime/date should still appear when known.
2. Log in to an existing account without current terms acceptance. Leave agreement unchecked, choose Delete account, enter its password and DELETE, and complete deletion. Repeat with a failing terms lookup in staging. Cancel must preserve the account; agreeing must still work normally.
3. Create a group and invite another account. The invitee must remain pending until they accept. Their account must not show member activity or plans before acceptance. Accepting should unlock group content and chat.
4. As a member, confirm activity, plans and chat work. Leave the group; refresh the group and chat on another signed-in device. Access must be revoked. Repeat by having an admin remove a member. A removed account must not regain membership using its old invitation.
5. As an admin, edit group details and invite/remove ordinary members. As owner, transfer ownership to an accepted admin. The new owner can delete/manage the group; the former owner remains an admin. Ordinary members cannot edit group details or roles.
6. In staging, attempt group reads/changes as an outsider, supply another person's actor ID, accept another person's invitation, and use a plan ID under the wrong group. Each must fail without making a change. Normal direct-plan invitations, acceptance, scheduling and completion must still work.

## Submission gates still to verify

- Test the exact uploaded TestFlight build against the deployed backend on physical iPhone/iPad and cellular data.
- Correct App Store privacy labels for stored messages and account-associated content, identifiers and analytics linkage. Optional collection does not automatically exempt analytics from disclosure; retained historical analytics also matters.
- Prove that reports reach a monitored destination and the operator can remove content and suspend abusive accounts. Repository tests do not establish a functioning live moderation operation.
- Provide Apple's requested physical-device recording of terms agreement, reporting and blocking, alongside working review credentials and navigation instructions.
- Verify the final age-rating questionnaire, privacy policy, support contact and trader-status declaration. Earlier screenshots do not establish their current values.

## Primary sources

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple account deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Apple privacy disclosure rules](https://developer.apple.com/app-store/app-privacy-details/)

These fixes reduce the identified risks; they do not guarantee approval.
