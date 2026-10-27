# Flixie TestFlight checklist — Pip, referrals and guest diary

Prepared 25 October 2026. TestFlight **2.0.6 (134)** is VALID and available for
internal testing, with tester notes attached. Backend rollout verification is
recorded below. Use two consenting tester accounts, A and B.

## Local automated evidence

25 October 2026: added and passed the real two-person backend/PostgreSQL journey.
Run `npm run test:referrals:e2e:local` in FlixieBE before release. It exercises
production HTTP routers and real SQL with isolated fictional identities, checks
both Film Friend and Cinema Club awards/retries, and removes its fixture rows.
Firebase login, OS link delivery, mobile signup screens and physical icon
switching still require the device checks below. See FlixieBE/TESTING.md.

## Before the TestFlight release

- [x] Production backend deployed with all four additive migrations, including Pip collection/RLS, profile highlights and legacy referral aliases. Database backup retained. All 761 backend tests passed; 45 long codes shortened and legacy-link readback passed.
- [ ] Verify authenticated GET/PATCH `/users/me/pip-collection` on that environment. Older clients must continue to work. No production fixture seeding.
- [x] Release checks and signed production entitlements pass; archive includes PipPeeksIn for iPhone/iPad. Source hashes match the build inputs.
- [x] TestFlight **2.0.6 (134)**: Apple VALID / IN_BETA_TESTING at 22:25 London; tester notes attached.

## Signed-out discovery and diary

- [ ] Open signed out: clear Home benefit, header signup, Find a film or show, films-only Trending, correctly proportioned posters.
- [ ] Browse Alien or Spider-Man, open title details and find where to watch; Flixie must not imply it streams films.
- [ ] Add several titles to the guest watchlist; confirm all posters stay together and signup copy does not split the grid.
- [ ] Log a film with a date, optional rating and a distinctive private note before signup. Close/reopen the app and check the device draft remains.
- [ ] Create an account through that draft. Confirm the film, date, rating and note survive; explicitly save once without repeating the form.
- [ ] Sign into another account instead: drafts and saved account content must not leak between accounts.

## Shared film and referral

- [ ] Account A logs Alien and adds an external companion. A's own entry is saved before sharing. Cancel the share sheet: no false 'invite sent' result.
- [ ] B opens the link signed out. The film/inviter are shown, but A's private note and rating are not copied into B's form.
- [ ] B enters a different score/date/note, creates an account, and confirms the restored draft explicitly.
- [ ] Try optional connection/referral consent both ways with appropriate separate testers. Declining connection must not prevent saving the shared watch; existing attribution must not be replaced.
- [ ] Retry after a failed final save: same claimed watch, no duplicate diary entry. Expired/used links explain the problem and preserve an unsubmitted draft for a separate entry.
- [ ] Referral page clearly separates joins and Film Friend earned. Film Friend still depends on setup completion, not the new cosmetic rule.

## Unlock Cinema Club

- [ ] Use an account without an existing qualifying shared watch: Classic Pip is available; Cinema Club is shown as locked only after a successful ownership check.
- [ ] A saves a shared-film entry alone: no cosmetic unlock yet. Sending/opening a link or signup alone must not unlock it.
- [ ] B confirms their own linked film entry: both A and B receive Cinema Club Pip and Pip peeks in. Different scores, or no score, are valid.
- [ ] A returns to the app or opens My Pip to refresh. B sees the reward after their save. Neither cosmetic is applied automatically.
- [ ] Existing qualifying linked film watches also count. Existing friends can qualify without a new referral. The current implementation recognises direct/shared-viewing requests (including external-person invites); separate group-plan records are outside this release.
- [ ] Dismiss the celebration: collection stays available in Settings. Switch outfit or edit the diary later: earned ownership remains.

## Choose and see your Pip

