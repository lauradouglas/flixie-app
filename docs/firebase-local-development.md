# Local Firebase development

Daily debug builds use the named `flixie-local` Firebase app with project
`demo-flixie-local` and bucket `demo-flixie-local.appspot.com`. The bundled default
Firebase app remains available to release/profile builds. All runtime Auth,
Firestore and avatar Storage consumers select the correct app. Local mode fails
if its API or emulator hosts are non-local; it never retries against production.
Missing emulators produce local connection errors. Release builds reject an
explicit emulator flag, including in the iOS archive validation script.

## One-command daily start

Start Docker Desktop, then from the app checkout:

```sh
scripts/dev.sh -d <ios-simulator-id>
# Android:
FLIXIE_ANDROID_EMULATOR=true scripts/dev.sh -d <android-device-id>
```

Omit `-d` to let Flutter select a device. The launcher starts the existing
`postgresql` container when port 5432 is not listening (override its name using
`FLIXIE_POSTGRES_CONTAINER`), starts/reuses Firebase, restores the local fixture
and cached original avatars, waits for the backend's local-only readiness marker,
and runs the debug app. Docker Desktop, dependencies and the configured backend
`.env.local` remain prerequisites; it does not migrate/reset the database.

`q` or Ctrl-C exits Flutter and stops only the Firebase/backend processes this
launcher started. Firebase exports state on shutdown. Reused services and the
shared database remain running. Logs are in `.local/firebase/logs/` (ignored).
Occupied ports with an unrecognised stack fail clearly instead of being killed.
This launcher rejects profile/release and custom Dart defines; use the existing
release tooling or individual scripts for intentional custom configurations.

## VS Code Run button

Choose **flixie-app (Mobile - Local Firebase)** in Run and Debug (use the Android
Emulator or Chrome/Web local entry for those targets), select your device, then
press Run/F5. Each local launch has `preLaunchTask: Flixie: start local services`.
The task calls the same launcher in `--services-only` mode. Its background matcher
waits for `FLIXIE_LOCAL_READY`, printed only after PostgreSQL, Firebase, the local
seed/cached avatars and the backend readiness check succeed. VS Code then launches
Flutter itself, keeping breakpoints, hot reload and its normal Stop button.

Stopping the debugger leaves the shared services task running for the next Run.
To end it, use **Tasks: Terminate Task → Flixie: start local services**. Termination
stops only owned services and lets Firebase export; reused services and PostgreSQL
stay running. Docker Desktop must already be open. Production profile launch has
no local prelaunch task.

Verified: seven focused launcher/configuration checks pass; the actual services
mode reached its readiness marker while reusing the existing local stack. This
checks the task command and launch wiring; the VS Code UI button itself was not
clicked in that verification.

## Individual commands

1. Start Docker Desktop and the existing `postgresql` container. The backend's
   `.env.local` must retain `USE_LOCAL_DATABASE=true` and its existing loopback
   `LOCAL_DATABASE_URL`. Do not reset/migrate/import a database just to run this.
2. From the app checkout, run `scripts/start-firebase-local.sh`. Java 21 and the
   existing Firebase CLI are required. It starts loopback Auth (9099), Firestore
   (8185), Storage (9199) and the UI (4000). The CLI may download official emulator
   components on first use. This config uses the app's real `firestore.rules` and
   indexes. `scripts/local-storage.rules` is emulator-only and permits signed-in
   reads; the local backend/Admin SDK supplies avatars. It is not a production
   Storage rules deployment.
3. From `../FlixieBE`, run `npm run seed:firebase:local`, then `npm run dev`.
   Development Firebase requires the demo project/bucket and all three local
   emulator hosts. The updated `.env.example` lists the exact values. Cloud
   service-account and application-default credential files are rejected in
   development. Production still reads deployment secrets and the original bucket.
4. From the app checkout, run `scripts/run-local.sh -d <ios-simulator-id>`.
   For Android use `FLIXIE_ANDROID_EMULATOR=true scripts/run-local.sh -d <id>`;
   this selects `10.0.2.2` for the API and Firebase. Ordinary `flutter run` also
   defaults debug Firebase to local. Its default API localhost must be overridden
   to `http://10.0.2.2:3000` on Android. The launch script handles both together.

For a physical Android device, use adb reverse for ports 3000/9099/8185/9199 and
run with host `127.0.0.1`; this is a manual device workflow. Physical iOS/LAN access
is intentionally not enabled by this loopback configuration. Do not bind the
unauthenticated emulator administrative interfaces to a public/LAN address.

## Dougasaur

Sign in with username **dougasaur** and local-only password **FlixieLocal1!**.
The seed reuses the existing LOCAL PostgreSQL profile and external identity ID;
it does not fetch a production Firebase user, password, messages or uploaded
media, and does not change the existing local profile/library/badges. Its email
comes from that already-local profile so username sign-in works unchanged.
If the local profile is absent, seeding refuses rather than silently importing it.
The seed preserves existing Auth sessions on ordinary reruns. To deliberately
restore the fixture password, use `npm run seed:firebase:local -- --reset-password`
(this signs existing local sessions out).

