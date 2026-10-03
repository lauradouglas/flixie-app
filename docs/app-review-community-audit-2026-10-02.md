# Community, moderation and privacy submission review

Reviewed 2 October 2026. **Recommendation: hold the next submission until the locally implemented fixes are deployed and the privacy and production verification below are complete.** This is a code and focused-test audit, not a guarantee of App Review approval.

Scope: current Flutter app, backend routes and policy helpers, admin dashboard report actions, schema deletion relations, and the published privacy policy. The uploaded IPA, production database/rules, operational inbox and App Store Connect declarations were not inspected. No production data, reports, emails, account access or deployments were changed.

## Findings requiring action

### 1. High: community text filtering could be bypassed — fixed locally

`../FlixieBE/src/middleware/moderateUserText.ts` exempted any request whose entire original URL contained `/library-import`. The query string was included, so a community discussion/reply request could add that text as a query value and skip the moderation middleware. The discussion/reply routes rely on this middleware for their text filtering.

Restricted the exception to POST requests to the exact `/users/me/library-import/resolve` and `/users/me/library-import/commit` paths, excluding query text. Added regression cases for community discussions, public replies, profile writes, similarly named paths, and the legitimate import exemption. All 13 moderation tests and 17 build-70 compatibility tests pass. No schema or request/response contract changed. **The backend fix must be deployed before submission; this audit did not deploy it.**

### 2. High: content-removal workflow — implemented locally

Added an explicit Admin → Reports → Review removal action for movie/show reviews, public personal lists, Around Flixie replies, friends activity comments, community discussions and discussion replies. The operator sees the actual current content, supplies an audit reason and confirms removal. Server-side authorization, author validation, content fingerprint and report-status checks prevent removal based on an untrusted submitted preview or stale review. Removal, report resolution and audit recording are atomic; failed auditing rolls back removal. Suspension and ordinary report-status changes remain separate.

Reviews/lists are deleted, reply text is cleared and tombstoned, and removing a discussion also clears its replies. Related community state is removed and stored notification previews/links are scrubbed. Already-delivered push notifications and content already cached on a device cannot be recalled; fresh requests enforce removal. There is no operator restore action.

Verified all seven target types against isolated fictional records in local PostgreSQL, including direct community visibility rejection and audit/report outcomes. Focused service/route tests, admin UI tests/build, TypeScript and 17 build-70 compatibility checks passed. **API and Admin deployment plus staging/live verification remain required; no production content was changed.** See `../FlixieBE/docs/admin-dashboard.md` for the procedure and fixture commands.

### 3. Medium: published privacy policy predates communities

The live https://www.flixie.co.uk/privacy page was reachable and dated 17 September 2026. It describes general social content and visibility but does not specifically explain Around Flixie opt-in, community membership/discussions, mentions, follows, public taste-profile preferences, or the distinction between disabling review sharing and deleting separately published replies/discussions.

Prepare an updated policy and publish it before the release. Verify App Store Connect privacy declarations and age-rating answers against the actual community, messaging, moderation and analytics features. I did not inspect those declarations and cannot confirm they are correct.

Suggested additions for policy owner review (not published by this audit):

- **Community data:** Flixie stores community memberships, discussions, public replies, mentions, reactions, follows, saved posts and community notification/visibility preferences to operate its community features. Saved-post and hidden/muted-author preferences are personal controls, not public posts.
- **Around Flixie:** Enabling sharing makes existing and future film/show reviews, their ratings, and eligible public personal lists available through Around Flixie. Public reviews may also appear in relevant communities you join. Watch history, watchlists and watch plans are excluded from these public feeds. Switching sharing off stops this distribution; it does not change Friends visibility rules or erase content you separately publish as discussions or public replies.
- **Discussions and replies:** Discussions and public replies are visible to eligible people browsing the community or public post, including people outside your friends. They may be published independently of the Around Flixie review-sharing setting. Delete an individual discussion/reply using its content menu. Leaving a community removes the current membership and hides member-dependent discussion content; it is not permanent deletion, and rejoining can make retained content visible again.
- **Public identity and taste:** Public interactions identify you by your username, avatar and badges. Additional bio/favourite and genre visibility is controlled by separate community profile settings. Public favourites can be used to suggest people with similar taste. Community ratings are aggregated from eligible public reviews.
- **Notifications and deletion:** Community replies, reactions and mentions may generate in-app or push notifications according to preferences. Account deletion also covers community memberships, discussions, replies and account-linked community records in active systems, subject to the existing limited safety-report retention explanation.

These are factual draft descriptions derived from the current code, not a legal sign-off. Preserve the existing policy's applicable retention, provider, contact and rights sections when updating it.

### 4. Medium: sharing-off wording overstated its scope — fixed locally

