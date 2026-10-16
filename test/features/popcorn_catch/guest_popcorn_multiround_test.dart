import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/popcorn_catch/domain/popcorn_engine.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/controllers/popcorn_controller.dart';
import 'guest_popcorn_test.dart' show GuestRoundService;

void main() {
  test('restoring a guest run keeps round transitions and score', () async {
    SharedPreferences.setMockInitialValues({});
    final service = GuestRoundService(),
        round = await GuestRoundService().startGuest();
    final e = PopcornEngine(round.seed, version: 3);
    for (var i = 0; i < 600; i++) {
      e.step(0);
    }
    expect(e.roundComplete, isTrue);
    e.nextRound();
    for (var i = 0; i < 600 && !e.complete; i++) {
      e.step(0);
    }
    expect(e.complete, isTrue);
    await service.rememberGuestScore(round, e.targets);
    final restored =
        PopcornController(userId: 'fictional-casey', service: service);
    addTearDown(restored.dispose);
    await restored.restoreGuestScore();
    expect(restored.phase, PopcornPhase.finished);
    expect(restored.engine.level, e.level);
    expect(restored.engine.tick, e.tick);
    expect(restored.engine.score, e.score);
  });
}
