# Performance and repository baselines

The user requested baselines across the app on 6 October 2026, so each cleanup
or optimisation can be compared with evidence. Keep this record current alongside
`product-ideas.md`. Separate repository size, deterministic test observations and
profile-device measurements. Moving code does not establish a runtime speedup.

## Repository baseline

The frozen [6 October snapshot](performance/2026-10-06-repository.json) lists every
Dart file under `lib/`, its line/byte count and content hash, plus totals and the
20 largest files. It identifies the Git revision and whether the working tree
was dirty. This baseline includes the earlier Watchlist cleanup and this Movie
Detail extraction; it is not an untouched production snapshot.

Capture a new snapshot after each meaningful cleanup without replacing the old:

```sh
python3 scripts/repo-baseline.py docs/performance/YYYY-MM-DD-description.json
```

Compare file responsibilities as well as sizes: moving one giant file to another
or adding many empty forwarding layers is not a cleaner architecture. Generated
Dart files are included consistently; the JSON is a structure measurement only.

| Screen | Before this cleanup journey | Before current Movie Detail work | Current |
|---|---:|---:|---:|
| Movie Detail | 5,106 lines | 4,390 lines | 1,199 lines |
| TV Detail | 3,608 lines | 3,382 lines | 930 lines |
| Home | 2,971 lines | 2,715 lines | 1,555 lines |
| Own Profile | 2,160 lines | 2,160 lines before Profile work | 213 lines |
| Friend Profile | 2,142 lines | 2,142 lines before Friend Profile work | 279 lines |
| Watchlist | 3,670 lines | 824 lines | 824 lines |
| Social | 2,023 lines | 2,023 lines before Social work | 165 lines |
| Watch Requests | 2,048 lines | 2,048 lines before Watch Requests work | 367 lines |
| Movie List Detail | 2,115 lines | 2,115 lines before list work | 348 lines |

Earlier counts were recorded during the cleanup; they are not historical runtime
measurements. The frozen JSON is the reproducible starting point for subsequent
repository comparisons. Watchlist's earlier 822-line report preceded formatting.

## Deterministic loading/request baselines

These are fictional fixtures and fake/virtual time, not network latency, device
frame time or production account measurements. Preserve these budgets in focused
regressions when refactoring; change a budget only with an explained improvement.

| Journey / fixture | Baseline | Evidence |
|---|---|---|
| Movie Detail progressive loading | Useful title/synopsis visible at 100 ms of virtual fixture time; deliberately delayed optional work settles at 5,000 ms | `test/movie_detail_loading_test.dart` |
| Movie Detail refresh | Core content does not wait for optional sections; refresh completion does; resolved sections remain visible; old results cannot overwrite a new refresh/movie | `test/movie_detail_loading_test.dart` |
| Movie metadata across two viewers + their reviews | 3 HTTP fixture requests: 1 shared metadata read + 2 viewer-specific review reads | `test/movie_detail_cache_test.dart` |
| Movie metadata explicit refresh | 2 reads; late first completion cannot replace refreshed metadata | `test/movie_detail_cache_test.dart` |
| 400-title library update | 0 eager provider requests just from publishing the owned library | `test/watchlist_large_library_test.dart` |
| 400-title provider enrichment | 400 movie-provider fetches, at most 5 concurrent; one fixture failure leaves 399 successful results and still reaches the last title | `test/watchlist_large_library_test.dart` |
| 400-title friend recommendations, movies and TV separately | 16 batches of at most 25 + 1 transient retry = 17 requests; at most 1 active batch; early results published before the rest finish | `test/watchlist_large_library_test.dart` |
| Watchlist local search/filter/time changes | 0 additional fixture reads for already-loaded selection changes | `test/features/watchlist/watchlist_controller_test.dart` |
| TV Detail progressive loading | Summary renders while credits remain pending; refresh and stale-response protection covered; no elapsed-device-time baseline | `test/show_progressive_loading_test.dart` |
| Watchlist native paging | Earlier dedicated Flixie Patrol simulator journey passed with 400 titles; this is correctness evidence, not a scrolling benchmark | `patrol_test/watchlist_paging_test.dart` |

Movie Detail's extracted provider tabs own their state, so a tab change calls
`setState` on that section rather than the entire Movie Detail screen. This is a
verified ownership change; its frame-time impact has not been measured.

Validation of these fixture budgets and the Movie Detail extraction is recorded
in [the dated validation record](performance/2026-10-06-validation.md).

## Runtime ledger

### Group Detail cleanup — 9 October 2026

[Report and evidence](performance/2026-10-09-group-detail/README.md): header waits
for group/members instead of all four parent reads; parent conversation resolution
removed because Activity never uses it. Four initial data dependencies remain.
Concurrent parent loads coalesce. 22 focused tests pass; stale account/group
publication blocked. Source/fixture evidence only; native timing not measured.


### Home friend activity on demand — 9 October 2026

[Change and physical comparison](performance/2026-10-09-home-friend-demand/README.md):
initial hero friend reads 12 → 2; total login/root-startup HTTP 25 → 15; refreshed
resume 20 → 10. Same release iPhone/fixture lifecycle harness, 50 clean samples,
one native test passed. Median login approximately unchanged at 1.31/1.41 seconds
for 20/400 titles; no production speedup claimed. 31 focused Home tests pass.
Cards load as swiped, reuse current results and reject old account/refresh replies.


### Physical iPhone startup/login/resume — 9 October 2026

Completed on iPhone 16 Pro / iOS 27.0.1 in release mode using a separate benchmark
app and populated isolated PostgreSQL/Auth/Firestore fixtures over Wi-Fi.
[Report, raw samples and limitations](performance/2026-10-09-physical-lifecycle/README.md):
50 lifecycle observations plus 15 fresh-process launches. Median login: 1,330 /
1,419 ms for 20 / 400 titles; refreshing resume: 462 / 483 ms; throttled resume:
352 / 334 ms. One profile read for login/refresh, zero for throttled resume.
All lifecycle transport checks clean; native test passed. Fresh-process startup
uses separate Dart-entry and host-observed boundaries detailed in the report.
These establish physical fixture baselines, not production-service latency or
a speedup against earlier simulator measurements.


The [populated simulator reference](performance/2026-10-06-populated-simulator/README.md)
contains **50 completed native samples**: five selected-cache-reset/cached pairs
for Home, Movie Detail, TV Detail and Watchlist with 20/400 saved movies. Patrol
passed on the dedicated Flixie Patrol iOS 26.5 simulator, with Flutter 3.44.0 in
debug mode. The frozen repository identifies 405 Dart files / 113,024 lines, 747
fewer lines than the earlier 400-file snapshot. This is structure evidence only.

The separately named local PostgreSQL database has 722 movies, 154 shows, 518
seasons, 8,531 episodes and 42 fictional users: 6,420 watchlist rows, 4,200 ratings,
4,200 watched rows, 420 reviews and 80 friendships. Catalogue-only copying excludes
real account data. UI reads use the real API routes/services/SQL and production
provider enrichment. Firebase identity/legacy reactions are isolated; trending
transport reads the local catalogue, external cast is empty and movie streaming
offers are fictional cached fixtures. Two excluded external reads produce recorded
500s (movie recommendations and TV provider refresh); their timings do not measure
healthy live services. The raw ledger retains each endpoint's response statuses.

Timings start at **screen mount**, with an already-loaded User snapshot. They include
debug/test polling overhead, loading plus five scroll flings, RSS start/observed
peak/end and Flutter image-cache bytes. API counts exclude fixture bootstrap and
image downloads. Only named service caches and decoded-image memory are reset;
server caches, database buffers and image disk cache are retained. Home also retains
its session snapshot after the first mount: its first fresh title observation was
1,648.8 ms (one sample); its `cold` median is **not** five full-cold Home launches.

Both Watchlist sizes made 23 initial API reads in the reset condition and 2 cached
reads. The 400-film library made 46 total reset-condition reads across five flings,
enriching visible 20-title pages. This records the existing paging/cache behaviour;
it does not prove a speedup from moving files. RSS includes the engine/harness and
is measured before explicit GC, so it cannot establish retained heap or leaks.
Scenarios share one process in a fixed order; cross-screen RSS differences also
include residual state and automatic GC from earlier cases.

