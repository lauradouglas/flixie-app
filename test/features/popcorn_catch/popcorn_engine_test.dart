import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/popcorn_catch/domain/popcorn_engine.dart';

void main() {
  test('protocol vectors agree with authoritative server replay', () {
    for (final vector in [
      (1, 230, 21, 5, 3),
      (12345, 130, 17, 3, 3),
      (2147483646, 200, 20, 3, 3)
    ]) {
      final e = PopcornEngine(vector.$1, version: 1);
      for (var i = 0; i < 600; i++) {
        e.step(500);
      }
      expect([e.score, e.caught, e.burnt, e.bestCombo],
          [vector.$2, vector.$3, vector.$4, vector.$5]);
      expect(e.kernels, isEmpty);
      expect(e.targets, hasLength(600));
      e.step(500);
      expect(e.targets, hasLength(600));
    }
  });
  test('combos, golden bonus, burnt penalty and misses follow game rules', () {
    final e = PopcornEngine(1);
    for (var i = 0; i < 5; i++) {
      e.kernels.add(PopcornKernel(500, e.tick - 52, 52, 3));
      e.step(500);
    }
    expect(e.score, 60);
    expect(e.multiplier, 2);
    e.kernels.add(PopcornKernel(500, e.tick - 52, 52, 9));
    e.step(500);
    expect(e.score, 120);
    e.kernels.add(PopcornKernel(500, e.tick - 52, 52, 0));
    e.step(500);
    expect(e.score, 100);
    expect(e.combo, 0);
    expect(e.burnt, 1);
    e.kernels.add(PopcornKernel(500, e.tick - 52, 52, 3));
    e.step(500);
    e.kernels.add(PopcornKernel(900, e.tick - 52, 52, 3));
    e.step(500);
    expect(e.combo, 0);
  });
  test('gummies and chocolate build the same combo; gold stays highest', () {
    final e = PopcornEngine(1)..tick = 1;
    for (final kind in [2, 3, 4, 5, 6]) {
      final treat = PopcornKernel(500, e.tick - 52, 52, kind);
      expect(treat.basePoints, 10);
      expect(treat.gummyBear, kind == 2 || kind == 3);
      expect(treat.chocolate, kind == 4 || kind == 5);
      e.kernels.add(treat);
      e.step(500);
    }
    expect(e.combo, 5);
    expect(e.score, 60);
    e.kernels.add(PopcornKernel(500, e.tick - 52, 52, 9));
    e.step(500);
    expect(e.score, 120);
    expect(e.combo, 6);
  });
  test('three burns end ranked play early; misses only reset combo', () {
    final e = PopcornEngine(7)..tick = 1;
    for (var i = 0; i < 3; i++) {
      e.kernels.add(PopcornKernel(500, e.tick - 1, 1, 0));
      e.step(500);
      expect(e.lives, 2 - i);
    }
    expect(e.complete, isTrue);
    final tick = e.tick;
    e.step(1000);
    expect(e.tick, tick);
    final practice = PopcornEngine(7)..tick = 1;
    for (var i = 0; i < 5; i++) {
      practice.kernels.add(PopcornKernel(500, practice.tick - 1, 1, 0));
      practice.step(500, practice: true);
    }
    expect(practice.lives, 3);
    final miss = PopcornEngine(7)
      ..tick = 1
      ..combo = 3;
    miss.kernels.add(const PopcornKernel(900, 0, 1, 3));
    miss.step(500);
    expect(miss.lives, 3);
    expect(miss.combo, 0);
  });
  test('v2 vectors agree with server early endings', () {
    for (final v in [
      (1, 10, 5, 165),
      (12345, 110, 15, 427),
      (2147483646, 140, 16, 499)
    ]) {
      final e = PopcornEngine(v.$1);
      for (var i = 0; i < 600; i++) {
        e.step(500);
      }
      expect([e.score, e.caught, e.tick, e.lives], [v.$2, v.$3, v.$4, 0]);
      expect(e.targets, hasLength(v.$4));
    }
  });
  test(
      'levels speed falling treats and fast movement raises anxiety then settles',
      () {
    final e = PopcornEngine(1)..tick = 120;
    e.step(1000, practice: true);
    expect(e.level, 2);
    expect(e.kernels.last.fall, 46);
    for (var i = 0; i < 40; i++) {
      e.step(i % 2 == 0 ? 0 : 1000, practice: true);
    }
    final fast = e.anxiety;
    for (var i = 0; i < 35; i++) {
      e.step(e.x, practice: true);
    }
    expect(e.anxiety, lessThan(fast));
    e.tick = 480;
    e.step(500, practice: true);
    expect(e.level, 5);
    expect(e.kernels.last.fall, 28);
  });
  test('bucket stores caught treats up to the rim, ignores burns and resets',
      () {
    final e = PopcornEngine(1)..tick = 1;
    for (var i = 0; i < 22; i++) {
      e.kernels.add(PopcornKernel(500, e.tick - 1, 1, 2 + i % 8));
      e.step(500, practice: true);
    }
    expect(e.basket, hasLength(18));
    expect(e.basket.take(3), [2, 3, 4]);
    e.kernels.add(PopcornKernel(500, e.tick - 1, 1, 0));
    e.step(500, practice: true);
    expect(e.basket, hasLength(18));
    expect(PopcornEngine(1).basket, isEmpty);
  });
  test('movement speed is bounded and practice continues past 30 seconds', () {
    final e = PopcornEngine(1)..step(1000);
    expect(e.x, 550);
    e.step(-1);
    expect(e.x, 500);
    expect(e.targets.last, 0);
    for (var i = 0; i < 610; i++) {
      e.step(500, practice: true);
    }
    expect(e.tick, 612);
    expect(e.targets, hasLength(2));
  });
}
