# Pip’s Space Premiere

Space Premiere is the native space shooter requested with a Space Invaders vibe,
reached from the **Play with Pip** arcade at `/play/space-premiere`. It extends
Flixie's established purple cinema arcade identity with an original Pip ship,
pixel enemies, gold shots and cream text. The app bar retains `FlixieWordmark`.

## Play and controls

- Pip fires automatically. Drag horizontally, use keyboard arrow keys, or tap
  the labelled left/right buttons to steer. The arena also exposes semantic
  increase/decrease steering actions. Space pauses or resumes keyboard play.
- Each wave starts with 21 enemies in three rows of seven. The formation marches
  sideways, reverses and descends at the edges, and accelerates as enemies fall
  and waves advance. Bottommost enemies fire toward Pip.
- Three shields each absorb four enemy hits. Normal play starts with three
  lives; a hit grants 1.4 seconds of recovery. Losing all lives or allowing the
  formation to reach Pip ends the game.
- Clearing a wave awards a wave bonus. Starting the next wave supplies a fresh
  formation and shields. Replay starts a fresh score and wave one.
- Practice provides unlimited lives and resets the formation on invasion.
  Pause is available during play, and leaving the foreground pauses the game.
- **Back to games** pops a pushed route, or routes to `/play` when opened at the
  root, so direct entry still has an exit.

All state is local and in memory. There is no API, database, leaderboard, saved
best score or boss encounter. No database fixture is needed to try the game.

## Implementation and artwork

`lib/features/space_premiere/domain/space_engine.dart` owns deterministic 60Hz
rules in a 360 × 520 logical arena. The controller separates per-frame arena
notifications from score/lives/phase updates to the HUD. The feature owns its
screen, painter and controls; the arena scales proportionally to available space,
HUD labels wrap, and overlays scroll on constrained viewports.

The transparent player ship at `assets/images/space_premiere/pip-ship.png` and
chooser hero at `assets/images/pip_arcade/space-scene.png` were created with the
built-in image generator using the existing
`assets/icon/community_pips/pip-space-adventure.png` as the identity reference.
The exact prompts, transparency settings and generated-source provenance are
saved in `design/space-premiere/artwork-prompts.json`; prompt metadata is also
embedded in the artwork. The ship and chooser are illustrated assets, while the
three original enemy patterns, shields and playfield are drawn by the painter.
The chooser uses native text and actions over its decorative image.

## Verification and limits

Fourteen new shooter checks and four existing arcade checks passed (18 total),
including background pause and exit from a direct root route. Focused analysis
is clean. Relevant commands from the app root:

```sh
flutter test test/features/space_premiere test/features/pip_pairs/pip_pairs_entry_test.dart
flutter analyze lib/features/space_premiere lib/features/pip_games tool/preview_space_premiere.dart test/features/space_premiere
```

Independent finish review found no material issues in the source or the valid
native iPad fixture capture at `output/space-premiere/tablet-gameplay.png`. That
fixture depicts 1.2 seconds of deterministic game state and establishes layout
only; it does not verify live performance. Phone screenshot attempts showed an
OS open-link confirmation and are debug evidence, not valid gameplay captures.

`tool/preview_space_premiere.dart` runs live by default and can freeze the
deterministic fixture with `--dart-define=SPACE_CAPTURE=true`. The iPad preview
was hot restarted back to live play after capturing the fixture.
`patrol_test/space_premiere_test.dart` adds a native journey but has not been
executed. No Patrol pass is claimed. Live device performance, valid native phone
layout and actual assistive-technology use remain unverified.
