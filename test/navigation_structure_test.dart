import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/navigation_structure_fixture.dart';

void main() {
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
