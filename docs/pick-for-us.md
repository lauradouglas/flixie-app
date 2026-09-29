# Pick for me / Pick for us

Updated 26 September 2026. The user approved a guided mood-first overhaul of the
picker, preserving Flixie’s visual system and the existing lower Home entry.

## Journey

1. Choose an experience: Switch off, Feel good, Have a laugh, Get hooked,
   Feel something, Escape somewhere, Be challenged or Get scared. Keep my options
   open is the explicit default. The actual chosen mood reaches the ranking engine.
2. Set up the evening: Just me, With a friend or With a group; streaming or cinema.
   Viewers are searchable and constrained to a scrollable area. Solo works while
   social data loads or fails. Friend avatars preserve their personal borders.
   Streaming with others also offers Together or Separately.
3. Refine your picks is optional: runtime (90/120/150/180/240 minutes, default 120),
   genre, content exclusions, rewatches and eligible rental opt-in. Mood and genre
   remain separate. Exclusion controls do not promise certainty from missing data:
   titles with unknown relevant content are excluded.
4. Results present one film with alternatives, runtime, overview and factual reasons.
   View movie is the fixed solo action; Make a Watch Plan is the social action.
   Social viewers can also open the movie details. The existing plan sheet receives
   the selected friend/group and venue and still requires explicit submission.
5. Show different films excludes every film already returned in this search, up to
   60 IDs, without recording a dislike. If none remain, keep the previous picks and
   offer refinement. Back/Change preferences preserve inputs. A new search after
   editing starts fresh. Retry after a request failure preserves the criteria;
   failure while replacing results preserves the previous shortlist.

The primary action remains reachable while scrolling. At large text sizes the
secondary result actions scroll with content so the footer does not crowd out the
film. Layouts inherit dark/light themes, use app typography and reflow on narrow
phones, tablets and landscape. The flow does not introduce decorative animation.

## Request and compatibility

`POST /recommendations/pick-for-us` still authenticates the viewer server-side.
Neither friendId nor groupId means solo; otherwise exactly one is allowed, with
friendship/accepted membership checked before accessing taste. Groups support
2–12 accepted viewers. Private/unrelated groups are not selectable by arbitrary IDs.

Existing fields/defaults remain unchanged. **New optional field** `excludeMovieIds`
is an array of at most 60 positive safe-integer movie IDs, default `[]`. Both cinema
and streaming exclude them before selecting the shortlist and checking providers.
No database migration, persistent feedback or notification changes are introduced.
Build 70 remains supported. Deploy the additive backend before expecting fresh
shortlists from new clients; the frontend also rejects repeated films from an older
server and retains the previous picks instead of pretending they are new.

The structured UI uses existing mood IDs from `WatchlistMood`. The backend retains
legacy mood aliases and optional bounded `request` text for older clients; this
screen does not add a free-text interpretation promise. Runtime, content, personal
rejections, country and service constraints remain mandatory. This overhaul uses
the existing title-level experience/taste engine, not a new recommendation model.

Together requires an included service for at least one viewer. Separately requires
a shared provider available in every viewer’s country. Rentals are opt-in and only
apply to solo/together streaming; actual availability reasons label paid rentals.
Cinema uses the existing country-specific now-playing catalogue, not showtimes.
The runtime limit excludes adverts and trailers. Provider lookup failures never
count as availability. The bounded existing candidate pools and lookup limits remain.

## Local testing and preview

`test/support/pick_fixture.dart` contains fictional viewers and deterministic
recommendations for widget/Patrol tests. Its film results are UI fixtures, not proof
of recommendation quality; backend tests exercise actual ranking and availability.

For a fully offline **solo** preview:

```sh
flutter run -t tool/preview_pick_journey.dart -d <dedicated-device>
```

This preview has no friends/groups to avoid connecting watch-plan actions. Movie
navigation ends at a labelled preview destination. Actual Flutter screen captures
are in `design/pick-journey-2026-09-26/index.html` (fictional data, no live controls).

Local database fixtures (from FlixieBE):

```sh
NODE_ENV=development node --env-file=.env.local -r ts-node/register scripts/seed-dev-pick-journey.ts --dry-run
NODE_ENV=development node --env-file=.env.local -r ts-node/register scripts/seed-dev-pick-journey.ts
```

The guarded script refuses remote targets and identity collisions. Upserts preserve
existing edits. Fictional `dev_pick_casey`, `dev_pick_robin` and `dev_pick_ellis` have
saved services and overlapping watchlists containing local catalogue titles such
as Alien, The Odyssey, Spider-Man and Obsession. Casey/Robin are friends and accepted
members of the private fixture group; Ellis is pending. Profiles do not publish
activity. These are data fixtures, not production logins; no real account credentials
or relationships are created. Availability and catalogue metadata are not fabricated.

## Verification

- 22 widget tests: preserved original picker coverage plus guided mood submission,
  separate filters, alternatives/exhaustion, older-server repeats, failure recovery,
  independent social loading, avatar borders, back navigation, duplicate submission,
  disposal and phone/tablet/landscape at 1.8× text; light theme included.
- One request-contract test checks real service JSON and optional defaults.
- 19 backend controller/ranking tests pass, including new exclusions in both venues,
  exhaustion, input validation and legacy requests without the new field.
- 14 build-70 compatibility checks pass. TypeScript checking passes.
- Dedicated iOS Patrol journey passes: mood → picks → different films → movie →
  app background/foreground → return → revise preferences, with fictional services.
- Static analysis and patch whitespace checks clean. No goldens regenerated.

No production deployment, Android native run or live streaming-provider verification
was performed. The full regression suite was not run.

## Movie-detail navigation fix — 27 September 2026

Home now pushes the routed `/pick-for-us` page on the same shell navigator as
movie details. Previously a root Navigator MaterialPageRoute covered the shell,
so a detail route could open underneath the picker and appear unresponsive.
The focused journey harness now launches the picker through a nested shell and
checks solo and shared alternative detail navigation, including returning to the
selected result. All 23 focused picker tests passed.

## Direct exit — 27 September 2026

The app bar now has a Close picker action at every stage. Close exits the journey
in one tap, including during loading and after repeated changes of preferences.
Back still moves between stages. Direct route entry without a previous page falls
back to Home. All 26 focused picker tests passed, covering close from mood,
evening, results and an in-flight request completing after disposal.
