import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/navigation_structure_fixture.dart';

void main() {
  testWidgets(
      'active nav taps scroll and refresh each tab without refreshing inactive tabs',
      (t) async {
    final refreshed = <String>[];
    final router = navigationStructureFixture(onRefresh: (path) async {
      refreshed.add(path);
    });
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    final labels = ['Home', 'Discover', 'Plans', 'Social', 'Profile'];
    final paths = ['/', '/search', '/plans', '/social', '/profile'];
    for (var i = 0; i < labels.length; i++) {
      if (i > 0) {
        await t.tap(find.text(labels[i]));
        await t.pumpAndSettle();
        expect(refreshed.length, i,
            reason: 'Switching tabs must retain state without refreshing');
      }
      await t.enterText(find.byType(TextField), 'Alien');
      t.testTextInput.hide();
      await t.drag(find.byType(ListView), const Offset(0, -600));
      await t.pumpAndSettle();
      final position =
          t.state<ScrollableState>(find.byType(Scrollable).last).position;
      expect(position.pixels, greaterThan(0));
      await t.tap(find.text(labels[i]));
      await t.pumpAndSettle();
      expect(position.pixels, 0);
      expect(refreshed, paths.take(i + 1).toList());
      expect(find.text('Alien'), findsOneWidget);
    }
  });

  testWidgets('tab switches and detail returns retain query and scroll',
      (t) async {
    final router = navigationStructureFixture();
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    await t.tap(find.text('Discover'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Alien');
    t.testTextInput.hide();
    await t.drag(find.byType(ListView), const Offset(0, -650));
    await t.pumpAndSettle();
    final offset =
        t.state<ScrollableState>(find.byType(Scrollable).last).position.pixels;
    await t.tap(find.text('Plans'));
    await t.pumpAndSettle();
    expect(find.text('Screen /plans'), findsOneWidget);
    await t.tap(find.text('Social'));
    await t.pumpAndSettle();
    await t.tap(find.text('Discover'));
    await t.pumpAndSettle();
    expect(find.text('Alien'), findsOneWidget);
    expect(
        t.state<ScrollableState>(find.byType(Scrollable).last).position.pixels,
        offset);
    await t.tap(find.byType(ListTile).hitTestable().first);
    await t.pumpAndSettle();
    expect(find.text('Film detail'), findsOneWidget);
    await t.tap(find.text('Return to results'));
    await t.pumpAndSettle();
    expect(find.text('Alien'), findsOneWidget);
    expect(
        t.state<ScrollableState>(find.byType(Scrollable).last).position.pixels,
        offset);
    expect(t.takeException(), isNull);
  });
}
