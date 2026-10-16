import 'dart:math';

enum SpaceEvent { laser, enemy, shield, heart, wave, over }

enum SpacePhase { ready, playing, paused, waveComplete, finished }

class SpaceInvader {
  SpaceInvader(this.column, this.row, this.x, this.y);
  final int column, row;
  double x, y;
}

class SpaceShot {
  SpaceShot(this.x, this.y);
  final double x;
  double y;
}

class SpaceShield {
  SpaceShield(this.x);
  final double x;
  int health = 4;
}

/// Deterministic 60Hz rules in a 360 × 520 arena, independent of rendering.
class SpaceEngine {
  SpaceEngine({int seed = 1}) : _random = Random(seed) {
    _formation();
  }
  static const tick = 1 / 60;
  final Random _random;
  final events = <SpaceEvent>[];
  final invaders = <SpaceInvader>[];
  final shots = <SpaceShot>[];
  final enemyShots = <SpaceShot>[];
  final shields = <SpaceShield>[];
  SpacePhase phase = SpacePhase.ready;
  double x = 180, targetX = 180, invulnerable = 0;
  int score = 0, lives = 3, wave = 1, ticks = 0;
  bool practice = false;
  double _march = 0, _fire = 0, _enemyFire = 0;
  int _direction = 1;
  double get marchInterval =>
      max(.075, .58 - wave * .035 - (21 - invaders.length) * .018);

  void start({bool practice = false}) {
    events.clear();
    this.practice = practice;
    score = 0;
    lives = 3;
    wave = 1;
    ticks = 0;
    x = targetX = 180;
    _formation();
    phase = SpacePhase.playing;
  }

  void _formation() {
    invaders.clear();
    shots.clear();
    enemyShots.clear();
    shields.clear();
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 7; col++) {
        invaders.add(SpaceInvader(col, row, 48.0 + col * 40, 52.0 + row * 36));
      }
    }
    for (final x in [72.0, 180.0, 288.0]) {
      shields.add(SpaceShield(x));
    }
    _march = 0;
    _fire = 0;
    _enemyFire = .8;
    _direction = 1;
    invulnerable = 0;
  }

  void moveTo(double position) {
    if (position.isFinite) targetX = position.clamp(24, 336).toDouble();
  }

  void pause() {
    if (phase == SpacePhase.playing) phase = SpacePhase.paused;
  }

  void resume() {
    if (phase == SpacePhase.paused) phase = SpacePhase.playing;
  }

  void nextWave() {
    if (phase != SpacePhase.waveComplete) return;
    wave++;
    _formation();
    phase = SpacePhase.playing;
  }

  void step() {
    events.clear();
    if (phase != SpacePhase.playing) return;
    ticks++;
    x += (targetX - x).clamp(-280 * tick, 280 * tick);
    invulnerable = max(0, invulnerable - tick);
    _fire -= tick;
    if (_fire <= 0) {
      if (shots.length < 5) {
        shots.add(SpaceShot(x, 455));
        events.add(SpaceEvent.laser);
      }
      _fire = .28;
    }
    _march += tick;
    if (_march >= marchInterval && invaders.isNotEmpty) {
      _march = 0;
      final edge = invaders
          .any((e) => e.x + _direction * 9 < 18 || e.x + _direction * 9 > 342);
      if (edge) _direction *= -1;
      for (final enemy in invaders) {
        if (edge) {
          enemy.y += 18;
        } else {
          enemy.x += _direction * 9;
        }
      }
      if (invaders.any((e) => e.y >= 435)) {
        if (practice) {
          _formation();
        } else {
          phase = SpacePhase.finished;
        }
        return;
      }
    }
    _enemyFire -= tick;
    if (_enemyFire <= 0 && invaders.isNotEmpty) {
      final bottom = <int, SpaceInvader>{};
      for (final e in invaders) {
        if (bottom[e.column] == null || bottom[e.column]!.y < e.y) {
          bottom[e.column] = e;
        }
      }
      final candidates = bottom.values.toList();
      final source = candidates[_random.nextInt(candidates.length)];
      if (enemyShots.length < 7) {
        enemyShots.add(SpaceShot(source.x, source.y + 12));
      }
      _enemyFire = max(.28, .95 - wave * .055);
    }
    for (final shot in List.of(shots)) {
      shot.y -= 380 * tick;
      SpaceInvader? hit;
      for (final enemy in invaders) {
        if ((shot.x - enemy.x).abs() < 14 && (shot.y - enemy.y).abs() < 12) {
          hit = enemy;
          break;
        }
      }
      if (hit != null) {
        score += (3 - hit.row) * 10;
        events.add(SpaceEvent.enemy);
        invaders.remove(hit);
        shots.remove(shot);
      } else if (shot.y < -10) {
        shots.remove(shot);
      }
    }
    for (final shot in List.of(enemyShots)) {
      shot.y += (110 + min(wave, 12) * 9) * tick;
      SpaceShield? shield;
      for (final s in shields) {
        if (s.health > 0 &&
            (shot.x - s.x).abs() < 25 &&
            (shot.y - 405).abs() < 11) {
          shield = s;
          break;
        }
      }
      if (shield != null) {
        shield.health--;
        events.add(SpaceEvent.shield);
        enemyShots.remove(shot);
      } else if ((shot.x - x).abs() < 21 && (shot.y - 480).abs() < 16) {
        enemyShots.remove(shot);
        if (invulnerable <= 0) {
          if (!practice) lives--;
          events.add(SpaceEvent.heart);
          invulnerable = 1.4;
          if (lives <= 0) phase = SpacePhase.finished;
        }
      } else if (shot.y > 530) {
        enemyShots.remove(shot);
      }
    }
    if (phase == SpacePhase.playing && invaders.isEmpty) {
      score += wave * 100;
      shots.clear();
      enemyShots.clear();
      phase = SpacePhase.waveComplete;
      events.add(SpaceEvent.wave);
    }
  }
}