The Settings/signup control and Around Flixie settings sheet said that switching off sharing removed the user's “posts”. In fact, `visibleCommunityAuthor` requires consent for review/list posts, while `visibleSpaceAuthor` and public reply authors intentionally do not require that consent. Disabling sharing does not erase separately authored discussions or replies.

Corrected both UI explanations to distinguish review/list distribution from discussions/public replies, explain that those remain until deleted, and retain the statement that Friends sharing is unchanged. No default, saved consent or server permissions changed. This fix needs a new client build.

## Controls found and exercised

- Community settings default to false for review sharing, additional profile details and favourite genres; signup merely viewing the control does not opt anyone in. Saving failures preserve the confirmed state.
- `/community` requires authenticated identity; writes require accepted terms. Acting-user middleware prevents choosing another user's identity through request fields. Responses use `Cache-Control: no-store`.
- Review/list feeds and individual posts enforce sharing and bilateral blocks. Public lists must be PERSONAL, PUBLIC and not removed. Community review discovery also requires membership and consent. Shared profile data uses explicit selects rather than exposing emails or full user records.
- Public replies use a separate COMMUNITY audience. Friend/private comments are not reused as public replies.
- Discussions/replies require community membership to create; author deletion is scoped to the authenticated author. Posting UI identifies discussions/replies as public.
- Report/block actions exist on public posts, replies, discussions and community profiles. Backend block actions remove bilateral follows, invitations and list editing access as well as friendships. Reporting remains available without accepting new terms.
- Community text passes server-side moderation middleware. The implementation is an English profanity dictionary plus configured terms, not contextual threat/harassment detection. It is a filtering mechanism, but human moderation is still essential; do not describe it as comprehensive abuse detection.
- Reports persist in SQL before email delivery; delivery failures are retried. SMTP absence is logged and leaves reports queued. Published help/privacy pages provide flixieadmin@gmail.com. Live inbox monitoring and response practice remain unverified.
- Auth middleware verifies revoked/disabled tokens. Schema relations cascade deletion of community discussions/replies with their author; account deletion has retry handling. Full production deletion was not performed in this audit.
- Spoiler-aware thread responses withhold text until reveal, and mention notifications avoid spoiler text. Spoiler hiding is not a substitute for objectionable-content moderation.

## Verification

- Backend: 20 focused tests passed across community privacy, discussions, connections, reporting/blocking, mentions, moderation middleware, report delivery retry and admin authorization/actions. Loopback HTTP servers use mocked data/delivery; no live reports or email sent.
- Initial app audit: 45 passed, 2 failed because existing tests expected the previous `latest` default and `Reply notifications` label. Updated the interactions to current `For you` / `Replies and mentions`, retaining assertions for independent settings persistence, rollback and pagination. The longer accurate consent explanation also required the test to scroll back to the sheet close button before tapping it.
- Final affected app rerun: all 20 tests passed (community features, activity feed and sharing setting). The other initially passing safety, community-profile/space and deletion checks were unchanged. Changed Flutter files pass analysis. No full regression suite was run.

## Required release evidence

Use disposable review/staging accounts and recognisable fictional fixtures (existing local scripts cover community spaces and mentions). Do not test deletion, blocking or moderation against real users.

1. Submit one representative report and confirm it appears in the monitored moderator queue. Demonstrate the removal operation and record its audit entry; verify the target is unavailable to a second account through both feeds and a direct link.
2. Demonstrate block in both directions: posts, replies, mentions, profile discovery and attempted interactions. Suspend a disposable offender and confirm their current session cannot write.
3. With sharing off, create a review/public list: neither enters public community feeds. Opt in, verify visibility from a stranger, opt out and verify removal from fresh feed/direct-link responses. Separately publish/delete a discussion/reply and confirm the distinct behavior matches the UI explanation.
4. Delete a disposable account containing community posts, replies, mentions and memberships; verify active records and login removal. Verify relevant deployed migrations and deletion cascade relations.
5. Publish updated privacy copy; check app links, privacy disclosures and age-rating questionnaire in App Store Connect. Provide Apple a working review account and directions to Report, Block, sharing controls and Delete account.
6. Build and test the actual intended release. Recent local fixes are not evidence that uploaded build 87 or the production API contains them. Preserve supported build 70 backend compatibility.

## Sources

- Apple App Review Guidelines [1.2 User-Generated Content](https://developer.apple.com/app-store/review/guidelines/#user-generated-content): filtering, reporting with timely handling, blocking and reachable contact details.
- Apple [5.1 Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy).
- Apple [Before You Submit](https://developer.apple.com/app-store/review/guidelines/#before-you-submit).
- [Published Flixie privacy policy](https://www.flixie.co.uk/privacy), inspected during this audit.
