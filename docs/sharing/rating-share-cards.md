# Rating share cards

The existing Share action after a saved movie/show rating opens the rating-card
editor. Review cards keep their existing content and appearance.

- Six styles: Poster sticker, Compact poster, Pocket ticket, Polaroid, Circle stamp, Full Story.
- All six styles offer Transparent, Black, Lilac and Bone backgrounds.
  Full Story applies the choice to its full canvas, with dark text on light
  backgrounds and white text on charcoal/transparent. Shaped styles retain their
  card surface with the chosen canvas around them. Transparency exports as alpha.
- Card surfaces keep Flixie's dark ink or the ticket/polaroid cream, independent
  of the movie palette. Poster colours are confined to the feathered artwork area.
- Titles use the full content width, wrap at word boundaries and reserve their
  measured height. Ticket scores sit beneath titles. Circle content respects its
  curved edges; longer quotes reflow into a matching caption below the circle.
- Username and verdict are separate lines. A long username scales independently;
  Pip has reserved footer space below the username.
- The poster remains proportionally fitted. Its actual edge pixels extend into
  empty bands with a soft fade; no dominant-colour wash or generated artwork.
- None and Classic Pip are always available. Cinema Club appears only for the
  current account's verified entitlement. A card decoration does not update the
  account's active Pip. Each new editor opens without a Pip selected.
- The watch-note switch controls exported note visibility. A separate editable
  share quote uses up to 180 characters; longer diary notes start with an
  explicitly labelled excerpt and are never changed by the editor. All verdicts include
  the username; neutral and unanswered recommendations remain distinct.
- Output uses the existing 1080 × 1920 PNG export. Transparent margins remain
  alpha; the preview checkerboard sits outside the exported boundary. Share/save
  waits for the poster or offers a labelled fallback and retry after failure.
- Choices are local to the open editor. Each change invalidates cached bytes.
  Pip artwork is preloaded before capture.

## Local verification

Use existing fictional movie-opinion fixtures (Alien, The Odyssey, Spider-Man
and Obsession) from `../FlixieBE/scripts/seed-dev-movie-opinions.ts` for local UI
exploration; its local-target guard and fictional-account isolation must remain
in place. No schema or new server fixture is required by the editor. Do not
seed production or change another person's log to exercise image sharing.

The focused `test/features/sharing/rating_share_card_test.dart` fixtures are
self-contained and use local Alien artwork; they need no network or real account.
Run `flutter test test/features/sharing test/media_share_card_layout_test.dart`.
The opt-in `flutter test tool/render_rating_share_cards_test.dart` generates
five settled template previews and small/standard/tablet sheet captures under
`output/rating-share-cards/`. The 320px capture uses 200% system text; exported
artwork has fixed typography, while editor controls respect system scaling.
The capture harness aliases system wordmark fonts to bundled Manrope for
repeatability; production uses the existing official FlixieWordmark widget.

Actual Instagram import/placement, photo permissions and platform share-sheet
behaviour still need physical-device verification. No automatic Instagram post
or direct Stories integration is introduced.

## Compact portrait tickets (26 October 2026)

Compact poster replaces the old Cinema ticket; Pocket ticket adds the shorter
portrait layout. Both use intact posters without blur, adaptive titles and a
perforated bottom stub. Black, Lilac and Bone change the ticket paper and text
contrast; Transparent uses bone paper with transparent outer margins.
The QR asset encodes `https://www.flixie.co.uk/` with black modules, white paper
and a four-module quiet zone. Optional Pip stays above the QR stub. No backend
change or new dependency. Scanning after Instagram compression still needs a
physical-device check.

Latest background semantics (26 October): the background picker changes the actual
card/shape surface for every style. Outer 9:16 margins are always transparent.
Transparent removes the shape fill; Black uses white text, Lilac/Bone dark text.
The preview displays directly over the sheet without checkerboard. These rules
supersede the earlier outer-canvas and transparent-ticket fallback descriptions.

Transparent cards retain a fine white outline in preview and export so the shape
is visible without restoring a fill. Circle/caption, ticket notches, Polaroid and
Full Story use their own contours; Poster sticker retains its existing border.

The approved Focused editor now uses Style / Colour / Pip / Note tabs and a
smaller preview. Ticket subtypes remain under Style > Ticket. Export buttons stay
outside the scrolling body at the bottom; photo-save feedback is inline. Note
editing uses the existing local quote draft. Review cards retain their invite
entry point; rating invites remain in the Note panel. Export brings an offscreen
preview back into view before raster capture.
