import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/api/api_client.dart';
import '../../data/popcorn_service.dart';
import '../../domain/popcorn_engine.dart';
import '../../models/popcorn_leaderboard.dart';

enum PopcornPhase {
  ready,
  starting,
  countdown,
  playing,
  paused,
  roundComplete,
  finished
}

class PopcornController extends ChangeNotifier {
  PopcornController(
      {required String? userId, PopcornService? service, this.challengeId})
      : _userId = userId,
        _service = service ?? PopcornService();
  final PopcornService _service;
  void Function(String)? onSound;
  final String? challengeId;
  bool verified = false, replySent = false, replying = false;
  bool get newBest =>
      _userId != null &&
      !practice &&
      phase == PopcornPhase.finished &&
      engine.score > 0 &&
      engine.score > (_round?.personalBest ?? 0);
  bool get roughRound =>
      !practice &&
      phase == PopcornPhase.finished &&
      !newBest &&
      engine.score < 50 &&
      engine.caught < 5;
  String? get roundId => _round?.id;
  bool get guestRound => _round?.guestToken != null;
  Future<String?> verifyForSharing({bool quietly = false}) async {
    if (practice ||
        _round?.guestToken != null ||
        phase != PopcornPhase.finished ||
        _round == null) {
      return null;
    }
    if (verified || posted) return _round!.id;
    final generation = _generation;
    try {
      final score = await _service.verify(_round!, List.of(engine.targets));
      if (!_current(generation)) return null;
      if (score != engine.score) throw StateError('Replay mismatch');
      verified = true;
      return _round!.id;
    } catch (_) {
      if (_current(generation)) {
        if (!quietly) error = 'Couldn’t verify your score. Try sharing again.';
        _publish();
      }
      return null;
    }
  }

  Future<void> replyToChallenge() async {
    if (challengeId == null ||
        replying ||
        replySent ||
        phase != PopcornPhase.finished) {
      return;
    }
    final generation = _generation;
    final owner = _userId;
    final replay = List<int>.of(engine.targets);
    replying = true;
    error = null;
    _publish();
    try {
      if (owner != null) {
        await _service.rememberReply(owner, challengeId!, replay);
      }
      if (!_current(generation)) return;
      final score = await _service.reply(challengeId!, replay);
      if (!_current(generation)) return;
      if (score != engine.score) throw StateError('Replay mismatch');
      if (owner != null) await _service.clearReply(owner, challengeId!);
      if (!_current(generation)) return;
      replySent = true;
      verified = true;
    } catch (_) {
      if (_current(generation)) {
        error = 'Your first result wasn’t sent. Keep this game open and retry.';
      }
    } finally {
      if (_current(generation)) {
        replying = false;
        _publish();
      }
    }
  }

  final ValueNotifier<int> frame = ValueNotifier(0);
  String? _userId;
  bool _disposed = false;
  int _generation = 0, _boardGeneration = 0;
  PopcornPhase phase = PopcornPhase.ready;
  PopcornEngine engine = PopcornEngine(1);
  PopcornRound? _round;
  bool practice = false, posting = false, posted = false, boardLoading = false;
  PopcornLeaderboard board = const PopcornLeaderboard();
  String? error, boardError;
  int target = 500, countdown = 3;
  double fraction = 0;
  Duration _accumulator = Duration.zero, _countdownElapsed = Duration.zero;
  int get secondsLeft => ((PopcornEngine.roundTicks -
              (engine.version >= 3 ? engine.roundTick : engine.tick)) /
          20)
      .ceil()
      .clamp(0, 30);
  bool get animating =>
      phase == PopcornPhase.playing || phase == PopcornPhase.countdown;
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  void bind(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _generation++;
    _boardGeneration++;
    phase = PopcornPhase.ready;
    practice = false;
    _round = null;
    engine = PopcornEngine(1);
    board = const PopcornLeaderboard();
    posting = false;
    posted = false;
    boardLoading = false;
    verified = false;
    replySent = false;
    replying = false;
    error = null;
    boardError = null;
    _publish();
    if (userId != null) loadBoard();
  }

