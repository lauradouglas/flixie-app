import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/controllers/popcorn_controller.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/widgets/pip_catch_sprite.dart';

void main() {
  testWidgets(
      'Pip blinks, worries with speed, reacts and respects reduced motion',
      (tester) async {
    final c = PopcornController(userId: null)..phase = PopcornPhase.playing;
    addTearDown(c.dispose);
    Future<void> show({bool reduced = false}) async {
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: SizedBox(
                  width: 240,
                  height: 260,
                  child: PipCatchSprite(controller: c)))));
      await tester.pump();
    }

    String asset() =>
        (tester.widget<Image>(find.byType(Image)).image as AssetImage)
            .assetName;
    c.engine.tick = 83;
    await show();
    expect(asset(), endsWith('blink.png'));
    await show(reduced: true);
    expect(asset(), endsWith('catch.png'));
    c.engine.tick = 100;
    c.engine.movement = 1;
    await show();
    expect(asset(), endsWith('worried.png'));
    c.engine.tick = 480;
    await show();
    expect(asset(), endsWith('frantic.png'));
    c.engine.feedback = 'Golden! +30';
    c.engine.feedbackTick = 480;
    await show();
    expect(asset(), endsWith('catch.png'));
    c.engine.feedback = 'Ouch! −1 life';
    await show();
    expect(asset(), endsWith('frantic.png'));
    expect(tester.takeException(), isNull);
  });
}
