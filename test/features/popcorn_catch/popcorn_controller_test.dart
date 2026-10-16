import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/popcorn_catch/domain/popcorn_engine.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/popcorn_catch/data/popcorn_service.dart';
import 'package:flixie_app/features/popcorn_catch/models/popcorn_leaderboard.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/controllers/popcorn_controller.dart';

class FixturePopcornService extends PopcornService {
  Completer<PopcornRound>? delayed;
  Completer<int>? delayedPost;
  int submissions = 0;
  List<int>? replay;
  bool failStart = false;
  int? bestBefore;
  @override
  Future<PopcornRound> start() async {
    if (failStart) throw StateError('offline');
    return delayed != null
        ? await delayed!.future
        : PopcornRound('fixture-round', 1, personalBest: bestBefore);
  }

  @override
  Future<int> verify(PopcornRound round, List<int> targets) async {
    final e = PopcornEngine(round.seed);
    for (final t in targets) {
      e.step(t);
    }
    return e.score;
  }

  @override
  Future<int> submit(PopcornRound round, List<int> targets) async {
    submissions++;
    replay = targets;
    return delayedPost != null ? await delayedPost!.future : 10;
  }

  @override
  Future<PopcornLeaderboard> leaderboard() async =>
      const PopcornLeaderboard(personalBest: 10, personalRank: 1);
}

class ChallengeFixtureService extends FixturePopcornService {
  int replies = 0;
  bool failReply = false;
  @override
  Future<PopcornRound> startChallenge(String id) async =>
      const PopcornRound('challenge-round', 1, personalBest: 20);
  @override
  Future<int> reply(String id, List<int> targets) async {
    replies++;
    replay = targets;
    if (failReply) throw StateError('offline');
    return 10;
  }
}

void play(PopcornController c, int steps) {
  for (var i = 0; i < steps; i++) {
    c.advance(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('ranked round finishes after active play and only posts explicitly',
      () async {
    final s = FixturePopcornService(),
        c = PopcornController(
            userId: 'casey', service: FixturePopcornService());
    c.dispose();
    final game = PopcornController(userId: 'casey', service: s);
    addTearDown(game.dispose);
    await game.startRanked();
    play(game, 60);
    expect(game.phase, PopcornPhase.playing);
    play(game, 100);
    game.pause();
    play(game, 600);
    expect(game.engine.tick, 100);
    game.resume();
    play(game, 500);
    expect(game.phase, PopcornPhase.finished);
    expect(s.submissions, 0);
    expect(game.engine.score, 10);
    await game.postScore();
    await game.postScore();
    expect(s.submissions, 1);
    expect(s.replay, hasLength(165));
    expect(game.posted, isTrue);
    expect(game.board.personalBest, 10);
  });
  test('offline failure offers practice and practice cannot post scores',
      () async {
    final s = FixturePopcornService()..failStart = true;
    final c = PopcornController(userId: 'casey', service: s);
    addTearDown(c.dispose);
    await c.startRanked();
    expect(c.error, contains('offline practice'));
    c.startPractice();
    play(c, 700);
    expect(c.phase, PopcornPhase.playing);
    c.finishPractice();
    await c.postScore();
    expect(s.submissions, 0);
  });
  test('account changes discard late start and post results', () async {
    final s = FixturePopcornService()..delayed = Completer<PopcornRound>();
    final c = PopcornController(userId: 'casey', service: s);
    addTearDown(c.dispose);
    final pending = c.startRanked();
    c.bind('robin');
    s.delayed!.complete(const PopcornRound('caseys-round', 1));
    await pending;
    expect(c.phase, PopcornPhase.ready);
    s.delayed = null;
    await c.startRanked();
    play(c, 660);
    s.delayedPost = Completer<int>();
    final post = c.postScore();
    c.bind(null);
    s.delayedPost!.complete(10);
    await post;
    expect(c.posted, isFalse);
    expect(c.board.personalBest, isNull);
    expect(c.posting, isFalse);
  });
  test('new personal best uses pre-round score even after posting', () async {
    final s = FixturePopcornService()..bestBefore = 5;
    final c = PopcornController(userId: 'casey', service: s);
    addTearDown(c.dispose);
    await c.startRanked();
    play(c, 660);
    expect(c.newBest, isTrue);
    await c.postScore();
    expect(c.newBest, isTrue);
    s.bestBefore = 1000;
    await c.startRanked();
    c.move(0);
    play(c, 660);
    expect(c.engine.score, 30);
    expect(c.roughRound, isTrue);
    expect(c.newBest, isFalse);
  });
  test('challenge first result sends automatically without public posting',
      () async {
    final s = ChallengeFixtureService();
    final c = PopcornController(
        userId: 'robin', service: s, challengeId: 'challenge');
    addTearDown(c.dispose);
    await c.startRanked();
    play(c, 660);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.phase, PopcornPhase.finished);
    expect(c.replySent, isTrue);
    expect(s.replies, 1);
    expect(s.submissions, 0);
    expect(s.replay, hasLength(165));
    await c.replyToChallenge();
    expect(s.replies, 1);
  });
  test('offline first result is stored per account and retry preserves it',
      () async {
    final s = ChallengeFixtureService()..failReply = true;
    final c = PopcornController(
        userId: 'robin', service: s, challengeId: 'challenge');
    addTearDown(c.dispose);
    await c.startRanked();
    play(c, 660);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.replySent, isFalse);
    expect(await s.pendingReply('robin', 'challenge'), hasLength(165));
    expect(await s.pendingReply('casey', 'challenge'), isNull);
    s.failReply = false;
    await c.replyToChallenge();
    expect(c.replySent, isTrue);
    expect(s.replies, 2);
    expect(await s.pendingReply('robin', 'challenge'), isNull);
  });
  test('a stalled frame pauses instead of silently skipping gameplay',
      () async {
    final c =
        PopcornController(userId: 'casey', service: FixturePopcornService());
    addTearDown(c.dispose);
    await c.startRanked();
    play(c, 60);
    c.advance(const Duration(seconds: 2));
    expect(c.phase, PopcornPhase.paused);
    expect(c.engine.tick, 0);
  });
}