  Future<void> loadBoard() async {
    if (_userId == null) return;
    final owner = _userId, request = ++_boardGeneration;
    boardLoading = true;
    boardError = null;
    _publish();
    try {
      final result = await _service.leaderboard();
      if (!_disposed && owner == _userId && request == _boardGeneration) {
        board = result;
      }
    } catch (_) {
      if (!_disposed && owner == _userId && request == _boardGeneration) {
        boardError = 'Leaderboard couldn’t load. Try again.';
      }
    } finally {
      if (!_disposed && owner == _userId && request == _boardGeneration) {
        boardLoading = false;
        _publish();
      }
    }
  }

  Future<void> startRanked() async {
    if ((_userId == null && challengeId != null) ||
        phase == PopcornPhase.starting ||
        posting ||
        replying) {
      return;
    }
    final generation = ++_generation;
    phase = PopcornPhase.starting;
    error = null;
    _publish();
    try {
      final round = challengeId == null
          ? (_userId == null
              ? await _service.startGuest()
              : await _service.start())
          : await _service.startChallenge(challengeId!);
      if (!_current(generation)) return;
      _round = round;
      _begin(round.seed, false, version: round.version);
    } catch (_) {
      if (_current(generation)) {
        phase = PopcornPhase.ready;
        error = challengeId != null
            ? 'This first attempt couldn’t start. It may already be in progress or expired. Return to chat to check the challenge.'
            : 'This round couldn’t start. Try again, or play offline practice.';
        _publish();
      }
    }
  }

  void startPractice() {
    if (posting || replying || challengeId != null) return;
    _generation++;
    _round = null;
    _begin(Random().nextInt(2147483646) + 1, true);
  }

  void _begin(int seed, bool isPractice, {int version = 3}) {
    engine = PopcornEngine(seed, version: version);
    practice = isPractice;
    target = 500;
    posted = false;
    verified = false;
    replySent = false;
    replying = false;
    error = null;
    countdown = 3;
    fraction = 0;
    _accumulator = Duration.zero;
    _countdownElapsed = Duration.zero;
    phase = PopcornPhase.countdown;
    _publish();
    onSound?.call('arcade-select');
  }

  void move(double normalized) {
    target = (normalized.clamp(0, 1) * 1000).round();
  }

  void nudge(int direction) {
    target = (target + direction * 120).clamp(0, 1000);
  }

  void dragBy(double normalizedDelta) {
    target = (target + normalizedDelta * 1000).round().clamp(0, 1000);
  }

  void advance(Duration delta) {
    if (!animating || delta.isNegative) return;
    if (delta > const Duration(milliseconds: 250)) {
      pause();
      return;
    }
    final sounds = <PopcornEvent>{};
    final oldLives = engine.lives, oldLevel = engine.level;
    final oldScore = engine.score,
        oldCombo = engine.combo,
        oldSeconds = secondsLeft,
        oldPhase = phase,
        oldCountdown = countdown;
    if (phase == PopcornPhase.countdown) {
      _countdownElapsed += delta;
      countdown = 3 - _countdownElapsed.inSeconds;
      if (countdown <= 0) {
        phase = PopcornPhase.playing;
        _accumulator = Duration.zero;
      }
    } else {
      _accumulator += delta;
      while (_accumulator >= const Duration(milliseconds: 50)) {
        _accumulator -= const Duration(milliseconds: 50);
        engine.step(target, practice: practice);
        sounds.addAll(engine.events);
        if (!practice && engine.complete) {
          phase = engine.version >= 3 && !engine.runOver
              ? PopcornPhase.roundComplete
              : PopcornPhase.finished;
          _accumulator = Duration.zero;
          break;
        }
      }
      fraction = _accumulator.inMicroseconds / 50000;
    }
    if (phase == PopcornPhase.finished &&
        oldPhase != PopcornPhase.finished &&
        challengeId != null) {
      replyToChallenge();
    }
    if (phase == PopcornPhase.finished &&
        oldPhase != PopcornPhase.finished &&
        challengeId == null &&
        !practice) {
      verifyForSharing(quietly: true);
    }
    frame.value++;
    if (oldLives != engine.lives ||
        oldLevel != engine.level ||
        oldScore != engine.score ||
        oldCombo != engine.combo ||
        oldSeconds != secondsLeft ||
        oldPhase != phase ||
        oldCountdown != countdown) {
      _publish();
    }
    for (final event in sounds) {
      onSound?.call(switch (event) {
        PopcornEvent.catchTreat => 'popcorn-catch',
        PopcornEvent.gold => 'popcorn-gold',
        PopcornEvent.burnt => 'popcorn-burnt',
        PopcornEvent.streak => 'popcorn-streak',
      });
    }
    if (oldPhase != phase &&
        (phase == PopcornPhase.roundComplete ||
            phase == PopcornPhase.finished)) {
      onSound?.call('popcorn-round');
    }
  }

