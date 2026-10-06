import 'package:flixie_app/features/watchlist/presentation/widgets/watchlist_navigation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final pushed in [false, true]) {
    testWidgets(
        pushed
            ? 'in-app Watchlist returns to the previous page'
            : 'widget Watchlist opens Home', (tester) async {
      final router = GoRouter(
        initialLocation: pushed ? '/profile' : '/watchlist',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('Home page')),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const Scaffold(body: Text('Profile page')),
          ),
          GoRoute(
            path: '/watchlist',
            builder: (_, __) => Scaffold(
              appBar: AppBar(leading: const WatchlistNavigationButton()),
              body: const Text('Watchlist page'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      if (pushed) {
        router.push('/watchlist');
        await tester.pumpAndSettle();
      }
      final button = pushed ? find.byType(BackButton) : find.byTooltip('Home');
      expect(button, findsOneWidget);
      expect(find.byIcon(Icons.home_outlined),
          pushed ? findsNothing : findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text(pushed ? 'Profile page' : 'Home page'), findsOneWidget);
      expect(find.text('Watchlist page'), findsNothing);
    });
  }
}
