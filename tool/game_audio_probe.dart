// Native audio smoke check for the offline simulator preview only.
// Invoke ext.flixie.gameAudio on its authenticated local VM service.
import 'dart:convert';
import 'dart:developer';
import 'package:flixie_app/features/pip_games/audio/game_audio.dart';

void registerGameAudioProbe() {
  registerExtension('ext.flixie.gameAudio', (_, __) async {
    final backend = NativeGameAudioBackend();
    final checked = <String>[];
    try {
      for (final track in ['pairs-music', 'popcorn-music', 'space-music']) {
        await backend.music(track, .14);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await backend.pauseMusic();
        checked.add(track);
      }
      for (final effect in [
        'arcade-select',
        'arcade-pause',
        'pairs-flip',
        'pairs-match',
        'pairs-mismatch',
        'pairs-complete',
        'popcorn-catch',
        'popcorn-gold',
        'popcorn-burnt',
        'popcorn-streak',
        'popcorn-round',
        'space-laser',
        'space-enemy',
        'space-shield',
        'space-heart',
        'space-wave',
        'space-over',
      ]) {
        await backend.effect(effect, .3);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        checked.add(effect);
      }
      await backend.stopEffects();
      return ServiceExtensionResponse.result(
          jsonEncode({'checked': checked, 'status': 'passed'}));
    } catch (error) {
      return ServiceExtensionResponse.result(jsonEncode(
          {'checked': checked, 'status': 'failed', 'error': '$error'}));
    } finally {
      await backend.dispose();
    }
  });
}