The [auth/lifecycle simulator reference](performance/2026-10-06-lifecycle-simulator/README.md)
adds **50 completed native samples**: five repetitions of signed-in/signed-out
app-root startup, real email Login submission, first native foreground resume and
quick subsequent resume for 20/400-film accounts. These use the native Firebase SDK
with local demo Auth/Firestore emulators and actual profile/terms API routes. The
production FlixieApp/router/AuthProvider runs with local analytics and push registration
excluded. All captured API responses succeeded in this run. Raw phase timings,
frames, request statuses and RSS are retained; Home's session snapshot and selected
caches are reset for each startup/login condition.

Email submission to observed Home content medians were **1,437.1 / 1,486.6 ms**
for 20/400-film accounts; native Firebase sign-in itself was **71.0 / 69.7 ms**.
First native resume to observed content was **643.2 / 459.7 ms**, and a quick next
resume **412.1 / 452.0 ms**. These include Patrol observation/automation overhead,
not production network performance. Each condition has five samples; its p95 is the
maximum observation. Startup in this reference creates a fresh auth/app root in
one process. The [fresh-process startup reference](performance/2026-10-06-startup-simulator/README.md)
adds 15 genuine process launches with persisted native Firebase sessions. Median
OS launch → useful content was **2,006.6 ms** signed out and **2,529.6 / 2,628.2 ms**
signed in with 20/400 films. These are debug fixture launches with warm OS/server
caches; production bootstrap services are excluded as documented in that report.

**Duplicate profile-read finding:** all ten first resumes made **two** full-profile
reads: AuthProvider recovery, followed by Home's `activityVersion` listener calling
`refreshUserData()` from `_loadAll`. All ten quick resumes made **zero** profile
reads (one other API read). This current behaviour is preserved as an optimisation
target, explicitly remembered at the user's request in `docs/product-ideas.md`.
**Targeted fix completed:** the [comparison](performance/2026-10-06-resume-optimisation.md)
records 50 additional samples. Every first resume now makes **one** profile read
and **20** total API requests; every quick resume still makes zero profile reads.
Settled medians: **1,200.5 → 859.9 ms** (20 films), **1,200.4 → 1,009.1 ms**
(400 films). Useful timing is mixed and RSS is higher, so no general speed/memory
improvement is claimed. Incomplete transport-failure attempts and login request/
response gaps in both captures are retained and documented in the comparison.

No physical profile/release-device baseline has been captured. Fields below remain
unmeasured unless explicitly covered by the linked references. No speedup or
production-performance claim is made.

| Scope | Measurements to capture | Baseline status |
|---|---|---|
| Cold startup, signed out and signed in | Launch to first usable screen; frame p50/p95; request count; peak memory | Auth/app-root and 15 fresh-process fixture launches recorded; whole production bootstrap/profile-device timing pending |
| Warm launch / foreground resume | Time to usable content; requests and repeated refreshes; retained memory | 20 native background/foreground samples recorded; original duplicate recorded; fix confirmed with 10 additional first resumes at one profile read and 10 quick resumes at zero; retained heap pending |
| Home, cold and warm | Useful title/settled; reads; frames; RSS/image bytes | 50-sample reference includes 10 Home mounts; first fresh mount only once; snapshot caveat above |
| Movie Detail, cold and cached | Navigation to useful title/synopsis; optional completion; endpoint reads; tab rebuilds; memory after repeated open/close | Native mount/cache reference recorded; navigation/tab rebuilds and retained heap pending |
| TV Detail, cold and cached | Summary/full-detail timing; season request count; tab/episode rebuilds; scroll frames | Native mount/cache reference recorded; season/episode interactions pending |
| Watchlist, small and 400-title libraries | Initial rows; requests/concurrency; filter/search latency; scroll frames; memory | Native 20/400-library reference recorded; filter/search action timing pending |
| Profile, favourites/ranking and gallery | Useful content; reorder/save latency; gallery frames and image memory | Mounted own/Friend Profile tab comparisons and native correctness recorded; save latency, gallery-specific frames and retained heap pending |
| Social/activity, friends, groups and chat | First useful rows; paging requests; live update rebuilds; scroll frames | Paired mounted Social/tab/paging capture recorded in the Social cleanup report; chat and populated group-member stress remain pending |
| Search, recommendations and collections | Input to useful results; duplicate/cancelled requests; paging/rebuilds | Not measured |
| Login / auth/account switching | Submit to Home; auth/profile/terms phases; requests by account; cache isolation; memory after logout/switch | Reliable login reference plus 20 final logout/target-login timings and 40 GC observations recorded; retaining paths investigated; app-owned router retention fixed |
| Long session | Heap/RSS before/after repeated routes and after GC; active listeners/timers; image cache bytes | Not measured |

## Comparable profile captures

Use a dedicated test device with fictional local fixtures. Record the device/OS,
Flutter version, commit **and working-tree snapshot**, profile/release mode,
backend/region, fixture sizes, image cache state, network conditions, text scale
and screen size. Never store account tokens, personal account data or credentials.

1. Freeze the starting repository snapshot **before** the proposed runtime change.
2. Run in profile mode and capture DevTools Performance, Memory and Network
   traces. Use the same dedicated device and backend for before/after.
3. Separate cold caches from warm caches. Run at least five repetitions for each
   journey after setup; record median and p95 with the raw observations, sample
   count and route/tap that starts/stops each timer.
4. Record UI and raster frame durations, missed frame budget/janky-frame count,
   useful-content and settled timing, requests per endpoint, peak memory and
   retained memory after the same repeated navigation/GC sequence. Use the actual
   display refresh rate for the frame budget rather than assuming 60 Hz.
5. Keep trace exports and raw results under `docs/performance/` with a dated name,
   or link their durable location here. Record failures/outliers rather than
   silently deleting them. Compare the same scripted journey and fixture.
6. Only claim an improvement supported by comparable measurements. Record the
   correctness checks alongside it; a faster result must still be correct.

Before/after result entries should include: scope, revisions/snapshots, device,
mode, fixture, cache condition, sample count, useful-content median/p95, frame
UI/raster p95, janky frames/total frames, endpoint request counts, memory
start/peak/retained, trace links and interpretation. Use “not measured” for every
missing field.

## Home loading/subscriptions cleanup — 7 October 2026

[Before](performance/2026-10-07-home-before.json) and
[after](performance/2026-10-07-home-after.json) source snapshots record this batch.
Home was 2,723 lines immediately before it and is now 1,555. Responsibilities moved
to cohesive section/plan controllers and hero/session widgets; this is not a claim
that total code or runtime memory fell. The [cleanup record](performance/2026-10-07-home-cleanup.md)
contains focused validation and simulator comparison status. Narrower rebuild
scope is demonstrated by actual widget-identity tests. Native measurements must
be compared against the post-profile-read-fix reference, with failed transports
and request/response gaps visible.

The Home batch completed another **50 native lifecycle samples**. First-resume
profile/API budgets remain 1/20 and quick-resume budgets 0/1. Resume UI frame p95
was 60.1 → 25.3 ms (20 films) and 37.9 → 17.3 ms (400 films); timing was mixed and
peak debug RSS higher. Seventeen connection-failed requests in five login samples
limit login comparisons. The failed attempt and all successful-run transport
diagnostics are retained; no general latency or memory improvement is claimed.

## Reliable login reference — 7 October 2026

The [reliability record](performance/2026-10-07-reliable-login.md) establishes two
independent clean lifecycle captures: **100 samples, including 20 real email logins**,
zero transport exceptions, HTTP failures or request/response gaps. Plain Dart
requests reproduced the local fixture keep-alive expiry race; its server now
retains idle sockets for 60 seconds. No production transport or app behavior changed.
The capture reporter rejects incomplete transports rather than accepting a visible
title alone. Historical gap-containing runs remain preserved.

Combined clean medians (20 / 400 films): login to useful Home **1,337.3 / 1,354.4 ms**;
login settled **1,566.5 / 1,585.5 ms**; signed-in app-root startup to useful Home
**284.4 / 308.5 ms**; first resume to useful Home **452.0 / 462.3 ms**.
All logins have 25 successful API requests; first resumes retain one profile read
and 20 total requests, quick resumes zero profile reads and one request.
The complete table, p95, raw phases/frames/RSS and methodology are in the linked
record and captures. Earlier missing optional work prevents an equivalent-work
login speed comparison. These remain debug simulator measurements, excluding
whole production bootstrap, external sign-in providers and physical release timing.

## TV Detail cleanup — 7 October 2026

