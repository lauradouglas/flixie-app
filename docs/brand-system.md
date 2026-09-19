# Flixie app colour and typography

Implemented 18 September 2026 from the approved colour/typography plan.

## Identity and colour roles

The existing wordmark remains the primary identifier. Shared app tokens live in `lib/app/theme/app_theme.dart`.

| Role | Value | Application |
|---|---|---|
| Primary purple | #7C4DFF | Main actions and strong brand fills; unchanged |
| Purple shade | #6534E8 | Darker purple/container and light-theme accent text |
| Lilac tint/text | #B9A0FF | Readable purple-family text, selected labels and accents on dark surfaces |
| Secondary mint | #65D6C4 | Shared-watch and social highlights; replaces cyan |
| Secondary shade | #19776B | Strong mint-family container; pair with white |
| Secondary tint | #95E3D7 | Light mint-family container; pair with midnight |
| Tertiary peach | #F1A77A | Warm editorial/invitation accents; unchanged |
| Tertiary shade | #99552D | Strong peach-family container; pair with white |
| Midnight | #120A24 | Dark background and foreground on mint/peach fills |
| Dark surfaces | #1A1033 / #27194A | Cards, sheets and raised surfaces |
| Bone | #F3F0E9 | Warm light-theme canvas |
| Light supporting text | #51495F | Supporting text on light surfaces |
| Control outline | #8C7AAE | Visible input/control boundaries |

Normal purple action labels are white. Mint and peach filled surfaces use midnight labels. Existing green success, gold warning/rating and red error colours retain their functional roles. The plan's colours are not assigned to new features or avatar borders.

`primaryTint` now actually represents the lilac tint; primary fills continue to use `primary`. Explicit purple-on-dark outlined/text actions and selected controls were adjusted where they bypassed the theme. Explicit black labels, checkmarks, loading indicators and unread counts on purple were changed to white. Success/warning labels keep their darker foregrounds.

## Typography

Manrope remains the only bundled UI family. Newsreader is reserved for optional editorial/merchandise work and has not been added to the application.

`lib/app/theme/flixie_typography.dart` remains the source of truth:

- Hero 30/36, weight 800, tracking -0.6 px.
- Page title 26/~32, weight 800, tracking -0.26 px.
- Sheet 24/30 and section 20/26, weight 700.
- Card title 17/~22, weight 700.
- Body 16/24, weight 400; body-large 16/24, weight 500.
- Action label 16/22, weight 700.
- Supporting 14/~20 and metadata 13/~18.
- Compact label 12/16, weight 600; editorial eyebrow 12/16, weight 700, tracking 0.96 px.

Primary body copy uses the primary text colour; supporting roles remain muted. Filled, elevated, outlined and text-button themes explicitly inherit the action type role. Standard filled/elevated/outlined buttons have minimum 48 px height but can grow with content. App bar titles use the shared Manrope section style. Section headers preserve supplied case by default, including stats headings.

Respect system text scaling and allow wrapping/reflow. Existing small role-specific overrides are retained where they serve compact layouts; this is not a blanket replacement of every numeric font size.

## Verification

`test/flixie_brand_theme_test.dart` checks semantic foreground/background contrast in both themes, selected chip contrast, action label colours and interactive controls at 200% text on 320×568, 430×932, 844×390 and 834×1194 layouts.

Existing responsive tests cover library import, watch plans, notification inbox, conversations, prompt sheets and Pick for Us. Seven intentional visual references were inspected and refreshed: library import at phone/tablet widths, group recap at ordinary/large text, activity reply and watch-request cards/options. These are Flutter widget-test renders, not native simulator screenshots.

Core theme/type static analysis passed with no issues. The full app analysis initially reported only informational lints; the new-test lint was fixed, leaving unrelated existing test/vendor suggestions.

The broad test run exposed unrelated failures in search debounce timing, authentication timeout state, watch-plan empty-message expectations (three tests), and MovieList update serialization. All six were reproduced against an isolated copy of the application's source captured before this change. An additional stale primary-colour expectation was corrected to the actual pre-existing #7C4DFF, and the secondary-colour expectation was updated to the approved mint.

The app icon pack remains a separate asset deliverable from the earlier icon task. This colour/typography change does not replace native launcher assets, splash artwork, the original logo, or user avatar/badge data.
