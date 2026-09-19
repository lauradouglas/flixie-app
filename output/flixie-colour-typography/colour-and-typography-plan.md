# Flixie colour & typography plan

Proposed brand extension · 18 September 2026

## Design decision

Keep Flixie's original wordmark, vivid purple and rounded personality. Pair the purple with a softer mint and warm peach. Use Manrope as the working voice everywhere in the app; introduce Newsreader only for occasional cinema-club editorial moments outside everyday UI. The result should feel social and inviting, with enough restraint to work on clothing.

This is a proposal, not a change to the live theme. It is based on the current `FlixieColors` and `FlixieTypography` definitions, the existing PNG wordmark, and the softened After Hours F.

## 1. Core brand colours

| Role | Name | HEX / RGB | Use |
|---|---|---|---|
| Primary | Flixie Purple | #7C4DFF / 124, 77, 255 | Main calls to action, selected navigation, primary brand fields and recognition |
| Secondary | Soft Mint | #65D6C4 / 101, 214, 196 | Social prompts, shared-watch highlights, supporting details and occasional merchandise accents |
| Tertiary | Peach | #F1A77A / 241, 167, 122 | Editorial highlights, warm invitations, limited club editions and small celebratory accents |

**What changes:** the app's present cyan #00D1C7 becomes the softer #65D6C4. The primary purple and existing peach stay exactly as they are. This is an intentional reduction in saturation for the supporting colour, not a wholesale palette replacement.

Purple brings the identity; mint separates the social layer from the brand's main action; peach adds warmth to the dark cinematic setting. Do not assign equal visual weight to all three. A screen with three competing bright buttons will lose hierarchy even if the colours harmonise.

The purple in the supplied wordmark is a lighter, tonal raster treatment, not a reliable single solid ink swatch. Preserve that supplied wordmark as-is. #7C4DFF is the existing app's primary colour and the solid brand standard; do not recolour or reconstruct the wordmark to make the two numerically identical.

## 2. Supporting colours and surfaces

| Token / role | HEX | Use |
|---|---|---|
| primaryPressed | #6534E8 | Pressed/hover purple and purple text on light surfaces |
| primaryText / Lilac | #B9A0FF | Purple-family text and line icons on dark backgrounds; the F app icon foreground |
| background / Midnight | #120A24 | Main cinematic canvas and app icon background |
| surface | #1A1033 | Cards, sheets and primary raised surfaces |
| surfaceElevated | #27194A | Higher elevation, menus and nested detail surfaces |
| textPrimary | #F5F7FA | Main dark-theme copy |
| textSecondary | #B7C2D0 | Supporting dark-theme copy |
| textMuted | #A0ACC0 | Lower-emphasis metadata, without making it faint |
| Bone | #F3F0E9 | Merchandise blanks, editorial backgrounds and warm light layouts |
| lightTextPrimary | #120A24 | Type on bone, mint and peach |
| lightTextSecondary | #51495F | Supporting copy on bone |
| lightMintText | #19776B | Mint-family text on bone/light layouts |
| lightPeachText | #99552D | Peach-family text on bone/light layouts |
| controlOutline | #8C7AAE | A visible boundary where an interactive control depends on its outline |

Lilac is a tint within the purple family, **not a fourth equal brand colour**. The existing softened icon stays lilac-on-midnight: it reads clearly at small sizes and still belongs to the purple brand. Do not put purple, mint and peach into the small app icon simultaneously. The full identity carries the wider palette.

Use subtle existing dividers for nonessential separation. A divider is not automatically a sufficient boundary for an interactive field; use the stronger outline when the boundary is needed to identify the control. Focus indication must stay visible and should not rely on colour alone.

## 3. Usage balance

For brand-owned layouts, use roughly **75% neutral surfaces, 20% purple-family emphasis and 5% supporting accents** as a starting composition guide, not a quota. Posters, avatars and user images are excluded from that estimate.

