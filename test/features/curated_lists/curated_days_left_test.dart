import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/curated_lists/models/curated_list.dart';
import 'package:flixie_app/features/curated_lists/presentation/widgets/curated_list_intro.dart';

void main() {
  final christmas = CuratedList(
      id: 'days',
      title: 'Christmas',
      filmCount: 31,
      completionTarget: 5,
      startsAt: DateTime.utc(2026, 11, 1),
      endsAt: DateTime.utc(2027, 1, 1));
  test('remaining days are only shown while open and include the final UK day',
      () {
    expect(christmas.daysLeftAt(DateTime.utc(2026, 10, 31, 23, 59)), isNull);
    expect(christmas.daysLeftAt(DateTime.utc(2026, 11, 1)), 61);
    expect(christmas.daysLeftAt(DateTime.utc(2026, 11, 1, 23, 59)), 61);
    expect(christmas.daysLeftAt(DateTime.utc(2026, 11, 2)), 60);
    expect(christmas.daysLeftAt(DateTime.utc(2026, 12, 31, 23, 59)), 1);
    expect(christmas.daysLeftAt(DateTime.utc(2027, 1, 1)), isNull);
  });
  test('opening label switches to days left when the challenge starts', () {
    expect(christmas.timingLabelAt(DateTime.utc(2026, 10, 28, 19)),
        'Opens in 4 days');
    expect(christmas.timingLabelAt(DateTime.utc(2026, 10, 30, 23, 59)),
        'Opens in 2 days');
    expect(
        christmas.timingLabelAt(DateTime.utc(2026, 10, 31)), 'Opens in 1 day');
    expect(christmas.timingLabelAt(DateTime.utc(2026, 11, 1)), '61 days left');
    expect(christmas.timingLabelAt(DateTime.utc(2027, 1, 1)), isNull);
  });
  test('UK calendar count remains correct over the daylight-saving change', () {
    final october = CuratedList(
        id: 'dst',
        title: 'October',
        startsAt: DateTime.utc(2026, 9, 30, 23),
        endsAt: DateTime.utc(2026, 11, 1));
    expect(october.daysLeftAt(DateTime.utc(2026, 9, 30, 23)), 31);
    expect(october.daysLeftAt(DateTime.utc(2026, 10, 24, 23)), 7);
    expect(october.daysLeftAt(DateTime.utc(2026, 10, 25, 23, 59)), 7);
    expect(october.daysLeftAt(DateTime.utc(2026, 10, 26)), 6);
  });
  for (final now in [DateTime.utc(2026, 10, 30), DateTime.utc(2026, 11, 15)]) {
    for (final viewport in [(390.0, 1.0), (320.0, 1.7)]) {
      testWidgets(
          'countdown stays right aligned and readable at $viewport on $now',
          (tester) async {
        tester.view.physicalSize = Size(viewport.$1, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
                body: MediaQuery(
                    data: MediaQueryData(
                        textScaler: TextScaler.linear(viewport.$2)),
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: CuratedListIntro(list: christmas, now: now))))));
        expect(find.text(christmas.timingLabelAt(now)!), findsOneWidget);
        expect(
            tester.getBottomRight(find.text(christmas.timingLabelAt(now)!)).dx,
            closeTo(
                tester.getBottomRight(find.byType(CuratedListIntro)).dx, .01));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
