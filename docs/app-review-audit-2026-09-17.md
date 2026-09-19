# App Review audit — 17 September 2026

**Follow-up:** the user subsequently authorised fixes. See [implemented fixes, deployment order and manual tests](app-review-fixes-2026-09-17.md). The findings below preserve the original audit state; its line numbers and “not changed” verification note describe that earlier review, not the current working tree.

Scope: static review of the Flutter app and Express backend, focused automated checks, and a browser check of the published privacy policy. Production database migrations, deployed Firestore rules, SMTP delivery and the submitted device build were not verified. Findings refer to the local repositories; an issue in local configuration is not proof that the same configuration is deployed.

## Fix before submission

### 1. Chat read permissions are too broad — high privacy risk

`firestore.rules:13`, `:22`, `:32` allow any authenticated account to read conversations, messages and member documents. There is no membership condition, and `read` also permits listing conversations. Keeping a conversation ID out of the UI does not protect it.

Restrict reads to the authenticated conversation participants using a trusted mapping between Firebase UIDs and the Postgres user IDs. Keep client writes disabled. Verify with the Firebase emulator that a third account cannot list or read another pair's chat or member data. The backend Admin SDK bypasses Firestore rules, so the next finding must be fixed separately.

The rules also omit `watchRequests`, although `lib/features/social/data/chat_service.dart:148` reads that subcollection. With exactly these rules deployed, that read is denied. Add participant-scoped rules for the collections the app actually uses, or move those reads through authenticated backend endpoints.

### 2. Messaging endpoints trust the supplied acting-user ID — high privacy and impersonation risk

`FlixieBE/src/routes/messagingRoutes.routes.ts` accepts `userId`, `senderId`, `creatorId` and `requesterId` from request bodies/queries. Its mounted authentication middleware verifies a Firebase token, but this router does not bind those IDs to the token owner. `MessagingService.assertMember` at line 1780 checks membership of the supplied ID rather than the authenticated caller.

For example, `GET /conversations?userId=...` can request another account's conversation list, and message creation can claim another member as sender. Derive acting identity from the token and reject mismatches throughout this router. Test using two authorized test accounts and a separate outsider account. This is a code-confirmed authorization gap, not a claim that production data has been accessed.

### 3. Objectionable-text filtering misses reachable publishing paths — direct Guideline 1.2 risk

Ordinary reviews and chat messages call the moderation service, but these paths do not:

- Profile creation/updates: `FlixieBE/src/services/usersService.ts:1252`, `:1319`, `:1335`. Username validation exists, but bios and names do not use the general content filter. The bio is editable in Settings.
- Watch Plan completion reviews: `FlixieBE/src/services/messagingService.ts:906` checks length, then writes the review, including to `movieReview` at line 2105. `groupService.ts:777` has the same missing filter for completion text.
- List creation/renaming: `usersService.ts:435` and `:493` validate names and duplicates but do not moderate names, including lists with shared visibility.
- Watch Plan location labels and several secondary message fields need the same coverage review.
- The image-message endpoint remains enabled at `messagingService.ts:1388`; neither its caption nor image content is moderated. No image-upload action was found in the app's current chat UI, so disable this unused endpoint or implement the appropriate protections before exposing it.

Run the same moderation policy before every relevant write, including create, update and completion/import paths that publish content. Test an ordinary accepted phrase and a phrase already rejected by the main review form through each path.

### 4. Blocking still allows group notifications and recap content — direct Guideline 1.2 risk

`FlixieBE/src/services/messagingService.ts:390` checks blocks only for direct text messages. The group branch still increments unread counts and sends the message preview to every other member at lines 414–426. `pushDeliveryService.ts` does not filter blocked sender/recipient pairs.

The chat UI hides blocked messages, but the recipient can still receive their text in a push notification. `lib/features/watch_plans/presentation/widgets/group_plan/group_watch_plan_recap.dart:262` also displays completion text without a blocked-user check or a report action on that text.

Filter notifications, unread counts and relevant previews per recipient; hide blocked content consistently and make recap text reportable. Verify with two accounts in a shared group: after blocking, send a new group message while the recipient app is backgrounded and inspect both notifications and the completed-plan recap.

### 5. Analytics contradicts the privacy policy and the shown privacy labels

The published policy's Analytics section says watch history is not sent and analytics is not linked to the Flixie account. However:

- `lib/core/analytics/flixie_analytics.dart:299` emits `watch_logged` with a movie/show `content_id`.
- The same code includes `watch_plan_id`; real backend plan IDs are supplied, for example, by `watch_requests_screen.dart:663`.
- Plan IDs can be associated with participants in the backend. Disabling IDFV and omitting Firebase `setUserId` do not remove this explicit connection.

