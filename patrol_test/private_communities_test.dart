import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/pages/private_communities_screen.dart';
import '../test/features/social/private_communities_test.dart'
    show PrivateFixture;

void main() {
  for (final light in [true, false]) {
    patrolTest(
        'private community invitation requires acceptance ${light ? 'light' : 'dark'}',
        ($) async {
      final fixture = PrivateFixture();
      final router = GoRouter(initialLocation: '/private', routes: [
        GoRoute(
            path: '/private',
            builder: (c, s) => PrivateCommunitiesScreen(service: fixture)),
        GoRoute(
            path: '/genre-communities/:id',
            builder: (c, s) => const Scaffold(body: Text('Inside community')))
      ]);
      addTearDown(router.dispose);
      await $.pumpWidgetAndSettle(MaterialApp.router(
          theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
          routerConfig: router));
      await $('Movie night club').scrollTo().tap();
      await $('Join community').waitUntilVisible();
      expect(fixture.accepted, 0);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await $('Join community').scrollTo().tap();
      await $('Inside community').waitUntilVisible();
      expect(fixture.accepted, 1);
    });
  }
}
