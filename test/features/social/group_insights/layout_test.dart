import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/controllers/group_insights_controller.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_insights/group_insights_content.dart';
import 'package:flixie_app/models/group_insights.dart';
import 'fixture.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(844, 390),
    const Size(1024, 768)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('insights reflow at $size and ${scale}x text',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final data = insightFixture(
            title:
                'The Odyssey and a very long film title that should stay readable');
        (data['mostActiveMembers'] as List).single['username'] =
            'a_very_long_group_contributor_name';
        final c = GroupInsightsController(
            load: (_, {timeWindow, limit}) async =>
                GroupInsightsResponse.fromJson(data));
        addTearDown(c.dispose);
        await c.bind('group');
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(body: GroupInsightsContent(controller: c))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Tap to reveal review'), 200);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tap to reveal review'));
        await tester.pumpAndSettle();
        expect(find.text('The fictional ending is revealed here.'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
            find.text('@a_very_long_group_contributor_name'), 200);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
