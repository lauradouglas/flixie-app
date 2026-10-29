import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/data/milestone_badge_service.dart';
import '../../support/watchlist_auth.dart';
import 'package:flixie_app/features/profile/models/milestone_badge.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_milestone_badges.dart';
import 'package:flixie_app/features/profile/presentation/widgets/badges_explainer.dart';
import 'package:flixie_app/features/profile/presentation/widgets/film_milestone_badge.dart';

List<MilestoneBadge> fixture({bool lockedPurple = false}) => [
      for (final b in MilestoneBadge.examples)
        MilestoneBadge(
            id: b.id,
            target: b.target,
            metal: b.metal,
            label: b.label,
            earned: !lockedPurple || b.target != 500,
            displayOrder: b.target == 50 ? 0 : null),
    ];
void main() {
  testWidgets(
      'profile customisation persists three choices and prevents selecting a fourth',
      (t) async {
    final service = BadgeFixtureService();
    final auth = TestAuth();
    await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            home: Scaffold(
                body: ProfileMilestoneBadges(
                    userId: 'viewer', editable: true, service: service)))));
    await t.pumpAndSettle();
    await t.tap(find.text('Customise badges'));
    await t.pumpAndSettle();
    await t.tap(find.text('100+ films'));
    await t.pump();
    await t.tap(find.text('250+ films'));
    await t.pump();
    await t.tap(find.text('500+ films'));
    await t.pump();
    expect(
        t
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .where((b) => b.value == true)
            .length,
        3);
    await t.ensureVisible(find.text('Save badges'));
    await t.tap(find.text('Save badges'));
    await t.pumpAndSettle();
    expect(service.selected, ['films_50', 'films_100', 'films_250']);
    expect(find.byType(FilmMilestoneBadge), findsNWidgets(3));
    await t.tap(find.text('Customise badges'));
    await t.pumpAndSettle();
    expect(
        t
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .map((b) => b.value),
        [true, true, true, false]);
    expect(t.takeException(), isNull);
  });
  testWidgets('picker actions and rows reflow on a narrow phone at large text',
      (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(320, 640);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: MilestoneBadgePicker(
                            badges: fixture(), save: (_) async => [])))))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'locked purple cannot be selected; earned badges save in chosen order',
      (t) async {
    List<String>? saved;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MilestoneBadgePicker(
                    badges: fixture(lockedPurple: true),
                    save: (ids) async {
                      saved = ids;
                      return fixture();
                    })))));
    final boxes =
        t.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();
    expect(boxes.last.onChanged, isNull);
    await t.tap(find.text('100+ films'));
    await t.pump();
    expect(find.text('Choose up to 3 for your profile · 2/3'), findsOneWidget);
    await t.tap(find.text('Save badges'));
    await t.pumpAndSettle();
    expect(saved, ['films_50', 'films_100']);
  });
  testWidgets('failed save preserves selections and can retry hiding all',
      (t) async {
    var fail = true;
    List<String>? saved;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MilestoneBadgePicker(
                    badges: fixture(),
                    save: (ids) async {
                      if (fail) throw Exception();
                      saved = ids;
                      return [];
                    })))));
    await t.tap(find.text('Save badges'));
    await t.pumpAndSettle();
    expect(find.text('Couldn’t save your badges. Try again.'), findsOneWidget);
    await t.tap(find.text('50 films'));
    await t.pump();
    fail = false;
    await t.tap(find.text('Save badges'));
    await t.pumpAndSettle();
    expect(saved, isEmpty);
  });
  testWidgets(
      'guest examples show four circular tiers at narrow large text and tablet sizes',
      (t) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final width in [320.0, 430.0, 834.0, 1194.0]) {
      t.view.physicalSize = Size(width, 900);
      await t.pumpWidget(const MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: BadgesExplainer()))))));
      expect(find.byType(FilmMilestoneBadge), findsNWidgets(5));
      expect(find.text('Bronze'), findsOneWidget);
      expect(find.text('Silver'), findsOneWidget);
      expect(find.text('Gold'), findsOneWidget);
      expect(t.takeException(), isNull);
    }
  });
}

class BadgeFixtureService extends MilestoneBadgeService {
  List<String> selected = ['films_50'];
  List<MilestoneBadge> get data => [
        for (final b in MilestoneBadge.examples)
          MilestoneBadge(
              id: b.id,
              target: b.target,
              metal: b.metal,
              label: b.label,
              earned: true,
              displayOrder:
                  selected.contains(b.id) ? selected.indexOf(b.id) : null)
      ];
  @override
  Future<List<MilestoneBadge>> load(String userId) async => data;
  @override
  Future<List<MilestoneBadge>> save(String userId, List<String> ids) async {
    selected = ids;
    return data;
  }
}
