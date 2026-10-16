import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/popcorn_catch/data/popcorn_service.dart';
import 'package:flixie_app/features/popcorn_catch/domain/popcorn_engine.dart';
import 'package:flixie_app/features/popcorn_catch/models/popcorn_leaderboard.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/controllers/popcorn_controller.dart';

class GuestRoundService extends PopcornService {
  int claims = 0, posts = 0, boards = 0;
  @override
  Future<PopcornRound> startGuest() async => PopcornRound('guest-round', 1,
      version: 3,
      guestToken: 'guest-secret',
      expiresAt: DateTime.now().add(const Duration(hours: 24)));
  @override
  Future<PopcornRound> claimGuest(PopcornRound round) async {
    claims++;
    expect(round.guestToken, 'guest-secret');
    return PopcornRound(round.id, round.seed, version: 3);
  }

  @override
  Future<int> submit(PopcornRound round, List<int> targets) async {
    posts++;
    expect(round.guestToken, isNull);
    final replay = PopcornEngine(round.seed, version: 3);
    for (final target in targets) {
      if (replay.roundComplete) replay.nextRound();
      replay.step(target);
    }
    expect(replay.complete, isTrue);
    return replay.score;
  }

  @override
  Future<PopcornLeaderboard> leaderboard() async {
    boards++;
    return const PopcornLeaderboard();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('guest plays a timed round and can only claim/post it after signup',
      () async {
    final service = GuestRoundService();
    final guest = PopcornController(userId: null, service: service);
    addTearDown(guest.dispose);
    await guest.loadBoard();
    await guest.startRanked();
    expect(guest.phase, PopcornPhase.countdown);
    for (var i = 0;
        i < 700 &&
            guest.phase != PopcornPhase.finished &&
            guest.phase != PopcornPhase.roundComplete;
        i++) {
      guest.advance(const Duration(milliseconds: 50));
    }
    if (guest.phase == PopcornPhase.roundComplete) guest.finishRun();
    expect(guest.phase, PopcornPhase.finished);
    final score = guest.engine.score;
    await guest.postScore();
    expect(service.posts, 0);
    expect(service.claims, 0);
    expect(service.boards, 0);
    expect(await guest.rememberGuestScore(), isTrue);
    final signedIn =
        PopcornController(userId: 'fictional-casey', service: service);
    addTearDown(signedIn.dispose);
    await signedIn.restoreGuestScore();
    expect(signedIn.phase, PopcornPhase.finished);
    expect(signedIn.engine.score, score);
    expect(service.posts, 0); // Signup alone never publishes.
    await signedIn.postScore();
    expect(signedIn.posted, isTrue);
    expect(service.claims, 1);
    expect(service.posts, 1);
    expect(await service.pendingGuestScore(), isNull);
    await signedIn.postScore();
    expect(service.posts, 1);
  });
  test(
      'expired guest scores are discarded and account changes clear restored results',
      () async {
    final service = GuestRoundService();
    await service.rememberGuestScore(
        PopcornRound('expired', 1,
            version: 3,
            guestToken: 'secret',
            expiresAt: DateTime.now().subtract(const Duration(seconds: 1))),
        [500]);
    expect(await service.pendingGuestScore(), isNull);
    final c = PopcornController(userId: 'casey', service: service);
    addTearDown(c.dispose);
    c.bind(null);
    await c.restoreGuestScore();
    expect(c.phase, PopcornPhase.ready);
    expect(service.claims, 0);
  });
}
