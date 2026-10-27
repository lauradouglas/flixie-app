# Pip collection implementation

User-approved 25 October 2026. Feature lives in `lib/features/pip`; backend
`pipCollectionService` and authenticated `/users/me/pip-collection` own unlocks and
outfit selection. AppIconService owns serialised native changes; iOS adds the
PipPeeksIn asset catalogue without replacing existing alternate icons.

A real linked film viewing with two distinct participants' confirmed, nonremoved,
matching film entries qualifies. No rating/review or referral signup requirement.
Existing direct/shared-viewing requests are reconciled on collection load, including
external-watch links and historical watches. Separate group-plan records are not
part of this rule implementation. Collection reads award both participants once,
using database uniqueness and a null-only unlock update. Later edits do not revoke
ownership. API identity comes from the authenticated external ID, not client IDs.

The additive users.PipCollection table stores permanent unlock, active outfit and
acknowledged celebration, cascading on account deletion. It does not expose private
watch notes, names or ratings. Deploy its migration before the new backend.
No production migration, backend deployment or TestFlight upload was performed.
Local history has older drift; only this new migration was applied locally rather
than trying to reconcile unrelated migrations.

My Pip lives in the Personalisation section at the top of Settings; phone tabs and tablet navigation have no extra Pip row.
It uses the existing diary header, preserving the calendar and avatar borders.
Settings exposes the same bounded root/safe-area sheet. Choices preview before
explicit apply; cancel and errors retain the current selection. Account-scoped
cache preserves the last look offline, while server verification gates new reward
selection. Activity changes, app resume and opening My Pip refresh ownership.
Native icon success is required before reporting it changed; unsupported devices
retain reward ownership with no apply action.

Local fictional fixtures: `../FlixieBE/scripts/seed-dev-referral-watch.ts` creates
Casey/Jamie independent Alien entries (qualifying) and Sophie (locked), guarded to
local PostgreSQL, rerunnable without overwriting edits. Calling getPipCollection
for the fictional accounts confirmed both unlock and locked states in the real DB.

Testing checklist: `docs/testing/pip-testflight-checklist.md`.

Validation: 37 focused Flutter checks passed across Pip state/UI, existing icon eligibility, tablet navigation, diary, referral page and external invite flows (the three render checks were rerun after a control-height fix). Thirteen focused backend tests passed, including authenticated ownership/forgery denial and external-invite regression; TypeScript typecheck passed. One dedicated native Patrol journey passed: build/ios_results_1792959730603.xcresult. The built test app lists PipPeeksIn for both iPhone and iPad, and its source icon has no alpha. The native method's physical Home Screen appearance remains on the TestFlight checklist; simulator UI retry tests use controlled method-channel failures. Final UI captures are in output/pip-implementation. Running development app was hot-restarted for provider wiring, then reloaded; no runtime errors were reported.

Row-level security is enabled by companion migration 20261025203001_pip_collection_rls. No client policies are added; trusted backend access and authenticated route ownership checks control entitlements. Both new migrations were applied only to guarded local PostgreSQL.

26 October 2026: user approved the two-Pip icon mockup. The PipPeeksIn native
alternate icon and matching collection preview now show two Pips around the
Flixie F. Identifier and entitlement behaviour are unchanged. The iOS source is
1024×1024 without alpha; installed native icons require a new build.


## OG Pip — 27 October 2026

User approved First 100 eligibility and adding the generated OG artwork as an outfit option. `OG Pip` appears in the existing My Pip outfit sheet only when the authenticated collection returns `ogUnlocked`. The backend derives that flag from the existing `EARLY_ADOPTER` badge; Founder alone is not eligibility. Forged entitlement fields and ineligible selections are rejected. No badges are assigned by collection access. Selection is saved as `og`, preserving classic/Cinema Club and account-scoped offline display. This is a companion outfit, not another native app icon.

Deploy `20261027130000_og_pip` before the backend accepting `og`; it expands the selection constraint and retains Cinema Club ownership protection. OG ownership is checked by authenticated backend badge lookup. Old app payloads default OG entitlement to false. Old builds treat unknown active outfits as Classic. Backend rollout and app release remain pending; no production data changed.

Local fixture: after the existing referral-watch seed and local migration, run `NODE_ENV=development node --env-file=.env.local -r ts-node/register scripts/seed-dev-og-pip.ts` in FlixieBE. Optional `--dry-run` checks identity without writes. Only fictional `dev_referral_casey` gets EARLY_ADOPTER; existing selection/activity is preserved. This fixture script was prepared, not run in this turn.

Validation: 11 focused Flutter tests pass, including OG visibility/save, locked accounts, parsing/cache defaults and account change; 3 backend Pip tests pass including forged/Founder-only denial; TypeScript and targeted Flutter analysis pass. Development iPad hot restart succeeded after hot reload failed. No new native icon assets or deployment.


**OG backend deployed — 27 October 2026:** User authorised migration/backend rollout after compatibility review. Isolated release `9fb4cf5b597932247ac0fec1448496393020e714` from deployed base `4d081dceec9e7c738dea31ae52661afd0114cfe2`, leaving unrelated local work out. GitHub run https://github.com/lauradouglas/FlixieBE/actions/runs/40505249656 succeeded: 763 CI tests, private database backup, only `20261027130000_og_pip` applied, then Azure deployment. Migration is atomic with 5-second lock timeout; real SQL regression preserves existing selections and Cinema Club/RLS protections. Root/health return 200 and unauthenticated Pip route 401 after deployment. Live authenticated outfit selection has not been exercised. Existing clients ignore the added entitlement field and fall back to Classic for an unknown OG outfit; no badge assignments changed. App binary release still pending. Evidence: `build/releases/backend/2026-10-27-og-pip/`.
