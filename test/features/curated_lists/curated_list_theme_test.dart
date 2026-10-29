import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/curated_lists/models/curated_list.dart';
import 'package:flixie_app/features/curated_lists/presentation/pages/curated_list_page.dart';
import 'package:flixie_app/features/curated_lists/presentation/widgets/curated_list_views.dart';
import 'package:flixie_app/features/curated_lists/presentation/widgets/christmas_reward_frame.dart';
import 'curated_list_fixtures.dart';

void main() {
  test('missing and unknown themes default to standard', () {
    expect(
        CuratedList.fromJson({'id': 'list'}).theme, CuratedListTheme.standard);
    expect(CuratedList.fromJson({'id': 'list', 'theme': 'FUTURE'}).theme,
        CuratedListTheme.standard);
    expect(CuratedList.fromJson({'id': 'list', 'theme': 'CHRISTMAS'}).theme,
        CuratedListTheme.christmas);
  });
  for (final theme in CuratedListTheme.values) {
    for (final detail in [false, true]) {
      testWidgets(
          '$theme controls decorations independently of rewards; detail $detail',
          (tester) async {
        final auth = CuratedFixtureAuth();
        final list = CuratedList(
            id: fixtureId,
            title: 'Theme fixture',
            theme: theme,
            filmCount: 2,
            completionTarget: 1,
            films: fixtureList().films,
            rewards: detail || theme == CuratedListTheme.standard
                ? fixtureList().rewards
                : const [],
            startsAt: fixtureList().startsAt,
            endsAt: fixtureList().endsAt);
        final service = CuratedFixtureService()..value = list;
        await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: detail
                    ? CuratedListPage(id: fixtureId, service: service)
                    : Scaffold(
                        body: CuratedListCard(list: list, onTap: () {})))));
        await tester.pumpAndSettle();
        final paint = find.descendant(
            of: find.byType(ChristmasRewardFrame),
            matching: find.byType(IgnorePointer));
        expect(
            paint,
            theme == CuratedListTheme.christmas
                ? findsOneWidget
                : findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        auth.dispose();
      });
    }
  }
}