The page now owns composition and local UI state; loading, actions and substantial
widgets have named owners. Frozen [before](performance/2026-10-07-tv-before.json)
and [after](performance/2026-10-07-tv-verified.json) snapshots retain every source
hash. The page fell from 3,382 to 930 lines. Episode-list progress is computed
once per build; provider tabs keep their own selection. No frame-time or retained
heap improvement follows from those changes alone.

The [cleanup record](performance/2026-10-07-tv-detail-cleanup.md) records focused
checks, native correctness and the new mounted-screen measurements. Historical
references remain unchanged; debug simulator mount timings do not measure
physical-device navigation or production service latency.

The [final TV-only native reference](performance/2026-10-07-tv-detail-final-simulator/README.md)
contains ten completed samples against the verified final source. Useful median
is 150.1 ms reset / 164.9 ms cached; every sample makes nine API reads. The audit
accounts for all 90 responses with no transport exceptions/gaps, while retaining
ten known fixture TV-provider HTTP 500s. Reset p95 is 1,453.7 ms (the maximum of
five); no slow sample was excluded. This is a new debug mounted reference, not a
controlled speedup comparison or a healthy-provider baseline. Use `--scenario
tv_detail` to repeat it; omitting the option retains the 50-sample full ledger.

## Own Profile cleanup — 7 October 2026

Frozen [before](performance/2026-10-07-profile-before.json) and
[after](performance/2026-10-07-profile-after.json) source snapshots retain file
counts/hashes. The page fell from 2,160 to 213 lines, with loading/paging, actions
and substantial widgets extracted into named owners. Repository totals are
420 → 432 files / 113,315 → 113,286 lines; files over 1,000 lines fell from 21 to
20. This is structure evidence, not runtime speed or retained-memory evidence.

The [Profile cleanup record](performance/2026-10-07-profile-cleanup.md) includes
before/after native mounted Library and tab observations, with request/response
and frame/RSS records. Notification-only updates preserve header and Library
widget identities in actual screen checks. The unused friends read is removed;
Stats remains lazy and cached on tab returns. Use the opt-in `--scenario profile`
to recapture; the existing default 50-sample ledger is unchanged.

The paired ten-sample runs are transport/HTTP clean and match their frozen source
hashes. Unused friends reads fall from one to zero per mount; cached journeys
fall from ten to nine total API reads. Whole captures account for 102 → 95
requests, including differing timing of existing list refreshes. Library settled
medians are 294.4 → 297.9 ms reset and 295.4 → 297.2 ms cached. No clear timing
or retained-memory gain is established. All 52 focused checks and ten distinct
native correctness journeys pass; the record preserves the corrected gallery
test-selector failure and its successful rerun.

## Friend Profile cleanup — 7 October 2026

The page is 2,142 → 279 lines. Frozen [before](performance/2026-10-07-friend-profile-before.json),
[intermediate](performance/2026-10-07-friend-profile-after.json) and
[final](performance/2026-10-07-friend-profile-final.json) snapshots are retained.
Repository totals are 432 → 438 files and 113,286 → 112,941 lines; files over
1,000 lines fall from 20 to 19. Loading, friendship actions and presentation have
named owners; viewer/subject/refresh/disposal guards and original lazy rows are
protected by 74 focused checks and two passing final native journeys.

The [cleanup report](performance/2026-10-07-friend-profile-cleanup.md) preserves
the intermediate eager-Column regression/correction and all captures. Paired
before/final ten-sample database runs use a 150-film friend and 20-film viewer;
response audits are clean for 114 / 111 requests, with matching source hashes.
Necessary Profile reads remain one each per mount, and cached Reviews returns
make zero reads. Aggregate request variation is existing list-read timing.

Useful medians are 164.1 → 163.4 ms reset / 171.8 → 166.1 ms cached; settled
medians 1,347.0 → 1,330.4 / 514.2 → 597.4 ms. Final reset p95 is 1,475.3 ms,
retaining the slow first sample. Peak debug RSS medians are 385.2 → 362.8 /
333.3 → 274.2 MiB, but cached end RSS rises and retained heap remains unmeasured.
Timing is mixed; no general speed or retained-memory improvement is claimed.
Use `--database --scenario friend_profile` for focused recapture; default remains
50 samples.

## Social cleanup — 7 October 2026

SocialScreen is 2,023 → 165 lines, with separate People/Groups loading owners,
first-visit tabs, scoped unread updates and hidden/background polling control.
Account transitions reject stale reads/actions and close account-bound sheets.
63 focused Flutter checks, 11 capture/audit checks and final analysis pass.

The [cleanup report](performance/2026-10-07-social-cleanup.md) records paired
ten-sample native database captures. Request/response audits are clean: 437 → 397
requests. Initial load requests fall from 9 → 4 on later cold mounts and 8 → 3
warm; People/Groups reads move to first visit and unused activity-lists disappear.
Useful medians are 314.9 → 164.6 ms cold / 315.2 → 165.3 ms warm; settled medians
1,396.4 → 1,329.5 / 663.2 → 513.2 ms. First People visit becomes slower because
its reads are deferred. Paging records include scrolling/footer retries; no API
latency gain is claimed. Debug RSS is recorded, retained heap remains unmeasured.

Final capture matches all final lib hashes; before verifies four original active
Social files. Failed runs and disk/database recovery are preserved in the report.
Groups are empty in this database; populated group stress, production startup/login
and release-device performance remain pending. Use `--database --scenario social`.

## Watch Requests cleanup — 7 October 2026

The page is 2,048 → 367 lines; its notification resolver is a separate 106-line
page. Loading/filter/draft state, responses, schedules, completion, choices and
list/calendar UI have named owners. Account/refresh/disposal guards and account-bound
sheets protect late work; per-plan writes are single-flight; group-count reads
use four workers. Focused direct detail no longer loads unrelated group counts.

The [cleanup report](performance/2026-10-07-watch-requests-cleanup.md) records
88 focused Flutter checks, 11 passing native journeys, clean analysis/development
restart, twelve capture/audit checks and three fixture safety checks. Local real
SQL fixtures include 24 direct plans, four groups and 12 group plans. Paired
ten-sample mounted captures have clean response audits and matching lib hashes:
160 → 160 requests, six initial / 16 whole-journey reads per sample. Useful
medians 152.2 → 163.7 ms cold / 147.9 → 147.8 warm; settled 1,314.4 → 1,328.6 /
382.5 → 380.4 ms. Timing is broadly similar; no loading speedup is established.

Debug peak RSS rises 323.4 → 614.5 / 306.5 → 634.1 MiB and remains higher in an
unchanged-source confirmation capture. Separate paired post-service-GC allocation
checks show near-identical heaps (fifth cycle 127.68 → 127.80 MiB) and zero disposed
page/controller/friend/group states after each of five unmounts. This finds no added
screen retention in that debug scenario; the native/RSS gap remains unresolved.
No production memory gain is claimed. Source/hash audits, full class counts and
all captures remain visible. Startup/login, release-device memory and API paging
are outside this mounted-list capture; the list currently fetches all plans.
Use opt-in `--database --scenario watch_requests`; default remains 50 samples.

## Movie List Detail — 7 October 2026

Page 2,115 → 348 lines with separate metadata, actions, selection and UI owners.
35 focused checks, three native journeys and clean focused analysis pass.
Guarded fictional public/friends/private lists include a 121-title mixed shared
collection and overlapping badge-bearing contributors. Both matched ten-sample
captures are HTTP/transport/source clean: two load reads and four journey reads
per sample; member-sheet opening and sorting add no requests.

Useful-content medians cold/warm are 149.3 / 146.4 → 147.5 / 146.8 ms; settled
medians 1,313.5 / 380.0 → 1,311.9 / 378.3 ms. No loading speedup is claimed.
Peak debug RSS cold/warm is 514.9 / 437.7 → 338.6 / 371.3 MiB, without a
post-GC retained-memory comparison; lower process RSS alone is not evidence of
a memory optimisation. The screen still fetches its full list, not API pages.
Database write latency and physical-device profile performance remain pending.
See [the cleanup record](performance/2026-10-07-movie-list-detail-cleanup.md) for
full tables, fixtures, source/harness hashes, validation and corrected failures.

## Account lifecycle — 7 October 2026