Choose the intended data practice: remove account-resolvable IDs and any watched-title events inconsistent with the policy, or accurately disclose the actual events and account linkage. Opt-in analytics still needs disclosure. Reassess linkage after any changes; removing plan IDs alone is not a blanket guarantee of anonymization.

The App Store Connect screenshots also omit Emails or Text Messages despite stored in-app chat, and mark Other User Content unlinked despite account-associated reviews and profile content. FCM tokens are associated with accounts for notifications. Check each privacy-label answer against actual collection and use.

Production request logging in `FlixieBE/src/server.ts:24` includes the whole request URL, including search queries. Remove/redact query strings unless their retention is intentional and covered by the privacy disclosures.

### 6. Account deletion can get stuck after a partial failure

`FlixieBE/src/controllers/usersController.ts:180` deletes messaging data, then the Postgres profile, then Firebase Authentication. If the last step fails, the profile is already gone but the login may remain. A retry reaches the missing-user response at line 171 rather than finishing the authentication deletion; the ownership middleware may also reject it once the profile is gone.

Make deletion retryable across the three systems, using the verified identity even when a prior attempt already removed the profile. Test an injected Firebase deletion failure, then retry and verify that the login and associated active data are gone. A successful ordinary deletion does not cover this failure case.

## Verify operationally before submitting

- **Report delivery:** Reports are saved, but `safetyReportEmailService.ts:37` skips email if SMTP is unconfigured. Sending failures are logged without a durable retry at `safetyRoutes.routes.ts:85`. Submit a test report from a test account and confirm a moderator actually receives and can act on it. A monitored database queue is also valid; email itself is not an Apple requirement. Apple does require timely responses.
- **Terms deployment and older clients:** New signup requires `termsAccepted: true` and creates user-linked acceptance. Existing-user gating is implemented in the app, but the backend has no general terms gate on content writes. Existing/older clients can still write without current acceptance. Enforce acceptance on relevant backend operations and verify deployment of the acceptance migration before shipping the app that depends on it.
- **Release configuration:** The API base URL defaults to localhost if the build value is omitted. The iOS workflow supplies the API value, but the README's plain build command does not. Verify the actual archive against production on cellular data. `Rate Flixie` requires `FLIXIE_APP_STORE_ID`, which the checked-in iOS workflow does not include; verify the final build has it.
- **App Review package:** Supply the requested physical-device recording of agreement, report and block, a working review account and clear navigation steps. Confirm the privacy labels, age-rating questionnaire's UGC/messaging answers and trader-status declaration. The screenshots alone do not establish the final submitted answers.
- **Device testing:** Exercise signup, existing-user agreement, report, block, deletion, calendar save/cancel and photo saving on iPhone and iPad; include landscape, larger text and denied permissions. Several settings sheets still omit root-navigator/safe-area options, so inspect their controls against the bottom navigation and system chrome.

## Cleared or lower priority

- The public privacy-policy URL renders successfully and provides contact/deletion information; its analytics wording needs reconciliation as described above.
- The installed calendar plugin 3.1.1 presents Apple's event editor without requesting calendar access on iOS 17+. The older plist permission key is used for older iOS; the missing write-only key is not a confirmed defect for this implementation.
- Ordinary movie/show reviews, basic chat text and group metadata have moderation checks. Terms, report, block and in-app deletion entry points exist.
- TMDB attribution and its disclaimer are present. No payment or third-party-login flow requiring a separate Apple purchase/login assessment was found in the paths reviewed.
- The private LAN exception in `ios/Runner/Info.plist:58` is development configuration worth removing from release, but its mere presence is not evidence of an App Review rejection or that production traffic is insecure.

## Verification performed

- Backend TypeScript check passed.
- 32 focused backend tests passed: moderation, group moderation, ownership middleware and user-input validation.
- Flutter analysis found no errors or warnings, but returned three informational `prefer_const_constructors` notices in `test/notification_profile_badges_test.dart`.
- Selected Flutter tests could not start: the `objective_c` native build hook failed to resolve the Apple SDK. The machine also reports an unaccepted Xcode licence. No iOS archive or physical-device verification was completed during this audit.
- Application code, cloud configuration and App Store metadata were not changed by this review.

## Reference requirements

- [Apple Guideline 1.2: user-generated content](https://developer.apple.com/app-store/review/guidelines/#user-generated-content)
- [Apple App Privacy Details: linkage, messaging and opt-in collection](https://developer.apple.com/app-store/app-privacy-details/)
- [Firebase: security-rule conditions](https://firebase.google.com/docs/firestore/security/rules-conditions)
- [Apple: calendar write-only permission and event-editor exception](https://developer.apple.com/documentation/bundleresources/information-property-list/nscalendarswriteonlyaccessusagedescription)
- [Apple: trader-status declaration](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)
- [Flixie published privacy policy](https://www.flixie.co.uk/privacy)
