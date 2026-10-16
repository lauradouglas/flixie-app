# Pip Pairs

Pip Pairs is a local memory game reached from Home's **Play with Pip** games
area (`/play`), then **Pip Pairs** (`/play/pip-pairs`). The games area also offers
Popcorn Catch, and lives in `lib/features/pip_games/`. It extends
Flixie's established cinema arcade direction; it does not establish a new design
system or change the product identity.

## Arcade chooser and exit

The chooser follows the user-approved `design/pip-arcade/chooser-approved.png`.
Two illustrated cabinets use purple and coral frames, marquee lights, cream
titles and gold **PLAY** signs. All text and actions are native Flutter widgets
over decorative scene artwork in `assets/images/pip_arcade/`; each cabinet
exposes one semantic button with its game name and description. The scrollable,
width-bounded layout stacks controls on narrow screens or with larger text.

The arcade heading and game titles use the bundled `PressStart2P-Regular.ttf`,
with its OFL license at `assets/fonts/PressStart2P-OFL.txt`. Game titles are now
18px and the responsive heading is larger, following review of title hierarchy.
The official Flixie wordmark remains in the app bar.

Both scene plates were generated with the built-in image generator using the
approved chooser and existing Pip illustrations as references. Exact prompts,
reference paths and generated-source provenance are retained in
`design/pip-arcade/artwork-prompts.json`. These newly generated decorative scenes
are separate from the original outfit illustrations used by the memory game.

Pairs has an explicit close control labelled **Back to games**. It pops the
current route when possible and otherwise routes to `/play`, fixing the missing
exit when Pairs is opened as a root route. The offline preview at
`tool/preview_pip_pairs.dart` now uses GoRouter and starts at the chooser, with
Home and both game routes available. Its seeded Pairs board is a local preview
fixture; the regular game starts with all cards hidden.

## Play behaviour

- Easy (the default) keeps mismatched cards visible until **Turn cards back** is
  pressed. This action stays below the scrolling board in the safe area.
- Medium hides a mismatch 1.5 seconds after the second card is revealed; Hard
  hides it after 0.5 seconds. The first card has no reveal deadline.
- Matching cards stay face up. A pending mismatch blocks additional flips.
- Board size is independently selectable: 6, 8 or 12 pairs. Each board samples
  distinct outfits, duplicates each once, and shuffles the cards.
- Each second reveal counts as one move. There is no overall game timer.
- Restarting or changing settings after a move in an unfinished game uses
  `showFlixiePromptSheet` to confirm clearing progress. Completion shows the
  final move count and **Play another board**. Fresh boards clear matches,
  moves and pending hide timers while retaining the chosen settings.

The controller owns in-memory game state. There is no API, leaderboard, saved
progress or database dependency, so no database fixture is required to try it.

## Visual treatment and artwork

The game uses a dark purple cinema arcade surface, lavender controls and gold
match accents. Revealed cards have cream fronts; concealed cards carry the
official Flixie F. The app bar uses `FlixieWordmark` with white **flix** and
purple **ie**. Keep these official assets rather than substituting generic film
symbols.

`lib/features/pip_pairs/models/pip_outfit.dart` is the explicit 24-outfit pool.
Nineteen illustrations reuse `assets/icon/community_pips/`. Five existing original
illustrations were resized from `design/merch/pip/future-variants/` into runtime
assets under `assets/icon/pip_pairs/`:

| Source and runtime filename | Card name |
| --- | --- |
| `pip-sleepy.png` | Sleepy Pip |
| `pip-basketball-player.png` | Basketball Pip |
| `pip-dune.png` | Desert Pip |
| `pip-pokemon-trainer.png` | Trainer Pip |
| `pip-settings-lanyard.png` | Lanyard Pip |

These five are resized derivatives of the existing design artwork, not newly
generated illustrations. The pool excludes superseded artwork; keep archived
alternatives out of runtime selection. In particular, the selected Vampire Pip
uses `pip-horror-slasher-v2.png`, and Lanyard Pip uses the current unversioned
asset rather than `pip-settings-lanyard-v1.png`.

## Responsive and accessible behaviour

The content scrolls vertically, with three columns below 360 logical pixels and
four otherwise for 6/8-pair boards. The 12-pair board uses smaller cards and gaps,
four columns below 360px, six on standard phones/tablets and eight on wide short
landscape screens. Card height responds to viewport height with a 48px minimum
touch target; large text and very short viewports keep scrolling. Content width is bounded on larger screens. Settings and score
rows wrap, and card height is bounded. The Easy mismatch action remains outside
the scroll area so it can be reached without returning to the board's end.

Card flips normally animate over 160 milliseconds and become immediate when
system animations are disabled. Card semantics announce position, face-down or
revealed identity, and matched state. Hidden cards do not announce their outfit.
The explicit semantics tap action invokes the same reveal callback as a visual
tap; a regression covers this action after review found it missing. Status text
uses a live region. Decorative mascot images are excluded from semantics.

## Ownership and verification

Implementation lives in `lib/features/pip_pairs/`: the outfit model, observable
controller, screen and card widget. The shared Home entry and chooser belong to `lib/features/pip_games/`; the
former Popcorn Home entry remains a compatibility wrapper.
Focused tests mirror the feature under `test/features/pip_pairs/`.

Run focused checks from the app root:

```sh
flutter test test/features/pip_pairs
flutter analyze lib/features/pip_pairs lib/features/pip_games lib/features/popcorn_catch/presentation/widgets/popcorn_home_entry.dart test/features/pip_pairs tool/preview_pip_pairs.dart
```

Coverage includes board composition, move counting, mismatch blocking and timing,
reset cancellation, completion and replay, Home navigation, bundled artwork,
semantic activation, and small-phone, landscape and tablet layouts with doubled
text scaling. The timing checks exercise the second-card deadline.

The latest combined focused run passed 19 checks. The four routing/large-text/exit
checks also passed after the title hierarchy adjustment. Final focused analysis
is clean. Existing coverage includes chooser navigation, narrow
large-text layout and Pairs exit from both pushed and root routes.

Earlier native captures (`output/pip-pairs/phone.png`, `tablet.png` and
`tablet-outfits.png`) show the earlier Pairs state, before subsequent layout and
arcade changes. `output/pip-pairs/arcade-tablet.png` captures the native chooser
before the latest typography adjustment. Final native captures `output/pip-pairs/arcade-phone-final.png` and
`output/pip-pairs/arcade-tablet-final.png` were inspected and independently
reviewed against the approved concept: the title hierarchy finding is resolved,
and both game choices and Play actions are visible without material clipping.
This is a visual pass for those normal-text iOS states, not a native journey pass.

Patrol's native test build succeeded, but execution stalled during simulator
startup and was interrupted after 5m42s with zero tests executed. Do not count it
as a device pass. Result bundle: `build/ios_results_1792059657595.xcresult`.
No successful native Patrol rerun is claimed. Android, native large text,
phone mismatch/completion, actual screen-reader use and navigation gestures have
not been visually/device verified. Earlier development deep-link captures showed
the route-error page and are not evidence for the game; the retained debug image
is `output/pip-pairs/debug-route-error.png`.

The font licence/copyright is retained in source and bundled as
`assets/fonts/PressStart2P-OFL.txt`. Runtime scene PNGs embed their exact generation
prompts; provenance scan reports two rasters and zero missing prompts.
