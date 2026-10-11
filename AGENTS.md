# Flutter UI conventions

## Flutter engineering guide

For Flutter implementation, review and debugging, read and apply
`docs/flutter-expert-guidance.md`, adapted from the VoltAgent Flutter expert guide
at the user's request. Combine it with Impeccable for design work. The specific
project rules below and explicit user instructions take precedence.

## Feature structure

Follow `docs/architecture.md` for the current feature-based layout and ownership
rules. Watchlist is the reference cleanup. Keep UI, observable state, pure
selection and API access in their owning feature; add abstractions only when
they own useful logic. New tests should mirror feature paths. Other features
are migrated incrementally, with focused regression coverage.

## Official Flutter plugin

The user requested the official `dart-flutter` plugin from
https://github.com/flutter/agent-plugins (installed in Codex on 29 September 2026).
Use its applicable skills and available Dart MCP tools alongside the guides here.
For functional edits under `lib/`, refresh the relevant running development app
with hot reload when available; use hot restart when initialization changes
require it, accounting for loss of transient state. Skip refresh for documentation
and test-only edits. Preserve this repository's focused testing and Patrol rules;
plugin recipes do not authorise replacing the test harness or deploying the app.

## TypeScript engineering guide

For TypeScript tooling or cross-repository backend work, read and apply
`../FlixieBE/docs/typescript-pro-guidance.md`. When editing the backend, also follow
its own AGENTS.md, including supported-client compatibility requirements.

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
and its outcome. Run only focused checks relevant to the change while editing.
Run the full `scripts/test-regression.sh` suite only when explicitly requested
or in GitHub workflows; do not run it automatically for each prompt. Report
existing failures rather than skipping them or weakening assertions.

Device tests live in `patrol_test/`. Use `scripts/test-patrol.sh -d <test-device>`
for changes to favourites/ranking, activity-sheet navigation, profile gallery
layout, and watchlist paging. Use a dedicated simulator/emulator: Patrol reinstalls the app. Extend this
suite when adding another critical user journey. Fixtures must remain isolated
from real accounts; do not introduce production credentials into tests.

Do not regenerate visual goldens solely to make checks pass. Inspect differences
and update baselines only for intended design changes. See `docs/testing.md` for
coverage, setup, and the baseline review.

## Retired production build

iOS **1.0.0 build 70** compatibility was explicitly retired by the user on
6 October 2026. Future changes do not need to preserve its API shapes, request
defaults or notification routes, or run its dedicated compatibility checks.
Historical details remain in `../FlixieBE/docs/build-70-compatibility.md`.
This does not authorize deployment or removal of existing functionality.

## Product idea memory and next-step recommendations

The user wants ideas remembered in detail across Flixie work. Read
`docs/product-ideas.md` before proposing product priorities. When the user shares
an idea, update that file with their intent, concrete details, benefits,
dependencies, unresolved choices and status. Distinguish user requests from
assistant suggestions; discussing an idea does not authorize implementation.
Preserve useful detail when refining ideas and mark completed or rejected ideas
rather than silently losing their history.

When asked “what should we do next?”, assess the current implementation and
outstanding issues alongside this backlog. Recommend two or three options with
specific reasons, likely scope, dependencies and tradeoffs, and identify the
strongest next step. Do not simply repeat the newest ideas or treat previous
assistant suggestions as user-approved requirements. Keep this record current
when work is implemented or the user's priorities change.

## Local feature test data

When implementing Flixie features, provide representative local database fixtures
so the user can test the UI immediately. Prefer recognisable titles such as The
Odyssey, Alien, Spider-Man and Obsession. Use guarded, rerunnable seed scripts and
fictional fixture accounts; never seed production or overwrite real users'
activity. Include relationship overlaps and privacy/spoiler cases where relevant.
Movie social fixtures: `../FlixieBE/scripts/seed-dev-movie-opinions.ts`.

## Flixie branding

Always use the Flixie text wordmark (white **flix**, purple **ie** on dark surfaces), matching `lib/core/widgets/flixie_wordmark.dart`. Use the official Flixie F icon for compact branding, not a generic movie icon. Preserve this rule in admin/web work as well as the app.
