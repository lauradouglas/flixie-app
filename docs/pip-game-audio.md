# Pip game audio

User approved adding the audition pack's background music and game effects on
15 October 2026, excluding all Pip character voices. Three original music loops
and 17 effects are bundled locally in `assets/audio/pip_games/` (about 2.8 MB).
No network, microphone, sampled voice, production fixture or backend is needed.
Provenance and exact filenames are recorded beside the WAV files.

- Pip Pairs: card flip, mismatch, match and board completion.
- Popcorn Catch: catches, golden treats, burnt treats, streaks and round completion.
- Space Premiere: lasers, invader pops, shield hits, heart loss, wave clear and game over.
- Shared: selection/start and pause effects.

Every game and the arcade chooser has a **Game audio** speaker button. Its root,
safe-area bottom sheet has separate Music and Sound effects switches and a music
volume slider. Preferences persist across sessions and games on the device.
Music defaults to 14% player volume (slider caps at 35%); effects use 60%, with
repeated lasers at 30%. Hardware media volume still applies. iOS uses the ambient
audio category, respecting silent mode and allowing other audio to mix.

Music runs during active play, pauses between rounds/on game pause, and stops
when leaving the route or backgrounding. Pairs plays during an unfinished board.
Opening audio settings pauses the action games; resume manually afterward.
Effects queued before muting, backgrounding or leaving are invalidated. A bounded
four-player pool handles effects; one player loops music. Native operations are
serialized, playback errors do not interrupt the game, and exit disposes players.
The pure game engines expose typed tick events; authoritative scoring and
versioned replay rules remain unchanged.

Regression checks live in `test/features/pip_games/game_audio_test.dart` alongside
the existing game suites. Native audio is replaced with a recording fake in
widget tests, not suppressed in production. The offline simulator preview also
registers `ext.flixie.gameAudio` to exercise all bundled sounds through the real
native player; `tool/game_audio_probe.dart` is never imported by production main.

Audio first shipped to internal testers in TestFlight **2.0.4 (115)** on
15 October 2026 at 14:29 London. Build 114 predates this integration.
Apple independently confirms build 115 VALID and IN_BETA_TESTING.

Verified locally: 76 focused game/audio tests pass; focused static analysis is clean.
The iPhone simulator native probe successfully opens/plays all 20 bundled assets,
then stops and disposes the players. Evidence: `output/pip-audio-approval/native-phone-audio-check.json`.
This confirms native playback calls and asset decoding, not a subjective listening
assessment or physical-device interruption/mixing test.