[Account lifecycle report](performance/2026-10-07-account-lifecycle.md) records
20 final logout/target-account-login timings and 40 post-GC observations against
the populated local database and native demo Auth emulator. Logout and target login
are separate legs. Home owners clear after settled logout; one auth test instance
remains after disposal without accumulating. No production optimisation or proved
leak is claimed. Raw timings, exact source hashes, rejected exploratory capture
and repeatable command are linked in the report.

## Auth root retention — 7 October 2026

[Retaining-path investigation](performance/2026-10-07-auth-retention-investigation.md)
proves a static push-router reference kept disposed auth reachable. Root disposal
now detaches/disposes the router. Ten native account-free input controls record
zero live auth instances after the fix, versus one in the pre-fix control.
Natural framework last-input retention remains; no speed/RSS/total-heap gain claimed.
The fixed capture has 20 timing samples, 60 GC profiles and complete paths.

## Account cache ownership — 7 October 2026

[Ownership record](performance/2026-10-07-account-cache-ownership.md) links 50 before
and 50 after startup/login/resume samples, plus 20 after logout/switch timings and
60 GC observations. All captures are transport clean; paired startup/login/resume
endpoint counts are identical. First resume keeps one profile read, quick resume
zero. All ten neutral-input controls keep zero live auth instances. Cache allocation
counters are recorded but not a separate live-cache retention diagnosis. Timing
changes are mixed, with some higher login medians; no performance gain claimed.
AuthProvider delegates cached data to one owner and is 1,671 → 1,495 lines.


## Session recovery ownership — 7 October 2026

[Recovery record](performance/2026-10-07-session-recovery.md) compares the existing
50-sample cache-after reference with 50 new populated startup/login/resume samples.
Exact endpoint counts match; first resume retains one profile read, throttled
resume zero. Timings move in both directions and debug RSS is higher; no speed or
memory gain is claimed. AuthProvider is 1,495 → 1,351 lines with a 226-line recovery
owner. Another 20 clean logout/switch timings and 60 GC observations retain exact
request budgets and zero live auth in all ten neutral-input controls. Owner allocation
counters are recorded separately; they do not prove live owner retention.


## Person Detail — 8 October 2026

[Cleanup record](performance/2026-10-08-person-detail-cleanup.md) compares ten
populated before and ten after mounted-screen samples, with full-credit browsing,
Alien search and TV filter stages. All 60 requests are HTTP/transport clean:
three per load, no extra stage reads, unchanged exact endpoint budgets. Useful
median cold 167.202 → 184.595 ms; warm 206.565 → 199.655 ms. Timings are mixed;
peak debug RSS rises from 269.797 → 317.328 MiB cold and 262.578 → 312.594 MiB warm.
No speed or memory gain is claimed. The page is 2,113 → 216 lines with separate
loading/actions/selection/widgets, retained merged credits and viewer library sets.
Raw frames, RSS, stages, fixture/source hashes and validation are linked in the
record. This is mounted Person Detail; startup/login/resume baselines are unchanged.


## Controlled Person Detail memory — 8 October 2026

[Investigation and raw evidence](performance/2026-10-08-person-memory.md): two
fresh native debug captures with reversed image order, archived/current screens
in the same binary and populated local database. 40 visits, 200 GC checkpoints,
120 successful reads, unchanged source, two native passes and ten audit checks.
All ten direct class counts are zero at every baseline/neutral-input/cache-cleared
checkpoint. Immediately after navigation, both versions retain the page via
Flutter's last text-input connection; all 60 owner paths disappear after neutral
input. Current merged credits stay bounded at 121 while mounted.

Mounted baseline-adjusted heap medians before → current: no images 2.303 → 2.239
MiB / 2.323 → 2.221 MiB; controlled images 2.772 → 2.676 / 2.765 → 2.668 MiB.
Decoded images match at 17.840 MiB. Final heap medians above baseline span
0.062–0.428 MiB; paired image-condition direction varies, as does RSS. No growing
tracked owner leak or meaningful release-memory gain established; historical
roughly 50 MiB debug RSS gap remains causally unresolved. Keep allocation census
and direct instance queries distinct. Startup/login/resume records are unchanged.


## Group Watch Plan — 8 October 2026

[Cleanup and populated comparison](performance/2026-10-08-group-watch-plan-cleanup.md):
ten before and ten after mounted-screen journeys using four fictional groups and
12 plans in the populated local database. All 760 reads returned HTTP 200 with no
transport gaps/errors. Combined refresh removes four duplicate group-plan reads
(13 → 9); whole journey 40 → 36, a 10% reduction. Initial load, single refresh and
detail opening remain nine reads each; Past/Active/Back add none.

Useful-content medians cold 183.258 → 168.957 ms, warm 181.294 → 166.394 ms;
stage/frame timings are mixed, so no release-speed gain claimed. Median peak debug
RSS rises cold 319.406 → 549.500 MiB and warm 271.750 → 519.578 MiB; first cold peaks
are similar at ~723/~725 MiB an d decoded images remain 5.52 MiB. The cause remains
unresolved: these pre-GC readings prove neither a retained leak nor a memory gain.
The Person Detail controlled-memory result cannot establish group-plan behaviour.

Page size 2,023 → 241 lines; explicit owners/widgets total 3,233 lines across 17 files.
65 focused checks, 16 native action journeys and 15 capture/audit checks pass;
scoped analysis is clean and source/config restoration is verified. Raw data,
exact endpoint stages, hashes and caveats are linked in the report. Database write
latency, startup/login/resume and physical-device performance are outside this capture.

## Watch Request composer — 8 October 2026

[Cleanup and populated comparison](performance/2026-10-08-watch-composer-cleanup.md):
ten before and ten after mounted-composer journeys with 40 fictional friends and
four overlapping groups. All 320 reads returned HTTP 200 with complete accounting.
Per-journey work falls 22 → 11 cold and 21 → 10 warm; combined reads 215 → 105
(**51.16% fewer**). Group membership still refreshes each selection; user-provider
reads are shared only within the open sheet and cleared on disposal.

Useful-content medians cold 183.807 → 164.610 ms and warm 150.288 → 164.578 ms;
stage/frame timings are mixed. Peak debug RSS medians cold 615.797 → 628.234 MiB
and warm 623.250 → 551.719 MiB also move in opposite directions. No general speed
or memory gain claimed. Decoded images match at 0.032 MiB. Source/harness/fixture
checks and exact stage budgets are linked in the report; four rejected exploratory
attempts are excluded from the comparison.

Entry point 1,739 → 238 lines, with 13 cohesive files totalling 2,023 lines and no
file above 295 lines. Focused controller/widget/API/date/provider checks: 43 pass;
capture-scope/audit checks: 16 pass; scoped analysis is clean. All 19 selected native
action journeys pass with no failures and verified source/config restoration. Database send latency, physical-device release
performance and startup/login/resume are outside this mounted-composer capture.


## Controlled Group Watch Plan memory — 9 October 2026

[Investigation and paired evidence](performance/2026-10-09-group-memory.md): two
fresh debug simulator processes, reversed image order, archived/current pages in
one binary, matching source and populated four-group/twelve-plan local fixtures.
40 visits, 200 GC checkpoints, 1,520 HTTP-200 reads, two native passes, ten audit
checks and clean scoped analysis. Native test configuration is restored.

All six tracked owner/model class counts are zero at all 40 baselines and all 120
post-close checkpoints; post-close refresh signals cause no reads. Mounted counts
stay at 12 plans and 16 members, with one current controller and two action objects.
Decoded images match at 5.5234 MiB and clear to zero. Baseline-adjusted mounted heap
medians before → current are 3.6225 → 3.6369 / 3.6073 → 3.7038 MiB without images,
and 3.7267 → 3.7457 / 3.7189 → 3.7299 MiB with controlled images (runs 1 / 2).

No accumulating tracked retention is found; the historical ~230–248 MiB peak RSS
gap is not reproduced consistently in controlled post-GC readings. Its exact cause
remains unresolved. A smaller final paired baseline-adjusted heap residual remains
+2.6805–5.3261 MiB despite zero tracked owners; this is recorded, not attributed to
a proven leak or assumed measurement overhead. No production memory gain or fix
is claimed. Startup/login/resume and physical-device profile evidence are unchanged.

## Group Insights cleanup — 9 October 2026

