import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/features/curated_lists/models/curated_list.dart';
import 'package:flixie_app/features/curated_lists/presentation/widgets/curated_rules_sheet.dart';
import 'curated_list_fixtures.dart';

void main() {
  for (final viewport in [
    (390.0, 844.0, 1.0),
    (320.0, 700.0, 1.7),
    (768.0, 1024.0, 1.7),
    (640.0, 360.0, 1.0)
  ]) {
    for (final all in [false, true]) {
      testWidgets('rules scroll and dismiss at $viewport; all films $all',
          (tester) async {
        tester.view.physicalSize = Size(viewport.$1, viewport.$2);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final list = CuratedList(
            id: fixtureId,
            title: 'Did someone say Christmas?',
            filmCount: 31,
            completionTarget: all ? null : 5,
            startsAt: DateTime.utc(2026, 11, 1),
            endsAt: DateTime.utc(2027, 1, 1),
            rewards: fixtureList().rewards,
            watchRule: all ? 'ANY_WATCH' : 'DURING_CHALLENGE');
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(viewport.$3)),
                child: child!),
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () => showFlixiePromptSheet<void>(
                            context: context,
                            builder: (_) => CuratedRulesSheet(list: list)),
                        child: const Text('View rules'))))));
        await tester.tap(find.text('View rules'));
        await tester.pumpAndSettle();
        expect(find.text('Challenge rules'), findsOneWidget);
        expect(
            find.text(
                all ? 'Complete all 31 films.' : 'Choose any 5 from 31 films.'),
            findsOneWidget);
        expect(find.text('1 November'), findsOneWidget);
        expect(find.text('31 December'), findsOneWidget);
        expect(find.text('2026 · UK time'), findsOneWidget);
        if (all) {
          expect(find.textContaining('previous watches'), findsOneWidget);
        }
        await tester.ensureVisible(find.text('Got it'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();
        expect(find.text('Challenge rules'), findsNothing);
        expect(find.text('View rules'), findsOneWidget);
      });
    }
  }
}
