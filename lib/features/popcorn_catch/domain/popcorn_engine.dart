import 'dart:math';

enum PopcornEvent { catchTreat, gold, burnt, streak }

class PopcornKernel {
  const PopcornKernel(this.x, this.born, this.fall, this.kind);
  final int x, born, fall, kind;
  bool get burnt => kind < 2;
  bool get golden => kind == 9;
  bool get gummyBear => kind == 2 || kind == 3;
  bool get chocolate => kind == 4 || kind == 5;
  int get basePoints => golden ? 30 : 10;
}

/// Versioned protocol: integer simulation replayed by the server, independent of fps.
class PopcornEngine {
  PopcornEngine(int seed, {this.version = 2}) : _random = seed;
  final int version;
  final events = <PopcornEvent>[];
  static const roundTicks = 600;
  static const maxRunTicks = roundTicks * 60;
  int roundNumber = 1;
  int _lastDamageTick = -100;
  int get roundTick => tick % roundTicks;
  bool get roundComplete =>
      version >= 3 && tick > 0 && tick == roundNumber * roundTicks;
  bool get runOver => lives == 0 || (version >= 3 && tick >= maxRunTicks);
  int get spawnInterval =>
      version >= 3 ? max(3, 10 - (roundNumber - 1) ~/ 2) : 8;
  int get fallTicks =>
      version >= 3 ? max(18, 60 - (roundNumber - 1) * 4) : 52 - (level - 1) * 6;
  void nextRound() {
    if (!roundComplete || runOver) return;
    roundNumber++;
    lives = 3;
    combo = 0;
    basket.clear();
    kernels.clear();
    movement = 0;
    _lastDamageTick = -100;
  }

  int _random;
  int tick = 0, x = 500, previousX = 500;
  int lives = 3;
  double movement = 0;
  int get level => version >= 3 ? roundNumber : 1 + (tick ~/ 120).clamp(0, 4);
  bool get complete => version >= 3
      ? runOver || roundComplete
      : lives == 0 || tick >= roundTicks;
  double get anxiety => ((level - 1) * .13 + movement * .6).clamp(0.0, 1.0);
  int get expression => anxiety >= .72
      ? 2
      : anxiety >= .34
          ? 1
          : 0;
  int score = 0, combo = 0, bestCombo = 0, caught = 0, burnt = 0;
  int feedbackTick = -100;
  String feedback = '';
  final List<PopcornKernel> kernels = [];
  final List<int> targets = [];
  final List<int> basket = [];
  int get multiplier => min(4, 1 + combo ~/ 5);
  int _next() => _random = (_random * 1664525 + 1013904223) & 0xffffffff;

  void step(int target, {bool practice = false}) {
    events.clear();
    if (!practice && (version >= 3 ? runOver || roundComplete : complete)) {
      return;
    }
    target = target.clamp(0, 1000);
    if (!practice) targets.add(target);
    previousX = x;
    x += (target - x).clamp(-50, 50);
    movement = movement * .85 + (x - previousX).abs() / 50 * .15;
    final phase = version >= 3 || practice ? tick % roundTicks : tick;
    if (phase % spawnInterval == 0 &&
        (practice || phase < (version >= 3 ? roundTicks - fallTicks : 552))) {
      final px = 100 + (_next() >> 8) % 801;
      final kind = (_next() >> 8) % 10;
      kernels.add(PopcornKernel(
          px, tick, version == 1 ? 52 - phase ~/ 100 * 4 : fallTicks, kind));
    }
    for (var i = kernels.length - 1; i >= 0; i--) {
      final k = kernels[i];
      if (tick - k.born < k.fall) continue;
      kernels.removeAt(i);
      if ((k.x - x).abs() > 130) {
        if (!k.burnt) combo = 0;
        continue;
      }
      feedbackTick = tick;
      if (k.burnt) {
        if (version >= 3 && tick - _lastDamageTick < 20) continue;
        _lastDamageTick = tick;
        events.add(PopcornEvent.burnt);
        burnt++;
        combo = 0;
        score = max(0, score - 20);
        if (version >= 2 && !practice) lives = max(0, lives - 1);
        feedback = version >= 2 && !practice ? 'Ouch! −1 life' : 'Ouch! −20';
        if (lives == 0) break;
      } else {
        caught++;
        if (basket.length < 18) basket.add(k.kind);
        combo++;
        events.add(k.golden
            ? PopcornEvent.gold
            : combo % 5 == 0
                ? PopcornEvent.streak
                : PopcornEvent.catchTreat);
        bestCombo = max(bestCombo, combo);
        final points = k.basePoints * multiplier;
        score += points;
        feedback = k.golden ? 'Golden! +$points' : '+$points';
      }
    }
    tick++;
  }
}
