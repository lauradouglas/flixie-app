# App Review fixes — 17 September 2026

Implemented locally in the app and backend. This file does not confirm deployment to production or approval by Apple.

## Changes

- Chat reads require a server-managed Firebase UID → database user mapping and conversation membership. Direct client writes, identity forgery, unbounded conversation queries and reads during deletion are denied.
- Messaging API actor IDs must match the verified token owner. Expiring a conversation's plans also checks membership. Existing and new clients receive chat identity mappings at signup/login; the updated app additionally checks before opening Firestore streams.
- Profile names/bios, list names, Watch Plan reviews/messages/locations and nested publishing payloads use the objectionable-text filter. The unused, unmoderated image-message endpoint is disabled.
- Blocks in either direction suppress message/Watch Plan notification delivery. Blocked messages do not add group-message unread counts; blocked authors' previews and recap reviews are hidden. Recap reviews have Report and Block actions. Chats and recaps wait for the block list before displaying content.
- Backend content writes require current user-linked terms acceptance. Signup, agreement, reporting/blocking and account deletion remain available as appropriate. A legacy account without acceptance cannot bypass this by using an older client.
- Analytics drops backend Watch Plan IDs and all catalogue/person IDs from every event, so events cannot directly identify the titles opened, rated or watched. Request logs omit query strings. Analytics consent buttons have equal widths and reflow with larger text.
- Account deletion has durable progress, a concurrency lease and automatic retries. Firestore cleanup includes conversations the user already left. Failed message cleanup cannot remove the membership needed for a retry; response deletion and count updates are atomic.
- Saved safety reports are retried automatically when email delivery fails. Delivery receipts contain no report text or contact details. Reports remain in the database if SMTP is unavailable. Email delivery is at least once, so a crash immediately after SMTP acceptance can produce a duplicate.
- iOS release builds reject a missing, non-HTTPS or local API URL. Removed the private LAN transport exception, supplied the App Store listing ID and added safe-area/root-navigator settings to settings sheets.

## Deployment order

1. Confirm the target Firebase project and database. Deploy the new Firestore **indexes first** and wait for them to become ready. Both repos now reference `firestore.indexes.json` from `firebase.json`. New collection-group indexes cover `messages.senderId`, `watchRequests.createdBy` and `responses.userId`. They support deletion of content from former conversations. Do not approve deletion of unrelated live indexes if Firebase proposes it; merge those into the checked-in configuration first.
2. Deploy the existing `20260916220000_user_terms_acceptance` database migration if it is not already applied, then deploy this backend. Do not invent acceptance for legacy users. Keep the API process running so its minute-by-minute deletion/report retry workers can run.
3. Configure `SMTP_HOST`, `SMTP_USER`, `SMTP_PASSWORD` and the intended `SAFETY_REPORT_EMAIL`; set port/from/TLS options as needed. Monitor the saved report queue and worker failures. Verify delivery using an authorised test report to a controlled mailbox.
4. Backfill chat identities using the deployed backend's environment. Inspect the dry-run count, then apply. No database/Firebase credentials should be copied into commands or review notes:

   ```sh
   NODE_ENV=production node dist/scripts/backfillChatIdentities.js
   NODE_ENV=production node dist/scripts/backfillChatIdentities.js --apply
   ```

   The backfill skips accounts already being deleted. Successful signup/login also maintains mappings, and updated clients retry when opening chat.
5. Deploy the matching Firestore **rules after the backfill**. Do not deploy restrictive rules alone: accounts without mappings would lose chat access. Check both a pre-existing account and a new account immediately after rollout.
6. Build/upload the app with the real HTTPS `API_BASE_URL`. Check that the final archive connects on cellular data. No production deployment, migration, backfill or App Store submission was performed by this task.

## Manual tests on the final build

Use three test accounts: Alice and Bob are friends in a shared group; Charlie is an outsider. Use a physical iPhone and iPad, including a narrow/landscape layout and larger text.

1. **New account:** leave agreement unchecked; creation must be prevented. Open Read Terms and check the zero-tolerance clauses. Opening/closing terms must not tick agreement. Agree, create an account, sign out and sign back in; current acceptance must persist against the account. Verify on a second device.
2. **Existing account:** use a test account without current acceptance. On login it must be asked once; cancellation/failure must not unlock content creation. Agree and log in again. Confirm the backend rejects a content-write request without current acceptance. Deletion and reporting must remain possible.
3. **Text moderation:** try the same rejected test phrase through profile name/bio, list name, group metadata, chat, Watch Plan message/location and completion review. Each must reject the write with a useful error; ordinary text must still save.
4. **Private chats:** Alice and Bob can load messages, members and plans. Charlie cannot access their conversation through the API or Firestore, even with its ID. Forged acting-user IDs must be rejected. A valid member's normal conversation list must still load.
5. **Block/report:** report Bob's message and recap review. Confirm the report reaches the monitored queue/mailbox. Block Bob, then have Bob send a group message and plan update while Alice is backgrounded. Alice must receive no notification from Bob, no new message unread increment and no blocked preview/review. An unblocked friend's message must still arrive. Unblock and check normal delivery resumes.
6. **Deletion:** delete a disposable account that has direct/group messages, plan responses and content in a group it previously left. Check removal from the database, Firebase Authentication and Firestore. In staging, inject a transient failure and confirm the retry finishes even after closing the app. Old tokens must no longer authenticate once deletion completes.
7. **Analytics:** decline; verify collection stays disabled. Allow and log a viewing/plan event; verify no `watch_plan_id`, `content_id`, `parent_content_id` or `person_id`. Turn analytics off again. Do not assume this erases previously collected events.
8. **iOS controls:** Settings sheets, Read Terms, reporting, calendar save/cancel, photo saving and Rate Flixie must work. Test denied permissions and large text; no controls should hide under navigation/system chrome.

## App Store Connect still needs an accurate declaration

- Stored chat belongs under Emails or Text Messages; account-associated reviews/profile content must be marked linked. Recheck Device ID purposes for analytics and account-associated notification tokens, plus all other SDK data actually collected.
- Optional analytics does not automatically make its data exempt from disclosure. Removing plan IDs does not make Firebase app-instance data anonymous under Apple's device-linkage definition. Check the actual configuration against [Apple's privacy guidance](https://developer.apple.com/app-store/app-privacy-details/).
- Historical analytics may still contain previously emitted IDs. The privacy policy and declaration must account for retained historical data; this code change does not delete it. Catalogue/person IDs are also removed from discovery/recommendation events going forward.
- Confirm UGC/messaging answers in the age-rating questionnaire and complete trader status where applicable. Screenshots of the setup page do not establish a completed declaration.
- Supply Apple's requested physical-device recording of agreement, reporting and blocking. Include a working review account, navigation instructions and a recording link in App Review Information → Notes, and attach/link it in the review reply.

## Verification

- All 306 backend tests passed, including account-deletion retries, cleanup from former conversations, actor identity checks, moderation and report-delivery retries.
- 45 focused Flutter tests passed: safety state, recap/golden layouts, analytics, terms, report-sheet large-text layout and signup/legacy acceptance.
- Firestore emulator passed member reads, outsider/anonymous denial, constrained query success, forged/unbounded query denial, denied client writes and deletion access revocation. Both rule files are identical.
- TypeScript, release API URL checks and iOS plist/project syntax passed. Flutter analysis reports no errors or warnings; three existing `prefer_const_constructors` notices remain in an unrelated test.
- Java 21 was installed alongside Java 17. Xcode's licence issue was resolved and Flutter native tests could run. No physical-device tests or iOS archive were performed in this task.