- Choose mint **or** peach as the dominant supporting accent in a particular composition. Both can appear when their roles are clear.
- Primary app actions remain purple. Use white text on the primary purple fill.
- Mint highlights the social aspect; it does not turn every friend, chat and card into a separate coloured container.
- Peach adds warmth to editorial and club content. Do not repurpose it as an error colour.
- Keep backgrounds quiet. Avoid purple-to-mint gradients as the default brand treatment: they make the palette feel more like generic technology branding and reproduce poorly on merchandise.
- Do not mechanically replace every cyan occurrence. Audit whether each occurrence is decorative, interactive, informational or semantic before changing it.

## 4. Contrast and semantics

Calculated from the listed opaque sRGB pairs:

| Foreground on background | Ratio | Decision |
|---|---:|---|
| White #FFFFFF on primary purple #7C4DFF | 4.81:1 | Use for normal button labels |
| Midnight #120A24 on primary purple #7C4DFF | 3.99:1 | Avoid for normal-sized text |
| Primary purple #7C4DFF on elevated surface #27194A | 3.29:1 | Avoid for normal text; use lilac instead |
| Lilac #B9A0FF on elevated surface #27194A | 7.20:1 | Good dark-theme accent text |
| Mint #65D6C4 on elevated surface #27194A | 9.04:1 | Good supporting accent text |
| Peach #F1A77A on elevated surface #27194A | 7.97:1 | Good supporting accent text |
| Midnight #120A24 on mint #65D6C4 | 10.93:1 | Use for filled mint labels |
| Midnight #120A24 on peach #F1A77A | 9.64:1 | Use for filled peach labels |
| Muted text #A0ACC0 on elevated surface #27194A | 6.92:1 | Retain for readable metadata |

These are colour-pair checks, not a whole-app accessibility certification. Alpha, overlays, imagery and disabled states change the effective colours and must be checked in context. Aim for at least 4.5:1 for normal text; do not use the large-text exception to justify small interface labels. [W3C contrast guidance](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum).

The current theme mixes black and white labels across purple components. Standardise normal purple action labels to **white** during implementation. White labels on mint or peach have insufficient normal-text contrast; use midnight.

Keep functional colours separate from brand accents: existing success #00D97E, warning/rating gold #FFC857 and error #E57373 remain semantic candidates. Pair every semantic state with text or an icon; mint must not become an ambiguous substitute for “success”. A full component audit should verify their actual foreground/background combinations before changing their mappings.

## 5. Typography families

### Manrope — the primary family

Keep the family already bundled in the app. It relates well to the rounded wordmark and softened F, while giving headings, buttons and everyday copy one coherent voice. Use a small purposeful weight set:

- 400: body and descriptions.
- 500: supporting copy and metadata where required by the current app.
- 600: labels, secondary emphasis and compact navigation.
- 700: buttons, card titles and section headings.
- 800: short hero/page headings and prominent rating numbers.

Use sentence case for functional text. Reserve uppercase plus tracking for short edition labels and a few small editorial eyebrows. Do not create a replacement “flixie” wordmark by typing the name in Manrope.

### Newsreader — an optional editorial companion

Use Newsreader Medium 500 for selected campaign headlines, film-club essays, invitation cards and larger statement graphics. Its serif shapes add a more editorial, cinematic mood beside Manrope. Suggested specimen: “Stay for the credits.”

Keep it out of buttons, tabs, chat, search, metadata and dense film lists. One editorial serif moment per composition is enough. If the identity feels too literary in testing, omit Newsreader and keep the entire system in Manrope; coherence matters more than having a font pairing.

