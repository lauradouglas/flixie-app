import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/space_premiere/domain/space_engine.dart';
import 'package:flixie_app/features/space_premiere/presentation/controllers/space_controller.dart';
import 'package:flixie_app/features/space_premiere/presentation/pages/space_premiere_screen.dart';

void main() {
  patrolTest('start, steer, pause and resume Space Premiere offline',
      ($) async {
    final c = SpaceController();
    addTearDown(c.dispose);
    await $.pumpWidgetAndSettle(MaterialApp(
        theme: AppTheme.darkTheme, home: SpacePremiereScreen(controller: c)));
    await $.tester.ensureVisible(find.text('Start game'));
    await $(find.text('Start game')).tap();
    await $.pump(const Duration(milliseconds: 100));
    expect(c.engine.phase, SpacePhase.playing);
    final before = c.engine.x;
    await $.tester.drag(
        find.byKey(const ValueKey('space-steering')), const Offset(-90, 0));
    await $.pump(const Duration(milliseconds: 150));
    expect(c.engine.x, lessThan(before));
    await $(find.byTooltip('Pause game')).tap();
    await $.pumpAndSettle();
    expect(c.engine.phase, SpacePhase.paused);
    await $(find.text('Resume')).tap();
    await $.pump(const Duration(milliseconds: 100));
    expect(c.engine.phase, SpacePhase.playing);
    c.pause();
    await $.pumpAndSettle();
    expect($.tester.takeException(), isNull);
  });
}