The tab is now 61 lines, previously 1,489. Eleven focused ownership files total
1,077 lines, largest 234. Loading is scoped to viewer/group/period, overlapping
refresh work is shared, and old responses cannot repopulate a changed account.
Empty/error period selection, spoilers, privacy, own-user badges, routes and
responsive layouts have focused regression coverage. No persistent cache or extra
service/repository layer was added.

The [dated report](performance/2026-10-09-group-insights-cleanup.md) records the
populated before/after comparison, source/data fingerprints, query budgets and
validation. The [repository snapshot](performance/2026-10-09-group-insights-repository.json)
records structure separately from runtime performance. Existing API-level GET
coalescing means overlapping refresh still costs one HTTP read in both versions;
do not present controller extraction as a network-request reduction.

Audited comparison: **20 samples / 100 successful tracked reads**. Useful-content
medians are effectively unchanged: cold 166.3 → 165.1 ms, warm 148.2 → 148.3 ms.
Five reads per visit remain unchanged. Peak RSS rose from 313.4 → 406.4 MiB cold
and 312.6 → 407.7 MiB warm; pre-mount RSS was already elevated. The cause is
unresolved, and this pre-GC debug measurement establishes neither a leak nor
memory neutrality. Record a controlled Insights memory check as the follow-up;
do not substitute previous Group Watch Plan findings for evidence on this screen.

Validation: 28 focused tests, 17 capture/audit checks and six native journeys pass.
Scoped analysis is clean; development hot reload succeeded without runtime errors.
Native test configuration was restored and final source fingerprints verified.

## Controlled Group Insights memory check — 9 October 2026

The [controlled investigation](performance/2026-10-09-insights-memory.md) completes
the cleanup's RSS follow-up with **40 paired visits, 200 GC checkpoints and 200
successful API reads**, across image-free/controlled-image runs in reversed order.
Both native captures and eleven audit/reference checks pass; sources/data match.
No production code changed.

Every baseline and post-close observation has zero tracked tab/controller/review
States and populated movie/review/member models. One shared response remains
bounded at one through a compiled-code constant reference. Decoded images match at
6.6927 MiB. Mounted heap above baseline is ~1.62–1.90 MiB; final paired heap
residuals are small (current minus archived −0.013 to −0.182 MiB).

No accumulating tracked Insights retention was found. The earlier ~93–95 MiB RSS
gap does not reproduce consistently under controlled GC, but its historical cause
remains unattributed. This does not establish release-device memory improvement
or cover every flow. No production fix was warranted; native configuration restored.

## Search cleanup — 9 October 2026

Search now has a 174-line composition/focus/navigation page (previously 1,236), one
289-line controller and cohesive history/content/result owners. Eleven ownership
files total 1,486 lines; this is a responsibility split, not a net source-size cut.
Notification updates no longer rebuild results. Paging/refresh overlap and retries
have explicit ownership; failed refresh retries page one, collection failures are
visible, history writes are serialised and the recent-history header reflows.

The [dated report](performance/2026-10-09-search-cleanup.md) records **20 matched
samples / 170 HTTP 200 reads**, with no transport failures or response gaps. The
7,941-entry isolated PostgreSQL catalogue snapshot replaces only Search's external
TMDB transport. Request budgets remain nine cold/eight warm per visit. Useful
medians are 170.5 → 165.3 ms cold and 165.1 → 164.4 ms warm; interaction timings are
broadly unchanged. UI build p95 is lower, raster p95 slightly higher. No general
speedup is established by these debug simulator observations.

Peak RSS is higher: 374.0 → 467.1 MiB cold and 336.6 → 471.9 MiB warm. The first
pre-mount values are similar; later pre-mount values are elevated and may include
prior Search visits. The cause is unresolved. Record a controlled Search memory
check as a follow-up; do not claim memory neutrality or borrow conclusions from
Insights. Physical-device startup/login/resume profiling remains outstanding.

Validation: 39 focused checks, six native journeys, 18 capture/audit tests and
three backend fixture tests pass. Scoped analysis is clean; development hot restart
succeeded without runtime errors. Final source/data fingerprints match and native
configuration is restored. Failed harness attempts are preserved and excluded.
The [repository snapshot](performance/2026-10-09-search-repository.json) records
structure separately from runtime performance.


## Controlled Search memory check — 9 October 2026

The [controlled report](performance/2026-10-09-search-memory.md) compares the archived
page and current implementation using two fresh debug simulator processes, reversed
order and the same 7,941-entry local catalogue. Both captures pass: **40 visits,
200 GC checkpoints, 360 HTTP 200 reads**. Images are either absent or fixed at
29,343,584 decoded bytes in both variants.

Every visit releases tracked Search owners after neutral input. All 60 sampled
immediate page/controller paths pass through Patrol's focused editable reference;
all 80 remaining movie paths lead to the shared Trending cache. Its 21 movies clear
with the cache, leaving all 11 tracked classes at zero. Final baseline-adjusted
paired heap differences range from −0.358 to +0.060 MiB. No accumulating tracked
Search ownership was demonstrated, and production source remains unchanged.

Mounted RSS remains higher for the current variant in all four groups; post-clear
RSS differences vary in sign. The earlier +93.1/+135.3 MiB peak RSS gap is still
unattributed. This is an ownership baseline, not proof of overall memory neutrality
or a physical-device result. Startup/login/resume device profiling remains open.
Twelve audit/reference checks and both native captures pass; the frozen harness has
one analysis style info, no errors/warnings. Source/data fingerprints match and
native configuration is restored. Excluded attempts remain separately documented.


## Onboarding cleanup — 9 October 2026

The [dated report](performance/2026-10-09-onboarding-cleanup.md) records the
1,435 → 266-line page, 464-line state controller and seven focused widgets. The
nine owners total 1,748 lines; no net source-size or general runtime gain is claimed.
Existing SetupService and private taste/explicit favourites/community semantics
remain. Account/disposal guards, debounce cancellation, bounded availability work,
duplicate-add suppression and late saved-taste protection have focused regressions.

Both matched native captures pass: **10 measured visits / 40 HTTP 200 reads** using
the 7,941-entry isolated catalogue snapshot. Four catalogue reads per visit are
unchanged. Settled opening medians are 302.3 → 316.8 ms; scripted journey is
6,865.7 → 6,847.8 ms. Median per-visit build p95 is 9.745 → 9.801 ms and raster p95
1.454 → 1.521 ms. This includes controlled pumps/settling and is not human or full
signup latency. Account writes/completion/reference data are fixtures, images are
absent and production recommendation/database-write latency remains unmeasured.

Start RSS is 593.5 → 485.7 MiB; end RSS 575.9 → 455.2 MiB. The difference already
exists before mounting, so this does not establish lower retained memory. No GC
ownership study or physical-device profile result is implied.

Validation: 65 focused Flutter checks, eight capture-audit checks and three native
setup/favourites/community journeys pass. Scoped production and harness analysis
are clean. Source/data/archive checks pass, the development app restarted without
runtime errors, and temporary native configuration is restored. Original captured
harness/runner sources are archived; later changes only tidy test lint and expose
the guarded reusable capture CLI/audit. Physical-device startup/login/resume
profiling remains outstanding.

## Notification legacy-card removal — 9 October 2026

Inspection corrected the proposed 1,372-line extraction: the request card had no
Dart references outside its declaration; the active screen uses
`NotificationInboxCard`. Removed the unused file. `lib/` drops from 540 to 539
Dart files and 114,670 to 113,298 lines, with all surviving Dart source hashes
unchanged. The original source and before/after fingerprints are retained.

This is a structural baseline, not a measured runtime optimisation. Frame,
memory and database latency comparisons for an unmounted widget are not
applicable; no synthetic runtime gain is claimed. See the
[cleanup report](performance/2026-10-09-notification-cleanup.md) for validation.

## Settings — 9 October 2026

Page 1,134 → 455 lines; six resulting owners total 1,190 lines. Matched actual-editor
checks against archived original source: valid username then short/original input
reduces obsolete availability requests **1 → 0** in each scenario. Country reads
remain **1 → 1** per opening. An unrelated cached bio update replaces the edit tile
before, preserves it after. Debounce remains 600 ms; no latency/RSS claim.
16 focused tests and one native iOS save journey pass; analysis and development
refresh are clean. See [the report](performance/2026-10-09-settings-cleanup.md).

## Movie Lists overview/editor — 9 October 2026

