import 'package:flixie_app/features/pip_games/audio/game_audio.dart';
import '../../support/fake_game_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/popcorn_catch/domain/popcorn_engine.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/controllers/popcorn_controller.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/pages/popcorn_catch_screen.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/widgets/popcorn_arena.dart';
import '../../../tool/preview_popcorn_catch.dart';

void main() {
  setUp(() {
    GameAudioSession.backendFactory = FakeGameAudioBackend.new;
  });
  tearDown(() {
    GameAudioSession.backendFactory = NativeGameAudioBackend.new;
  });
  test('round 1 stays at level 1 for all 30 seconds until next round is chosen',
      () {
    final e = PopcornEngine(1, version: 3);
    final initialFallTicks = e.fallTicks;
    for (var tick = 0; tick < PopcornEngine.roundTicks; tick++) {
      e.step(0);
      expect(e.level, 1, reason: 'Round must not advance at tick $tick');
      expect(e.fallTicks, initialFallTicks);
    }
    expect(e.tick, 600);
    expect(e.roundComplete, isTrue);
    e.step(0);
    expect(e.tick, 600);
    expect(e.level, 1);
    e.nextRound();
    expect(e.level, 2);
    expect(e.fallTicks, lessThan(initialFallTicks));
  });

  test('v3 multi-round replay matches the authoritative server vectors', () {
    for (final vector in [(1, 60, 6, 0), (12345, 70, 5, 1), (42, 40, 2, 0)]) {
      final e = PopcornEngine(vector.$1, version: 3);
      for (var i = 0; i < 1200; i++) {
        if (e.roundComplete && !e.runOver) e.nextRound();
        e.step(0);
      }
      expect([e.score, e.caught, e.burnt, e.lives, e.roundNumber, e.tick],
          [vector.$2, vector.$3, vector.$4, 3, 2, 1200]);
    }
  });
  test(
      'each round holds its speed and refills lives without losing total score',
      () {
    final e = PopcornEngine(1, version: 3)
      ..tick = 599
      ..lives = 1
      ..score = 400;
    final speed = e.fallTicks;
    e.step(0);
    expect(e.roundComplete, isTrue);
    expect(e.runOver, isFalse);
    expect(e.level, 1);
    e.nextRound();
    expect(e.lives, 3);
    expect(e.score, 400);
    expect(e.roundNumber, 2);
    expect(e.fallTicks, lessThan(speed));
    e.step(0);
    expect(e.tick, 601);
    expect(e.level, 2);
  });
  test('burnt recovery prevents clustered damage for one second', () {
    final e = PopcornEngine(1, version: 3)..tick = 1;
    void hit() {
      e.kernels.add(PopcornKernel(e.x, e.tick - 1, 1, 0));
      e.step(e.x);
    }

    hit();
    hit();
    expect(e.lives, 2);
    expect(e.burnt, 1);
    for (var i = 0; i < 19; i++) {
      e.kernels.clear();
      e.step(e.x);
    }
    hit();
    expect(e.lives, 1);
  });
  test(
      'controller pauses between rounds and finishes only by choice or lost lives',
      () async {
    final c = PopcornController(
        userId: 'fictional-casey', service: PreviewPopcornService(version: 3));
    await c.startRanked();
    for (var i = 0; i < 60; i++) {
      c.advance(const Duration(milliseconds: 50));
    }
    c.engine.tick = 599;
    c.engine.kernels.clear();
    c.advance(const Duration(milliseconds: 50));
    expect(c.phase, PopcornPhase.roundComplete);
    c.advance(const Duration(milliseconds: 50));
    expect(c.engine.tick, 600);
    c.nextRound();
    expect(c.engine.lives, 3);
    expect(c.engine.roundNumber, 2);
    expect(c.phase, PopcornPhase.countdown);
    for (var i = 0; i < 60; i++) {
      c.advance(const Duration(milliseconds: 50));
    }
    c.engine.tick = 1199;
    c.engine.kernels.clear();
    c.advance(const Duration(milliseconds: 50));
    c.finishRun();
    expect(c.phase, PopcornPhase.finished);
    await Future<void>.delayed(Duration.zero);
    c.dispose();
  });
  testWidgets('dragging directly on Pip moves him and round buttons advance',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PopcornCatchScreen(
            userId: 'fictional-casey',
            service: PreviewPopcornService(version: 3))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start round 1'));
    await tester.tap(find.text('Start round 1'));
    await tester.pump();
    for (var i = 0; i < 65; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final c = tester.widget<PopcornArena>(find.byType(PopcornArena)).controller;
    final zone = tester.getRect(find.byKey(const Key('popcorn-drag-zone')));
    final onPip = Offset(zone.center.dx, zone.top + 75);
    final before = c.target;
    await tester.dragFrom(onPip, const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.target, greaterThan(before));
    c.engine.tick = 599;
    c.engine.kernels.clear();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('Round 1 complete!'), findsOneWidget);
    await tester.ensureVisible(find.text('Start round 2'));
    await tester.tap(find.text('Start round 2'));
    await tester.pump();
    expect(c.phase, PopcornPhase.countdown);
    expect(c.engine.lives, 3);
    expect(c.engine.roundNumber, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
