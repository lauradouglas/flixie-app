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