Page 1,103 → 285 lines; six resulting owners total 1,123 lines. Matched withheld-
response test with 40 fictional lists: personal editor opening relationship
requests **2 → 0**, form hidden → visible after 350 ms of test-clock pumping while
relationship responses remain pending. This removes the network dependency from
opening; it is not a measured device-latency/RSS improvement. Friends/groups load
on selection and reuse results only for the editor lifetime. See the
[report](performance/2026-10-09-movie-lists-cleanup.md) for scope and validation.

## Community Discussion — 9 October 2026

Page 1,012 → 581 lines; six resulting owners total 1,239 lines. Matched forty-reply
fixture corrects the initial proposal: body content already appears before replies
finish, before and after. The demonstrated request improvement is focusing an
already-loaded reply: **1 extra lookup → 0**. No first-content latency or RSS gain
claimed. Coalescing/stale-response tests cover refresh, paging, membership and
moderation. See [the report](performance/2026-10-09-community-discussion-cleanup.md).

### Pick for Us — 9 October 2026

[Cleanup and matched request baseline](performance/2026-10-09-pick-for-us-cleanup.md):
opening relationship calls 2 → 0; friend-only selection reads friends once and
skips groups. Selecting both types still costs two calls; revisits reuse results
within the flow. Screen 858 → 634 lines; six owners total 975. Deterministic
fictional service fixture; no database, latency or memory gain claimed.

### Add to List — 9 October 2026

[Report](performance/2026-10-09-add-to-list-cleanup.md): personal creation friend
reads 1 → 0; choosing collaborators still costs one. Opening list-content reads
remain 40 → 40 for the forty-list HTTP fixture: a separate fan-out target. Removed
170 commented layout lines and 150 unused widget lines; original file 935 → 293,
extracted creation form 330 (623 total). No database timing or memory claim.

### Batch movie-list membership — 9 October 2026

[Evidence](performance/2026-10-09-list-membership-batch.md): membership requests
40 → 1, plus the separate overview request. Guarded PostgreSQL fixture has 45 lists
and 4,500 entries, 40 accessible/39 matching. Three paired production backend-read
samples have medians 1673.49 → 3.56 ms; serialized content 5,966,509 → 2,889 bytes.
These exclude HTTP/device latency, overview and identity lookup. Permission,
removed-item and read-after-remove/restore assertions pass; fixtures cleaned up.

### TV lists, overview and Friend Watch Plan — 9 October 2026

- [TV membership](performance/2026-10-09-tv-list-membership.md): opening membership
  requests 40 → 1; personal-creation friend reads 1 → 0. Local backend median
  1913.66 → 2.61 ms, three paired samples on 4,545 entries. Shared picker replaces
  duplicate TV implementation; cold overview remains one separate request.
- [Overview](performance/2026-10-09-list-overview-query.md): hydrated items
  4,038 → 160; five-sample local median 32.26 → 19.94 ms. Counts/ordering/visibility
  preserved; missing collaborator badges now included. Not device or RSS results.
- [Friend Watch Plan](performance/2026-10-09-friend-watch-plan-cleanup.md): flow
  1,001 → 497 lines, six owners total 1,258. Structural improvement only.

34 Flutter cases, two backend regressions and two native journeys pass; raw data,
source archives and hashes in `performance/2026-10-09-lists-and-friend-plan-validation/`.

### Group Chat and Review Card — 9 October 2026

[Report](performance/2026-10-09-group-chat-review-cleanup.md): the controlled
50-message widget fixture records ten rebuilds causing extra subscriptions
10 → 0. Ten auth notifications during loading cause group/member/conversation/
request calls 11 → 1 each. These are fixture operation counts; actual Firestore
billing, real transport, device opening time and memory gains remain unmeasured.
Group Chat entry file 900 → 399 lines; Review Card 998 → 399 lines. Review extraction
is a readability change. Before 22 focused tests pass; after 34 pass. Raw opening
harness samples are recorded but are unsuitable for a speed comparison.

Three native iOS journeys pass; focused analysis is clean and development restart
reports no runtime errors. Temporary native test configuration restored.

### Notification inbox lifecycle — 9 October 2026

[Report](performance/2026-10-09-notification-inbox-lifecycle.md): 100-item isolated
HTTP fixture, three minutes covered/backgrounded: reads 3 → 0 in each scenario.
Route return now refreshes once. Two simultaneous refreshes remain one HTTP GET
(the API client already deduplicated them); cache publications 2 → 1. Screen
828 → 141 lines, five owners total 1,020. 42 existing tests pass before and 55
focused tests after; analysis clean. No live DB, device latency or memory gain
claimed. Four native iOS journeys pass, development restart reports no runtime
errors, and native configs are restored. Details and raw evidence are in the report.

## Group Members — 9 October 2026

[Cleanup and controlled selection baseline](performance/2026-10-09-group-members-cleanup.md):
100 members × 100 repeated lookups: 100 original sorts → one load sort and zero
repeat sorts. Ten focused tests pass. These are operation counts, not device
latency or retained-memory measurements.

## Media sharing — 9 October 2026

[Cleanup and repeat-open request baseline](performance/2026-10-09-media-sharing-cleanup.md):
three opens of each picker with empty recipients: 6 HTTP reads → 2. With 100 friends
and 100 groups: 2 → 2. Existing auth caches now retain empty-result validity.
42 focused tests pass; no device latency or memory improvement claimed.
Native confirmation: all three media-sharing iOS journeys passed (friend/group
send retry and pending-dismiss), with temporary native configuration restored.


## Group Detail / Members native and memory — 9 October 2026

[Audited report](performance/2026-10-09-group-native-memory/README.md): 11 native
iOS tests and seven focused widget tests pass; analysis clean. Accepted controlled
capture: 15 visits, 75 forced-GC observations, populated isolated PostgreSQL reads,
all responses 200 and source hashes unchanged. Every tracked page/controller/
Activity/chat owner returns to zero after exit; all five chat subscriptions cancel.
Before/current median settled loading 706.6/711.9 ms; seven API reads each for
Activity → Insights → Activity, plus substituted parent conversation attempts
1 → 0. No speed or heap reduction claimed. Images are removed and chat uses a
50-message local stream; this is not production/Firestore memory validation.
Native role/removal/invitation/account flows and group-delete cancellation pass;
confirmed deletion remains untested. Failed/exploratory runs are preserved.


## Login/Home endpoint investigation — 9 October 2026

[Report](performance/2026-10-09-login-endpoints/README.md): three fresh local backend
processes, 1,764 successful requests. First profile response 3.14–3.46 seconds,
with 3.10–3.43 seconds in awaited demo Firestore chat-identity setup. This is a
local first-use dependency finding, not production latency. Warm serial profile
medians 14–16/20–21 ms for 20/400 titles; 26 SQL statements. Large profile JSON is
226,927 bytes, followed by a 118,898-byte watchlist fetch that Home reduces to IDs.
Candidate fixes: defer chat identity to chat access; reuse fresh owned watchlist
membership; consider compact bootstrap later. No production behavior changed.

Measurement clarification: prior physical login “useful content” 1.31/1.41 seconds
is observed after Patrol tap settling, not first useful frame. Existing auth-ready
medians are 150/248 ms; profile medians 44/94 ms. Request-count improvements remain
valid. Future first-frame timings need a separate versioned measurement boundary.


## Non-blocking login chat warmup — 9 October 2026

[Report](performance/2026-10-09-chat-identity-warmup/README.md): user approved
starting chat identity during login without awaiting it. Nine focused tests and
TypeScript checking pass. 588 isolated local requests succeed; all 42 identity
spans complete. First profile response 45.3 ms while background identity took
3,177.7 ms (previous profile blocked for 3,135–3,462 ms). Warm profile medians
5.9/12.8 ms for 20/400 titles. These are local endpoint timings, not a production
or device speed claim. Profile fields, identity/deletion guards and chat-entry
setup remain intact. No deployment or main development server restart.


## Initial Home bootstrap membership — 9 October 2026

[Report](performance/2026-10-09-home-bootstrap-watchlist/README.md): initial
watchlist endpoint calls fall from 1 to 0 for fresh empty/20/400-title profiles
(controller assertions). Avoids the previously measured duplicate 6,004/118,898
byte responses. Refresh, stale/missing data, activity invalidation and account
ownership remain covered. 54 focused tests and targeted analysis pass. Expected
login request budget 15 → 14 is not yet device-verified; no latency claim.


## Movie/TV opening request priority — 9 October 2026

