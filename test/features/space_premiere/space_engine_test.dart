import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/space_premiere/domain/space_engine.dart';
import 'package:flixie_app/features/space_premiere/presentation/controllers/space_controller.dart';

void main() {
  test('movement is bounded and firing automatically destroys a target', () {
    final e = SpaceEngine()..start();
    e.moveTo(10000);
    for (var i = 0; i < 60; i++) {
      e.step();
    }
    expect(e.x, lessThanOrEqualTo(336));
    expect(e.shots, isNotEmpty);
    final enemy = e.invaders.first;
    final before = e.invaders.length;
    e.shots.add(SpaceShot(enemy.x, enemy.y + 380 * SpaceEngine.tick));
    e.step();
    expect(e.invaders.length, before - 1);
    expect(e.score, greaterThan(0));
  });
  test('shields absorb enemy shots; hits lose lives with recovery protection',
      () {
    final e = SpaceEngine()..start();
    e.enemyShots.add(SpaceShot(72, 403));
    e.step();
    expect(e.shields.first.health, 3);
    expect(e.lives, 3);
    e.enemyShots.add(SpaceShot(e.x, 478));
    e.step();
    expect(e.lives, 2);
    e.enemyShots.add(SpaceShot(e.x, 478));
    e.step();
    expect(e.lives, 2);
    e.invulnerable = 0;
    e.enemyShots.add(SpaceShot(e.x, 478));
    e.step();
    e.invulnerable = 0;
    e.enemyShots.add(SpaceShot(e.x, 478));
    e.step();
    expect(e.phase, SpacePhase.finished);
    expect(e.lives, 0);
  });
  test(
      'clear wave earns bonus; next wave retains score/lives and restores shields',
      () {
    final e = SpaceEngine()..start();
    e.lives = 2;
    e.shields.first.health = 0;
    e.invaders.clear();
    e.step();
    expect(e.phase, SpacePhase.waveComplete);
    expect(e.score, 100);
    e.nextWave();
    expect(e.wave, 2);
    expect(e.score, 100);
    expect(e.lives, 2);
    expect(e.invaders.length, 21);
    expect(e.shields.first.health, 4);
    expect(e.phase, SpacePhase.playing);
  });
  test('invasion ends normal play; practice resets formation and keeps lives',
      () {
    for (final practice in [false, true]) {
      final e = SpaceEngine()..start(practice: practice);
      for (final enemy in e.invaders) {
        enemy.y = 440;
      }
      for (var i = 0; i < 40; i++) {
        e.step();
      }
      expect(e.phase, practice ? SpacePhase.playing : SpacePhase.finished);
      expect(e.lives, 3);
    }
    final e = SpaceEngine()..start(practice: true);
    e.enemyShots.add(SpaceShot(e.x, 478));
    e.step();
    expect(e.lives, 3);
  });
  test(
      'pause freezes simulation and restart removes old projectiles and progress',
      () {
    final c = SpaceController();
    addTearDown(c.dispose);
    c.start();
    c.advance(const Duration(milliseconds: 200));
    c.pause();
    final ticks = c.engine.ticks;
    c.advance(const Duration(seconds: 30));
    expect(c.engine.ticks, ticks);
    c.resume();
    c.advance(const Duration(milliseconds: 20));
    expect(c.engine.ticks, greaterThan(ticks));
    c.start();
    expect(c.engine.score, 0);
    expect(c.engine.lives, 3);
    expect(c.engine.enemyShots, isEmpty);
    expect(c.engine.shots, isEmpty);
  });
  test('frame partitioning gives the same deterministic simulation', () {
    final a = SpaceController(), b = SpaceController();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    a.start();
    b.start();
    for (var i = 0; i < 100; i++) {
      a.advance(const Duration(milliseconds: 20));
    }
    for (var i = 0; i < 200; i++) {
      b.advance(const Duration(milliseconds: 10));
    }
    expect(a.engine.ticks, b.engine.ticks);
    expect(a.engine.score, b.engine.score);
    expect(a.engine.invaders.first.x, b.engine.invaders.first.x);
  });
}
