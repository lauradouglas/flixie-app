import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import '../test/support/navigation_structure_fixture.dart';

void main() {
  patrolTest('tabs preserve a search and return from title details', ($) async {
    final router = navigationStructureFixture();
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(MaterialApp.router(routerConfig: router));
    await $('Search').tap();
    await $(find.byType(TextField)).enterText('Alien');
    await $('Social').tap();
    await $('Search').tap();
    expect(find.text('Alien'), findsOneWidget);
    await $('Film 0').tap();
    await $('Return to results').tap();
    expect(find.text('Alien'), findsOneWidget);
  });
}
