# Flutter UI conventions

## Bottom sheets

Bottom sheets must be presented with `useRootNavigator: true` and
`useSafeArea: true`. For sheets that can grow beyond a small viewport, use a
viewport-relative bounded height and make the body scrollable. This prevents
the sheet from rendering under iOS status chrome or the app's bottom
navigation.

## Responsive layouts

Before shipping a UI change, consider small phones, large phones, tablets,
landscape, and increased system text scaling. Prefer responsive reflow,
wrapping, or a scrollable detail treatment over truncating meaningful content
with an ellipsis. Use the available width to adapt layout (for example, stack
metadata or move secondary actions to another line on narrow screens), while
preserving clear touch targets and avoiding overflow.

## User avatars and borders

Always render each user's avatar with their own badge border. Use
`ProfileAvatarView` with that user's `profileBadges`; do not omit the badges or
replace the user's border with a generic ring. This applies to activity cards,
Home previews, friends and group lists, profiles, chat, and notifications.

Preserve `profileBadges` through API selects, feed mappings, models, and copied
activity items. If a border is missing, check the data pipeline before changing
the widget. Compact rows must reserve space for the complete border and keep
avatar images and ring widths consistent, using `SpecialAvatarFrame` where
needed without applying the frame twice.

## Regression checks

For behaviour changes, add or update a regression test covering the user action
and its outcome. Run the affected widget tests while editing. Before declaring a
change ready, run `scripts/test-regression.sh`; report existing failures rather
than skipping them or weakening assertions.

Device tests live in `patrol_test/`. Use `scripts/test-patrol.sh -d <test-device>`
for changes to favourites/ranking, activity-sheet navigation, and profile gallery
layout. Use a dedicated simulator/emulator: Patrol reinstalls the app. Extend this
suite when adding another critical user journey. Fixtures must remain isolated
from real accounts; do not introduce production credentials into tests.

Do not regenerate visual goldens solely to make checks pass. Inspect differences
and update baselines only for intended design changes. See `docs/testing.md` for
coverage, setup, and the baseline review.