  void nextRound() {
    if (phase != PopcornPhase.roundComplete) return;
    engine.nextRound();
    countdown = 3;
    _countdownElapsed = Duration.zero;
    _accumulator = Duration.zero;
    fraction = 0;
    phase = PopcornPhase.countdown;
    _publish();
    onSound?.call('arcade-select');
  }

  void finishRun() {
    if (phase != PopcornPhase.roundComplete) return;
    phase = PopcornPhase.finished;
    _publish();
    if (challengeId != null) {
      replyToChallenge();
    } else {
      verifyForSharing(quietly: true);
    }
  }

  PopcornPhase _resumePhase = PopcornPhase.playing;
  void pause() {
    if (!animating) return;
    _resumePhase = phase;
    phase = PopcornPhase.paused;
    _publish();
    onSound?.call('arcade-pause');
  }

  void resume() {
    if (phase == PopcornPhase.paused) {
      phase = _resumePhase;
      _publish();
    }
  }

  void finishPractice() {
    if (practice) {
      phase = PopcornPhase.finished;
      _publish();
    }
  }

  Future<void> postScore() async {
    if (_userId == null ||
        practice ||
        phase != PopcornPhase.finished ||
        _round == null ||
        posted ||
        posting) {
      return;
    }
    final generation = _generation;
    posting = true;
    error = null;
    _publish();
    try {
      final guestRound = _round!;
      final ownedRound = guestRound.guestToken == null
          ? guestRound
          : await _service.claimGuest(guestRound);
      if (!_current(generation)) return;
      final score =
          await _service.submit(ownedRound, List<int>.of(engine.targets));
      if (!_current(generation)) return;
      if (score != engine.score) throw StateError('Replay mismatch');
      posted = true;
      _round = ownedRound;
      if (guestRound.guestToken != null) {
        await _service.clearGuestScore(guestRound.id);
      }
      if (!_current(generation)) return;
      await loadBoard();
    } catch (failure) {
      if (_current(generation)) {
        error = failure is ApiException && failure.statusCode == 410
            ? 'This round expired. Play another round to post a score.'
            : 'Your score wasn’t posted. Try again while this round is still open.';
      }
    } finally {
      if (_current(generation)) {
        posting = false;
        _publish();
      }
    }
  }

  Future<bool> rememberGuestScore() async {
    if (_userId != null ||
        phase != PopcornPhase.finished ||
        practice ||
        _round?.guestToken == null) {
      return false;
    }
    await _service.rememberGuestScore(_round!, List<int>.of(engine.targets));
    return true;
  }

  Future<void> restoreGuestScore() async {
    if (_userId == null || phase != PopcornPhase.ready || challengeId != null) {
      return;
    }
    final generation = _generation;
    final pending = await _service.pendingGuestScore();
    if (!_current(generation) ||
        phase != PopcornPhase.ready ||
        pending == null) {
      return;
    }
    final (round, targets) = pending;
    if (targets.isEmpty || targets.length > 36000) return;
    final replay = PopcornEngine(round.seed, version: 3);
    for (final target in targets) {
      if (target < 0 || target > 1000 || replay.runOver) return;
      if (replay.roundComplete) replay.nextRound();
      replay.step(target);
    }
    if (!replay.complete) return;
    _round = round;
    engine = replay;
    practice = false;
    phase = PopcornPhase.finished;
    _publish();
  }

  Future<void> removeScore() async {
    if (posting) return;
    final generation = _generation;
    posting = true;
    error = null;
    _publish();
    try {
      await _service.removeScore();
      if (_current(generation)) {
        _round = null;
        posted = false;
        phase = PopcornPhase.ready;
        engine = PopcornEngine(1);
        practice = false;
        target = 500;
        await loadBoard();
      }
    } catch (_) {
      if (_current(generation)) {
        error = 'Couldn’t remove your score. Try again.';
      }
    } finally {
      if (_current(generation)) {
        posting = false;
        _publish();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    frame.dispose();
    super.dispose();
  }
}