[Report](performance/2026-10-09-detail-request-priority/README.md): keeps friends
immediate and adds no loading indicators. Movie removes one discarded request;
reviews/images warm after core. TV skips duplicate embedded friends and unused
per-season trailer work; reviews warm after first core result. Real local TV
summary DB reads fall 5 → 1, median 3.078 → 1.089 ms across 120 warm reads in a
154-show/8,531-episode fixture (zero show ratings). Existing ID index used; no
migration. 42 unique Flutter / 13 backend tests, analysis/typecheck pass. Simulator
reload clean. No production deployment or measured device latency improvement.


## Group Activity tab return — 9 October 2026

[Report](performance/2026-10-09-group-activity-retention/README.md): retains only
Activity within the current group/account visit. Previous recorded native return
journey: 2 feed reads; current production-widget fixture: 1 across Activity →
Insights → Activity, preserving filter/search/scroll. Changed, errored or >1-minute
old feeds revalidate. Account/access changes clear data; page exit disposes state.
26 unique focused checks and targeted analysis pass; simulator restart clean.
No new loading indicators, native latency/heap claim, backend change or deployment.


## Profile opening — 9 October 2026

[Report](performance/2026-10-09-profile-opening/README.md): Library requests the
existing watches-only activity page and defers full Activity/ratings until needed.
Uncached controller opening requests 4 → 3; activity-page SQL 22 → 9 on populated
20/400-watch accounts with 100 ratings each. Two alternating local runs preserve
80 warm samples each and show lower query time, with significant between-run
variation (see report). No production DB migration/endpoint change. 29 Flutter +
2 backend tests and targeted analysis pass; simulator restart clean. Fixture seed
adds 420 fictional watch entries; do not compare old captures without matching data.
No measured device screen-speed improvement claimed.

### 9 October 2026 — Home image preload alignment

User switched the screen-speed run to images/scrolling. Corrected Home preloads
to use the same hero and Continue Watching image URLs as the cards. With five
distinct visible image paths, unused preload variants 3 → 0; combined unique
preload/display URLs 8 → 5. Source/fixture URL-plan counts only, not observed
HTTP requests, decoded memory, FPS or latency. No image-resolution/layout change.
17 focused tests, clean analysis and simulator reload with no runtime errors.
[Evidence](performance/2026-10-09-home-image-preload/README.md). Physical screen
benchmarks deferred; no new timing results. Lazy primary lists confirmed; compact
poster decoding and eager Watch Plans remain measurement candidates.

### 9 October 2026 — controlled poster decoding and scroll frames

Matched dedicated iPhone 17 Pro simulator captures with the 400-title fixture,
DPR 3 and controlled local image files: 36 native visits, 30 measured after
excluding warmups. Same API request/response maps and image file reads in each
pair. Accepted runs `before-2` / `after-1`; first harness failure rejected.

| Screen | Decoded cache after journey before → after | Reduction |
|---|---:|---:|
| Home | 14.509 → 12.784 MiB | 11.9% |
| Watchlist | 16.111 → 5.764 MiB | 64.2% |
| Search | 17.979 → 17.979 MiB | 0% |

Watchlist decodes small posters at physical display width; Home's bounded library
preload uses the same memory key. Image source URLs, resolution for full-size
views, and layout unchanged. Memory values repeat exactly in five measured visits.
Not total process memory, all 400 decoded posters, or compressed download savings.

No demonstrated scroll speedup. Build p95 before → after: Home 3.470 → 4.272ms,
Watchlist 2.201 → 2.379ms, Search 2.774 → 2.864ms. Raster p95 3.328 → 3.286ms,
2.416 → 2.530ms, 2.270 → 2.377ms respectively. Debug simulator; fixed flings
include top-edge refresh on Home/Search, so these are scroll-and-refresh diagnostics.
Raw frames/threshold counts retained; no physical FPS or causal speed claim.
19 focused Flutter + seven collector tests pass, analysis clean, simulator reload
without runtime errors. [Full report](performance/2026-10-09-poster-scroll/README.md).

### 9 October 2026 — TV missing-date response dependency

Before: stored TV details with a null last-air date awaited TMDB and a relation-loading DB update. After: neither refresh nor conditional DB write gates the response. Controlled tests hold each dependency unresolved and assert response completion; concurrent opens share one refresh. Valid dates persist for later reads, without overwriting newer syncs. No measured millisecond improvement or native benchmark claimed. [Evidence and verification](performance/2026-10-09-tv-date-refresh/README.md).

### 10 October 2026 — Group Activity first-load database/reaction phases

Seven alternating measured local PostgreSQL + Firestore emulator pairs (four fictional members, 50 feed items with reactions): median database assembly **46.066 → 30.465ms**, complete HTTP **62.716 → 40.139ms**, legacy viewing-entry lookup **12.640 → 1.993ms**. Grouped exact user/movie conditions reduce 400 OR branches to four. Firestore unchanged (7.363 → 6.090ms variation); complete responses match. No production or native screen speed claim. [Raw results and methodology](performance/2026-10-10-group-activity-first-load/README.md).

### 10 October 2026 — Group Activity independent-source bounds

Five independent sources capped at 50 with deterministic timestamp/ID order. Seven alternating measured local DB/emulator pairs: top-level rows **1,550 → 1,079**, movie-watchlist source **521 → 50**; database median **23.172 → 21.000ms**, complete HTTP **38.846 → 30.034ms**. Full-history deterministic reference and reaction responses match. Seven merging sources remain on their compatibility window; not a globally bounded feed. Local measurements only. [Raw results, checks and limits](performance/2026-10-10-group-activity-bounded/README.md).

### 10 October 2026 — rating save, notification paging and Insights

Accepted local PostgreSQL comparison (five measured alternating pairs after warmups): Insights **54.466 → 14.675ms**; archived output values preserved for three years, including rewatches and episode/plan edge cases. Notification first response **514,518 → 15,038 bytes** (1,004 → 25 raw/cards returned), but repository median **11.741 → 18.249ms**: record as payload reduction, not a measured latency win. Traversed 1,002 deduplicated cards over 41 pages, tested global unread/read-all and compact schedule/badge data. Rating save gate test verifies TMDB no longer blocks success; no elapsed-time claim. 37 backend and 53 Flutter tests pass, typecheck/analysis clean, simulator restart without runtime errors. No production or physical-device measurements. [Report and raw results](performance/2026-10-10-backend-batch/README.md).


### Notification SQL — 10 October 2026

Matched local 1,004-row fixture, ten measured alternating pairs after two warmups: visibility SQL median **14.041 → 3.775 ms**, selection + hydration **20.421 → 13.514 ms**. Duplicate sort rows **1,004 → 4**. All 41 pages plus 164 identity/status page comparisons match archived query. 13 focused tests/typecheck pass. No index/migration/deployment or native timing claim. Evidence: `performance/2026-10-10-notification-sql/README.md`.


### Group Activity selected-card hydration — 10 October 2026

Local route, PostgreSQL + Firestore emulator, seven measured alternating pairs per fixture. Normal database median **21.657 → 16.371ms**, HTTP **31.503 → 26.209ms**. With 5,000 extra temporary fictional watches: database **103.701 → 21.511ms**, HTTP **113.118 → 32.272ms**; rich rows **6,106 → 103**; serialized repository data **13,457,983 → 362,641 bytes** (not wire/RSS). Full-history deterministic references match; timestamp ties now explicitly use IDs. 22 focused tests/typecheck pass. Modern candidate and full-data hydration bounds added; six compact legacy/action metadata histories remain unbounded. No migration/deployment/native timing claim. Evidence: `performance/2026-10-10-group-activity-hydration/README.md`.


### Concurrent backend screen-call subsets — 10 October 2026

Unchanged local 10-connection pool, real PostgreSQL + Firestore emulator; 640 measured GETs over two fictional accounts. Corrected 400-title fixture median isolated → mixed: Home **7.13 → 15.38ms**, Profile **8.74 → 21.78ms**, Group **23.86 → 34.25ms**. Mixed acquisition p95 1.93–3.01ms; 24-request burst 10.85–13.80ms. Group still executes 75 SQL statements; Home per-movie friends 18 and plans 19. No pool change justified from this run; reduce query volume next. This is a backend opening subset, excluding recommendations/trending/auth verification/native rendering and background imports. Earlier exploratory broad-friends-feed run was rejected. All response checks and typecheck pass. Evidence: `performance/2026-10-10-concurrent-screens/README.md`.


