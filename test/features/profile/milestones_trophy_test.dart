import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/profile_milestone.dart';
import 'package:flixie_app/features/profile/presentation/pages/milestones_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/milestone_shield.dart';
import '../../profile_milestones_test.dart' show items;

void main() {
  testWidgets('Next up uses unearned shields; Earned uses coloured trophies',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MilestonesContent(
                data: ProfileMilestones(items: items, owner: true)))));
    await t.tap(find.text('Next up'));
    await t.pumpAndSettle();
    expect(find.text('14 / 25'), findsOneWidget);
    final unearned =
        t.widgetList<MilestoneShield>(find.byType(MilestoneShield));
    expect(unearned, isNotEmpty);
    expect(unearned.every((badge) => !badge.earned), isTrue);
    await t.tap(find.text('Earned'));
    await t.pumpAndSettle();
    expect(find.text('10 films watched'), findsOneWidget);
    expect(find.text('14 / 25'), findsNothing);
    expect(
        t.widget<MilestoneShield>(find.byType(MilestoneShield)).earned, isTrue);
    expect(t.takeException(), isNull);
  });
}