Newsreader is distributed under SIL Open Font License 1.1 according to its [official repository](https://github.com/productiontype/Newsreader). The [Google Fonts Manrope package](https://github.com/google/fonts/tree/main/ofl/manrope) includes its own OFL file. Retain the applicable licence files when bundling or sharing font binaries; use official sources. The preview loads these families for comparison; Newsreader has not been added to the Flutter build.

## 6. Practical type scale

Sizes below are starting logical pixels in Flutter and CSS pixels on the web. Respect the platform's text scaling; they are not fixed physical measurements. Existing values are retained where useful; the proposed body/action baseline is a little larger for clarity.

| Role | Family / weight | Size / line height | Tracking |
|---|---|---|---|
| Marketing display | Newsreader 500, or Manrope 800 | 48–64 / 1.05–1.1 desktop; 32–40 / 1.1 mobile | Newsreader -0.01em; Manrope -0.02em |
| App hero | Manrope 800 | 30 / 36 | -0.02em |
| Page title | Manrope 800 | 26 / 32 | -0.01em |
| Sheet title | Manrope 700 | 24 / 30 | 0 |
| Section title | Manrope 700 | 20 / 26 | 0 |
| Card title | Manrope 700 | 17 / 22 | 0 |
| Primary body | Manrope 400 | 16 / 24 | 0 |
| Supporting text | Manrope 500 | 14 / 20 | 0 |
| Metadata | Manrope 500 | 13 / 18 | 0 |
| Button / action | Manrope 700 | 16 / 22 | 0 |
| Compact label | Manrope 600 | 12 / 16 | 0 |
| Editorial eyebrow | Manrope 700 | 12 / 16 | +0.08em |
| Rating / compact statistic | Manrope 800 | 20 / 24 | 0; tabular numerals |

The current app body is 15 px and action label 15 px; the proposed 16 px baseline is a targeted future change, not already implemented. Keep 12–13 px for short optional metadata rather than instructions or essential reading. Long body copy should have roughly 45–70 characters per line on wide layouts; let mobile lines use their natural width.

Allow meaningful titles to wrap. On small phones, landscape and increased text scale, reflow or stack metadata and actions instead of shrinking fonts or truncating important content. Check small and large phones, tablets and approximately 200% text scale; allow larger platform settings to remain usable rather than capping scaling. A type scale is only successful when its containers can grow.

## 7. Merchandise translation

- **Everyday tee and cap:** bone or lilac F on midnight/charcoal; one ink/thread. Keep mint and peach out of the core monogram.
- **Credits hoodie:** bone Manrope 700/800 statement with a lilac F. This carries the launch collection.
- **Editorial tee/tote variant:** large Newsreader 500 “Stay for the credits.” with a small original wordmark on a separate label or back-neck placement. Use midnight on bone; one optional peach detail.
- **Social edition:** mint can appear as a small sleeve, side label or sticker accent; avoid adding a second print position without considering setup cost.
- **Stickers and packaging:** rotate mint and peach backgrounds with midnight copy. Keep the brand name or purple-family cue visible so the collection remains recognisable.

For screen print, begin with positive lines at least 0.5 mm and open gaps at least 0.7 mm; confirm with the printer and substrate. Inspect serif strokes at final size. Use Manrope for small print and embroidery; avoid Newsreader's finer details on caps. Begin embroidery lettering around 5–6 mm high with strokes/gaps around 1.2–1.5 mm, then approve a sew-out. These are conservative starting targets, not universal production limits.

HEX values are screen definitions, not ink or thread recipes. Select spot inks and threads against physical samples. Do not invent Pantone matches. Outline approved print typography in production copies while preserving a live-text editable source. The original wordmark still requires its editable master for final separations.

## 8. Implementation order

1. Approve purple + soft mint + peach, and whether Newsreader earns a place in the editorial system.
2. Introduce the new mint as a proposed brand token, then review existing cyan uses by role. Set corresponding readable text colours; do not globally replace hexadecimal strings.
3. Standardise purple action labels to white; use lilac for dark-theme text accents.
4. Consolidate existing Manrope roles and test the proposed 16 px body/action baseline on real content and larger text settings.
5. Bundle Newsreader only where editorial work needs it; the app does not need a second font just because campaign material uses one.
6. Apply the softened F icon pack separately, then check actual devices and store previews.
7. Produce one tee/cap sample and one statement print before expanding the range.

No app theme, font declarations, icon resources or existing logo files have been changed by this plan.