- [ ] No My Pip row appears above phone tabs or in tablet navigation; all destinations remain available.
- [ ] Open Settings → Personalisation → My Pip; verify the collection and active selection. Appearance is also in the top section; optional sign-in buttons are stacked below Preferences.
- [ ] Preview Cinema Club. Check the bone/cream F patch and clean eye outlines. Cancel: active Pip stays unchanged.
- [ ] Use this Pip: selected art changes in the original diary header and on the shared-watch saved screen. Original weekly diary/calendar remains usable.
- [ ] Your profile photo and earned border remain unchanged. Other users' avatars are unaffected.
- [ ] Switch to Classic and back. Restart/sign in on another device: the server-saved outfit returns for this account.
- [ ] Interrupt outfit saving: selection is retained for retry; repeated taps do not create concurrent saves.

## App icon — test on a physical iPhone/iPad

- [ ] Preview Pip peeks in, then Cancel: Home Screen icon stays unchanged.
- [ ] Use this icon: accept any system feedback and check the actual Home Screen icon. It should be opaque, crisp and correctly masked.
- [ ] Switch back to Classic. App-icon choice is device-local and independent of the selected outfit.
- [ ] Existing Founder/First 100 icons still work for eligible members.
- [ ] Locked accounts cannot apply Pip peeks in. Sign out restores the default; after switching accounts, verify access against the new account's collection.
- [ ] On unsupported platforms, show an explanation without a working apply button. Ownership remains intact.
- [ ] If the native icon change fails, show a useful error and keep the previous icon and proposed selection for retry.

## Recovery and accessibility

- [ ] Disconnect after loading a collection: keep the last saved outfit. A failed refresh must not say the reward was lost or must be earned again.
- [ ] Open an uncached account offline: show 'check/refresh' rather than asserting it is locked.
- [ ] Change accounts during loading/saving: no stale selection or reward from the previous account appears.
- [ ] Test smallest phone, landscape, tablet and larger system text. Read all labels, scroll all sheets, and reach Save/Cancel/Close without clipped controls.
- [ ] VoiceOver: My Pip has a clear label; choices expose selection; sheets have usable reading order. Check contrast in both themes.

## Referral visibility and signup choices

- [ ] With a verified, locked Cinema Club account, save a new solo Alien watch. See the contextual invitation with Cinema Club Pip. Not now keeps the saved watch and no further prompt appears within seven days on that device (maximum three offers per account/device).
- [ ] Edits, shared/companion logs and already-unlocked accounts do not trigger that promotion. Adding a companion preserves the same entry, date, score and private notes; failed writes retain the choice for retry.
- [ ] Empty Social Activity/People views offer Invite a friend. Pending People requests remain visible without a large invitation above them.
- [ ] Initial signup shows Around Flixie sharing on, with the public scope explained. Turn it off, finish signup and confirm it stays off in provider setup and Settings.
- [ ] Provider setup offers watchlist subscription availability alerts. Nothing enables them or asks OS permission until explicitly chosen and saved. Country/services save before alert opt-in; failed alert writes retain the choice for retry.
- [ ] Declining phone permission still allows setup and inbox alerts. On a physical device, allow permission and verify availability pushes with a controlled eligible title/provider change.
- [ ] Open Settings on a slower connection: sharing/alert/privacy controls show a neutral loading state, then the confirmed value, with no temporary off selection. Failed loads offer retry instead of appearing off.

Native automated invitation retry passed on 25 October 2026:
`build/ios_results_1792964631909.xcresult`. Widget/contract checks cover frequency,
explicit opt-in and sharing opt-out; physical push delivery remains a device check.

## Report an issue

Record build, device, account A/B, steps, expected/actual result and a screenshot.
For retries, note whether the action eventually saved and whether any duplicate
appeared. Never include passwords, invite tokens or private notes in public reports.

Other Pip designs and earning rules remain a later discussion; this release adds
only Classic/Cinema Club outfit selection and the selected Pip peeks in reward.

25 October 2026 verification update: 99 focused regression tests passed; the final
47-check batch after the compact provider copy and Social routing change also
passed. The dedicated native saved-film invitation retry passed. Small-phone
(320px at 200% text), phone (390px) and tablet (834px at 150% text) renders were
checked. `flutter analyze lib` is clean. A full-project analysis still reports
pre-existing missing imports/classes in archived performance harnesses under
`docs/performance` and tooling lints, rather than app implementation errors.
