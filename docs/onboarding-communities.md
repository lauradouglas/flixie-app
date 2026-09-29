# Optional communities during setup

Implemented locally following the user's approval on 26 September 2026.

The post-account flow remains four steps: country/services → taste → optional
communities → first picks. The former standalone privacy/spoiler stage is an
expandable section on the first-picks page. Its existing controls and defaults
remain available. Account creation, favourites semantics and first-pick ranking
are outside this change.

## Suggestions and consent

- Up to three unjoined communities are suggested from actual genre metadata for
  up to five selected titles and explicitly selected genres. Genre choices count
  twice, each matching title once; ties sort by community name.
- Suggestions explain the match. Failed metadata reads fall back to browsing,
  never to fabricated personalised suggestions. An empty directory avoids all
  title metadata reads. Movie genre IDs and exact show genre names are supported.
- Anime remains available under Browse communities; Animation does not imply Anime.
- New memberships start unchecked. Checking a row only changes local selection.
  Join N & continue makes authenticated membership requests. Continue with no
  selection and Skip for now send no joins.
- Partial success remains visible and persisted. Retrying only submits the remaining
  selected memberships; Skip discards only unsubmitted selections. Existing joined
  communities cannot be accidentally left by going back through setup.
- Joining never enables public sharing. The screen explains that already-public
  reviews can appear in eligible joined feeds. No follow, invitation or public post
  is created.
- Explore your communities completes setup and opens `/social?tab=communities`;
  that route selects the Communities tab, whose directory reads saved memberships.

## Verification and fixtures

42 focused tests passed across setup_flow_test, setup_communities_test,
onboarding_screen_test and genre_communities_test. Coverage includes ranking,
real membership request shape, unchecked defaults, skip, partial failure/retry,
existing membership, missing metadata, pending-request disposal and 2× text at
320×640, 430×932, 844×390 and 1024×768. Static analysis and whitespace checks pass.
The focused native Patrol test also passed on the dedicated Flixie Patrol iOS
simulator: choose Alien, explicitly join Horror, open Communities, then background
and resume the app with the joined membership visible. Native networking uses an
isolated mocked membership store; it does not exercise a production backend.
No visual golden baselines were changed.

New UI/Patrol fixtures are fictional and isolated: Alien suggests Horror/Science
Fiction; a mocked membership store persists into the actual community directory.
Existing guarded local data seeds `../FlixieBE/scripts/seed-dev-genre-communities.ts`
and `seed-dev-anime-community.ts` remain applicable; no new database schema or
production data is needed for this client-only step.

No production deployment or full regression suite. Suggestions depend on available
metadata; no claim is made that every selected show maps to a movie genre community.