### Group Activity SQL relation batching — 10 October 2026

Approved reduction of 75 statements. Final paired local normal feed **75 → 34 SQL calls**, database median **22.031 → 16.037ms**, HTTP **31.565 → 25.770ms**. Large temporary 5,000-entry fixture **53 → 27 calls**; database **20.732 → 18.400ms**. Concurrent Group median **31.949 → 28.514ms** and burst **82.400 → 70.567ms**; other endpoint/pool metrics mixed. Exact responses and full-history reference match. 25 focused tests/typecheck pass. No pool/schema/deployment/native changes. Evidence: `performance/2026-10-10-group-query-batching/README.md`.


### Home friends and watch-plan query batching — completed locally 10 October 2026

User approved Home friends lookup and watch-plan preview optimisation, emphasising slow plans. Combined friendship directions and compact membership counts; batch group requester/responder/candidate people and media; batch direct-plan people while retaining all Home scheduling/confirmation state. No new partial loaders or cache. Populated fixture SQL: friends **18 → 5**, group plans **19 → 11**, direct plans **21 → 15**. Isolated Home request-set median **10.048 → 8.112ms**; mixed **19.464 → 21.060ms** and burst **59.419 → 59.443ms** show no broad latency improvement. Larger-library account has empty plans and must not be used to claim populated-plan gains. Exact responses preserved; 12 focused tests/typecheck pass. No production deployment or native timing claim. Next proposed diagnostic is deployed-device Home-to-cards timing correlated with server requests; not yet implemented. Evidence: `docs/performance/2026-10-10-home-query-batching/README.md`.


### Background import contention — completed locally 10 October 2026

User requested investigating background import contention. Found bulk movie (25 workers), TV (10) and movie-refresh (5) jobs sharing the API database pool. Added a shared per-process two-title limit across those entry points, retaining interactive hydration outside the queue, and fixed FIFO slot handoff in the existing limiter. Controlled read-only workload uses real bulk scheduling with modeled 10ms connection holds, not actual TMDB/catalogue writes. Concurrent Home median quiet/old/limited **29.53 / 132.02 / 25.31ms**; connection acquisition p95 **3.00 / 51.01 / 3.99ms**. Modeled import batch slows **121.21 → 617.95ms**; all items complete and screen responses match. Nine tests/typecheck pass. No deployment or production root-cause claim. Separate workers, people/company maintenance, personal library imports and multiple server processes remain outside this budget; proposal to measure actual job overlap next, not approval for infrastructure changes. Evidence: `docs/performance/2026-10-10-import-contention/README.md`.


### Home timing trace completed — 10 October 2026

User requested measurement of the Home/watch-plan delay using the local backend
before their planned merge. Completed five fresh release launches on their
approved iPhone 16 Pro (iOS 27.0.1), isolated Flixie Benchmark app, native Firebase
Auth emulators and populated localhost flixie_runtime_fixture. No production work.

Final medians: Dart entry → first plan frame **363.638 ms**; Home mount → first
plan frame **201.671 ms**; all observed plan loads after Home mount **238.121 ms**.
Direct/group first request transport **224.001/172.793 ms**, server application
**28.2/29.5 ms**, repository/service data work **14.7/17.0 ms**. JSON decode below
1 ms. These overlapping spans must not be summed. Card frame excludes poster
completion; this is a current baseline, not proof of improvement or production speed.

**Concrete next candidate (suggested, not implemented): startup/resume duplicate
work.** All five final runs read the profile twice; two repeated group plans,
notifications, recommendations, continue watching and trending (one also direct
plans). Trace and source indicate initial resumed lifecycle recovery overlaps
startup and invalidates Home again. The initial pilot showed the race in 3/5 runs.
Consider initial-foreground handling and shared/fresh profile recovery, preserving
real background return, expiry and explicit retry; verify against the same trace.
Production occurrence/frequency remains unmeasured. User plans to merge themselves,
then test deployed backend using simulator/dedicated test account.

Evidence, raw pilot/final traces, source hashes, exact limits and rerun commands:
[Home timing report](performance/2026-10-10-home-timing/README.md). Thirty distinct
focused Flutter tests and two backend timing tests passed; analysis clean and
running dev simulator hot restarted. Wi-Fi fixture bridge closed after capture.


### Group Activity remaining history scans — completed locally 10 October 2026

User requested the remaining Group Activity history scans. Implemented adaptive
legacy candidate probing over six sources, full history only for selected exact
member/media pairs, and linked movie children only for bounded modern parents.
Starts with 256 actions plus an exhaustion probe; expands when merging leaves
fewer than 50 certifiable cards. Dense timestamp ties fall back once to complete
compact history. Merging, source/score ordering, badges, spoilers, membership,
card IDs and reactions remain equal to archived and unlimited-history references.
Legacy watched suppression now uses SQL EXISTS instead of Prisma distinct over
all historical viewing entries for selected pairs. No new cache/schema/migration.

Seven paired measured local runs per condition: +5,000 legacy reviews database
**67.556 → 21.096ms**, HTTP **80.499 → 32.734ms**, returned top-level rows
**6,004 → 913**. Normal DB **29.779 → 27.231ms**, HTTP **41.215 → 41.730ms**
(effectively flat), SQL calls **34 → 35**. Old-edit stress DB **22.878 → 18.852ms**.
Do not claim universal improvement: modern-entry-only stress DB **22.400 →
26.410ms**, identical-date legacy stress **132.123 → 134.548ms**. Physical SQL
rows examined are not the returned-row metric. One prolific pair, timestamp ties
and adaptive retries remain potentially history-sized; all reads are not globally
bounded. Existing indexes reused. No production/native benchmark or deployment.

30 focused tests and typecheck pass. Five real local fixture variants match full
JSON and populated reactions; temporary fixture rows cleaned and verified. Evidence:
[Group history report](../../FlixieBE/docs/performance/2026-10-10-group-history/README.md).
The separate Home trace's duplicate startup/resume profile reads remain an
unimplemented next candidate; this task did not change lifecycle recovery.


### First launch versus genuine background return — completed locally 10 October 2026

User requested fresh startup-profile reuse without losing real background recovery. AuthProvider now requires observed hidden/paused before ordinary resume recovery; initial foreground and inactive-only interruptions restart polling without another profile read or Home invalidation. Recovery errors and explicit retry still recover. Resume during startup joins existing restoration.

Five release physical iPhone runs against local fixtures: profile counts **1,2,1,1,2 → 1,1,1,1,1**, no repeated Home endpoints after. Median Dart-entry-to-first-plan frame **421.686 → 323.651ms**; Home-mount-to-card **140.594 → 136.483ms**, effectively flat. Small sequential Wi-Fi samples do not prove the full timing improvement is caused by this fix. 34 focused auth tests pass, analysis clean, simulator restarted. Existing Home assertion at line128 also fails on unchanged baseline; preserved and documented. Physical background-return timing was not remeasured; lifecycle recovery covered by regression tests. No deployment/merge.

Evidence: [startup/resume report](performance/2026-10-10-startup-resume/README.md). This completes the duplicate startup/resume candidate mentioned in the preceding history entry.


### Release confidence — verified locally on physical iPhone 10 October 2026

Resolved the previously documented Home account-switch test mismatch: assert reuse of the new account’s fresh startup profile, then verify explicit refresh fetches that account again. 35 focused Home/auth/recovery tests pass and static analysis is clean. No app implementation changes required.

Physical release Flixie Benchmark on Lozza Ds iPhone: 15 fresh-process cold launches pass (signed out, signed in with 20/400 titles), plus all 50 native lifecycle scenarios pass (five repetitions × two library sizes × startup signed in/out, email login, genuine resume and throttled resume). Genuine resume reads profile once, quick repeat reads zero; login profile/terms once. Transport audit clean. Native harness updated for current Home layout: visible persistent Watchlist action plus loaded Alien title, which may be below fold. Changed boundary explicitly recorded; no historical speed comparison. First locked-phone attempt and stale-finder failure preserved with successful rerun evidence. Local fixture/emulators only, bridge closed, no production/merge/deploy or full regression suite.

Evidence: [release-confidence report](performance/2026-10-10-release-confidence/README.md). Prior Home assertion failure is now resolved. Further optimisation should follow measurements after the user’s backend deployment, not speculative refactoring.
