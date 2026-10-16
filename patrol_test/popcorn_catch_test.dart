import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/pages/popcorn_catch_screen.dart';
import '../tool/preview_popcorn_catch.dart';

void main() {
  patrolTest(
      'Pip swipes work over his body and lives refill for the next round',
      ($) async {
    await $.pumpWidgetAndSettle(MaterialApp(
        theme: AppTheme.darkTheme,
        home: PopcornCatchScreen(
            userId: 'fictional-casey',
            service: PreviewPopcornService(version: 3))));
    await $.tester.ensureVisible(find.text('Start round 1'));
    await $(find.text('Start round 1')).tap();
    for (var i = 0; i < 65; i++) {
      await $.pump(const Duration(milliseconds: 50));
    }
    final zone = $.tester.getRect(find.byKey(const Key('popcorn-drag-zone')));
    await $.tester
        .dragFrom(Offset(zone.center.dx, zone.top + 75), const Offset(-600, 0));
    for (var i = 0; i < 600; i++) {
      await $.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Round 1 complete!'), findsOneWidget);
    await $.tester.ensureVisible(find.text('Start round 2'));
    await $(find.text('Start round 2')).tap();
    for (var i = 0; i < 65; i++) {
      await $.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNWidgets(3));
    expect($.tester.takeException(), isNull);
  });

  patrolTest('Pip round ends and posts a score to the fictional leaderboard',
      ($) async {
    final service = PreviewPopcornService();
    await $.pumpWidgetAndSettle(MaterialApp(
        theme: AppTheme.darkTheme,
        home: PopcornCatchScreen(userId: 'fictional-casey', service: service)));
    await $.tester.ensureVisible(find.text('Start round 1'));
    await $(find.text('Start round 1')).tap();
    await $.pump(const Duration(seconds: 3));
    await $.tester
        .drag(find.byKey(const Key('popcorn-drag-zone')), const Offset(60, 0));
    for (var i = 0; i < 680; i++) {
      await $.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('New personal best!'), findsOneWidget);
    await $.tester.ensureVisible(find.text('Post to leaderboard'));
    await $(find.text('Post to leaderboard')).tap();
    await $.pumpAndSettle();
    expect(find.text('Score posted'), findsOneWidget);
    expect(service.best, isNotNull);
    expect(service.best, greaterThanOrEqualTo(0));
    await $(find.byTooltip('Leaderboard')).tap();
    await $.pumpAndSettle();
    expect(find.text('Casey (you)'), findsOneWidget);
    expect($.tester.takeException(), isNull);
  });
}
