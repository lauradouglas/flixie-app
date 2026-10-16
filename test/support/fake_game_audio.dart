import 'package:flixie_app/features/pip_games/audio/game_audio.dart';

/// Native audio is outside widget tests; production decisions still execute.
class FakeGameAudioBackend implements GameAudioBackend {
  final calls = <String>[];
  @override
  Future<void> music(String asset, double volume) async =>
      calls.add('music:$asset:$volume');
  @override
  Future<void> pauseMusic() async => calls.add('pause');
  @override
  Future<void> effect(String asset, double volume) async =>
      calls.add('effect:$asset');
  @override
  Future<void> stopEffects() async => calls.add('stopEffects');
  @override
  Future<void> dispose() async => calls.add('dispose');
}
