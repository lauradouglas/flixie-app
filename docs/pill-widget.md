# Shared pills — Option A

Use `FlixiePill` from `lib/core/widgets/flixie_pill.dart` for all standalone pills. Appearance is defined once in `FlixiePillStyle`; the app's light and dark chip themes share those tokens.

- `choice` and `filter`: controlled selection via `selected` and `onSelected`.
- `action`: callback via `onPressed`, optional selected state for active filter menus.
- `label`: noninteractive metadata, compact by default. Use `compact: false` inside a menu trigger with its own touch target.
- `colorKey` on `label`: use the genre name for a stable decorative colour. Genre labels share six accessible colour pairs in dark/light themes; interactive pills cannot opt into this palette.
- `avatar`: optional icon or complete avatar widget. Keep the user's own `profileBadges` and reserve room for the border. Selection checks never paint over an avatar.
- Null callbacks disable interactive pills. Labels remain readable and noninteractive.

Option A uses 12px corners, no outline, a quiet dark/light surface and pale lilac selection with dark text. Interactive pills keep a 48px touch target; text wraps instead of being ellipsized. Semantic icons can retain their meaning-specific colour. Call sites cannot override fill, border or label typography.

## Migration audit

Audited all native Flutter chip constructors, named chip/pill/tag/badge helpers, and custom rounded text containers. Migrated standard and bespoke pills across:

- Watchlist time/genre/service controls, filter sheets and title type labels.
- Pick for me/us, onboarding, favourite genres and library import.
- Movie/show/person details, review/recommendation inputs, watch entries, genres, score/status badges, movie lists and sort menus.
- Home featured/trending cards, profiles, favourite/rating sections and activity.
- Social filters, visibility, group roles/status, group insights, counts, chat metadata, requests and review reactions.
- Watch planning labels and filters, stats and Wrapped tags/year menus.

Intentional separate controls: primary/secondary buttons, attached segmented controls, underlined navigation tabs, circular counters and icon-only controls, search fields, sheet handles, progress indicators, provider logos and avatar badge borders. These serve different roles and are not standalone pills.

`test/flixie_pill_test.dart` prevents new raw Material chips outside the shared component and checks behaviour, keyboard activation, minimum interactive size, responsive wrapping and both themes. Run with `PILL_CAPTURE=1` to write the theme gallery to `/tmp/flixie-pill-gallery.png`.