The seed adds one explicitly fictional `dev_firebase_robin` account/friend and
one Alien/The Odyssey chat if absent. It leaves existing messages/unread state
alone on reruns. Local Storage is populated with repository Pip artwork as
placeholder images at the curated avatar paths (originals and icons), preserving
the avatar catalogue and each profile's badge border. These placeholders are
intentionally different from the production avatar artwork and are never uploaded
to production. Existing Storage objects are not overwritten.

## What stays local

- Native Auth/Firestore/Storage use a separately named app so a retained production
  Firebase login is not reused. Local Firestore persistence is disabled to avoid
  stale results after emulator resets.
- Username password verification uses the local Auth REST endpoint. Backend token
  verification and Firestore membership rules remain active.
- Local mode skips FCM registration/sending and cloud analytics destinations; FCM
  has no local emulator. Production App Check/FCM configuration stays unchanged.
- Local backend background safety/delivery workers are not started, avoiding
  processing old local fixture queues against external delivery services.
- Avatar download URLs returned by the local backend map to the Android host when
  needed. Production Storage URLs cannot bypass the local avatar resolver.

The movie catalogue may still reference normal TMDB artwork and other external
services; emulator mode isolates Firebase, not every service Flixie integrates.
Native Google/Apple provider flows and real push delivery require separate explicit
integration checks; use the seeded email/password login for ordinary local work.

## Persistence and verification

Stop the emulator terminal with Ctrl-C for automatic export to
`.local/firebase/data`; the next startup imports it. This directory is ignored
because it contains local Auth identities/password hashes and fixture data. Do not
commit it. Use the seed to restore the known fixture after an empty start.

From the backend checkout, `node scripts/verify-firebase-local.cjs` verifies
username/password login, the token's demo project audience, authenticated backend
identity readiness, allowed member chat access, denied unauthenticated chat access
and a local avatar download. It uses only loopback URLs and never prints tokens.

## Verification completed on 21 October 2026

Focused Flutter auth/social-auth/avatar/environment tests, backend environment/auth/
username/push tests, analysis, backend typecheck and iOS release-guard checks pass.
The local HTTP smoke passed, the seed reran with zero Storage overwrites, and a
local export was saved. The native Flixie Review Patrol simulator build/startup
succeeded; connected Flutter tooling reported no runtime errors and the widget
inspector confirmed the development banner and guest screen. The dummy API-key
format initially caused an iOS SDK startup exception; fixed to a valid-format
fictional key and covered by a configuration regression. No production credential
was used to fix it.

Manual simulator verification also passed: signed in as Dougasaur, opened the
fictional Robin conversation, read the seeded welcome, sent “local test” and saw
it in the persisted conversation preview. Home/profile/chat avatars and the
avatar picker rendered the repository-owned placeholder artwork from local
Storage; saving the existing Goldie selection showed “Profile avatar updated”.
The canonical DM seed ID was corrected to match the backend routing. The local
backend was restarted with access to emulator ports after the initial chat load
stalled. Connected Flutter tooling reported no runtime errors afterward.

A focused Patrol regression was added and analyzed; its native build was stopped
before execution because a separate physical-device Xcode build was using this
checkout. The manual check above ran against the normal development app. Real
push/Google/Apple flows remain outside these checks.

## Original avatars offline

The 42 original avatars and their 42 small WebP icons are cached under
`.local/firebase/avatar-assets/` (ignored). The normal Firebase seed prefers this
cache and seeds placeholders only when an original is absent. It never fetches
production Storage. The emulator export also preserves uploaded originals.

From the backend, run `npm run seed:avatars:local` to repopulate a fresh emulator
from the cache. To populate/refresh the cache from the owner's original artwork:

```sh
npm run seed:avatars:local -- --source /Users/lauradouglas/Documents/FLIXIE/flixie_avatars
```

The source uses full PNGs at its root and WebPs under `small_avatars/`. Only
curated catalogue paths are copied. The importer validates the complete source,
refuses a cloud destination, and compares SHA-256 metadata to skip unchanged
objects. Original images replace earlier local placeholders once. Ordinary app
runs and reseeding use local files/emulators; no production downloads occur.

Verified on 21 October: 84 originals copied from local Documents (3,529,262
bytes), emulator import succeeded, repeat import made zero writes. Simulator
avatar picker visibly rendered distinct original artwork after hot restart.
Focused importer regression and backend typecheck passed.

## Unified launcher verification — 21 October 2026

`scripts/dev.sh -d 3A372E2A-A991-4C81-BD29-E007555B5A01` reused the running
emulators/backend, seeded local data and launched the debug app successfully in
the dedicated simulator. The home screen showed signed-in Dougasaur and Goldie.
Five focused launcher tests cover readiness, startup ordering, reuse, release
override rejection and ownership-based cleanup; three backend checks cover the
local readiness marker and fixture account/session preservation. Backend
typecheck passed. The seed now preserves existing Auth sessions unless an
explicit local fixture password reset is requested.


## Chat pagination fixtures

The daily seed also supplies 65 older messages in the Robin DM and the private
fictional **Local Alien & Odyssey Club** group. Open either from Messages and
scroll up to test the 20-message history pages. Message numbers and repeated
timestamps make boundaries visible. The seed is guarded to the existing local
PostgreSQL/demo Firebase targets, adds only missing fixture messages and preserves
existing chat activity.
