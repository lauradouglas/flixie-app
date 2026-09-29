import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/pick_for_us/pick_for_us_screen.dart';
import '../test/support/pick_fixture.dart';

void main() {
  patrolTest('mood to fresh shortlist to film and back survives app resume',
      ($) async {
    final service = FixturePickService();
    final router = GoRouter(initialLocation: '/pick', routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Home destination')),
          routes: [
            GoRoute(
                path: 'pick',
                builder: (_, __) =>
                    PickForUsScreen(userId: 'fixture-casey', service: service)),
          ]),
      GoRoute(
          path: '/movies/:id',
          builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text('Film ${state.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
    await $('Feel good').tap();
    await $('Next · Your evening').tap();
    await $('Find my picks').tap();
    await $('Alien').waitUntilVisible();
    expect(service.mood, 'feel_good');
    await $.tester.scrollUntilVisible(find.text('Show different films'), 200,
        scrollable: find.byType(Scrollable).first);
    await $('Show different films').tap();
    await $('Se7en').waitUntilVisible();
    expect(service.excluded, {348, 571, 539});
    await $('View movie').tap();
    await $('Film 807').waitUntilVisible();
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $('Film 807').waitUntilVisible();
    await $(find.byType(BackButton)).tap();
    await $('Se7en').waitUntilVisible();
    await $.tester.scrollUntilVisible(find.text('Change preferences'), 200,
        scrollable: find.byType(Scrollable).first);
    await $('Change preferences').tap();
    await $('Feel good · Change').waitUntilVisible();
  });
}
