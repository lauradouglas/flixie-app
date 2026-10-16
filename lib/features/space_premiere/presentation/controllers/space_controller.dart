import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../domain/space_engine.dart';

class SpaceController extends ChangeNotifier {
  SpaceController({SpaceEngine? engine}) : engine = engine ?? SpaceEngine();
  final SpaceEngine engine;
  void Function(String)? onSound;
  final frame = ValueNotifier<int>(0);
  double _pending = 0;

  void start({bool practice = false}) {
    engine.start(practice: practice);
    _pending = 0;
    notifyListeners();
    frame.value++;
    onSound?.call('arcade-select');
  }

  void moveTo(double x) => engine.moveTo(x);
  void pause() {
    final wasPlaying = engine.phase == SpacePhase.playing;
    engine.pause();
    _pending = 0;
    notifyListeners();
    if (wasPlaying) onSound?.call('arcade-pause');
  }

  void resume() {
    final wasPaused = engine.phase == SpacePhase.paused;
    engine.resume();
    _pending = 0;
    notifyListeners();
    if (wasPaused) onSound?.call('arcade-select');
  }

  void nextWave() {
    engine.nextWave();
    _pending = 0;
    notifyListeners();
    frame.value++;
    onSound?.call('arcade-select');
  }

  void advance(Duration elapsed) {
    if (engine.phase != SpacePhase.playing) {
      _pending = 0;
      return;
    }
    final phase = engine.phase, score = engine.score, lives = engine.lives;
    final sounds = <SpaceEvent>{};
    _pending += min(elapsed.inMicroseconds / 1000000, .2);
    while (_pending >= SpaceEngine.tick && engine.phase == SpacePhase.playing) {
      engine.step();
      sounds.addAll(engine.events);
      _pending -= SpaceEngine.tick;
    }
    frame.value++;
    if (phase != engine.phase ||
        score != engine.score ||
        lives != engine.lives) {
      notifyListeners();
    }
    for (final event in sounds) {
      onSound?.call('space-${event.name}');
    }
    if (phase != engine.phase && engine.phase == SpacePhase.finished) {
      onSound?.call('space-over');
    }
  }

  @override
  void dispose() {
    frame.dispose();
    super.dispose();
  }
}
