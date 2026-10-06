import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test/setup_activation_test.dart' show ActivationFixture;
import '../test/setup_flow_test.dart' show setupApp;

void main() {
  patrolTest(
      'first picks precede optional profile favourites and community joining',
      ($) async {
    // Patrol is a test harness; keep preferences isolated from real accounts.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final fixture = ActivationFixture();
    await $.pumpWidgetAndSettle(setupApp(fixture));
    final taste = find.byKey(const ValueKey('taste-movie:1'));
    await $.tester.ensureVisible(taste);
    await $(taste).tap();
    await $('Continue').tap();
    await $('Skip services for now').tap();
    expect(find.text('Your picks.'), findsOneWidget);
    expect(fixture.favourites, isEmpty);
    await $('Continue to favourites').tap();
    await $('Add my movie picks to favourites').scrollTo().tap();
    expect(fixture.favourites, ['movie:1']);
    await $('Continue to sharing').tap();
    await $('Find my kind of people').tap();
    expect(find.text('Which Alien would you watch again?'), findsOneWidget);
    expect(fixture.joins, isEmpty);
    await $('I’ll explore on my own').tap();
    expect(find.text('Home destination'), findsOneWidget);
    expect(fixture.joins, isEmpty);
  });
}
