import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import '../movies/movie_detail_action_flow_test.dart' show ActionAuth;

void main() {
  setUp(GuestAccess.clear);
  test('only catalogue and guest shell paths are public', () {
    for (final path in [
      '/',
      '/search',
      '/profile',
      '/movies/348',
      '/shows/1399',
      '/people/1'
    ]) {
      expect(GuestAccess.isPublicPath(path), isTrue);
    }
    for (final path in [
      '/friends/person',
      '/watchlist',
      '/messages',
      '/community/settings',
      '/movies/348/history'
    ]) {
      expect(GuestAccess.isPublicPath(path), isFalse);
    }
  });
  test('an intent belongs to its exact title and is consumed once', () {
    GuestAccess.destination = '/movies/348';
    GuestAccess.action = 'watchlist';
    expect(GuestAccess.takeAction('/movies/11'), isNull);
    expect(GuestAccess.takeAction('/movies/348'), 'watchlist');
    expect(GuestAccess.takeAction('/movies/348'), isNull);
  });
  testWidgets('guest collection progress prompts before opening private data',
      (tester) async {
    final auth = ActionAuth();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
              body: TextButton(
                  onPressed: () => GuestAccess.require(context,
                      title: 'Track your collection progress',
                      path: '/collections/809'),
                  child: const Text('Track progress'))))
    ]);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth, child: MaterialApp.router(routerConfig: router)));
    await tester.tap(find.text('Track progress'));
    await tester.pumpAndSettle();
    expect(find.text('Track your collection progress'), findsOneWidget);
    await tester.tap(find.text('Keep exploring'));
    await tester.pumpAndSettle();
    expect(find.text('Track progress'), findsOneWidget);
    expect(GuestAccess.destination, isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    auth.dispose();
  });
  testWidgets(
      'dismiss does nothing; signup preserves the title and save intent',
      (tester) async {
    final auth = ActionAuth();
    final router = GoRouter(initialLocation: '/movies/348', routes: [
      GoRoute(
          path: '/movies/:id',
          builder: (context, _) => Scaffold(
              body: TextButton(
                  onPressed: () => GuestAccess.require(context,
                      title: 'Save Alien for later', intent: 'watchlist'),
                  child: const Text('Add to watchlist')))),
      GoRoute(
          path: '/auth/signup',
          builder: (_, __) => const Scaffold(body: Text('Registration'))),
    ]);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth, child: MaterialApp.router(routerConfig: router)));
    await tester.tap(find.text('Add to watchlist'));
    await tester.pumpAndSettle();
    expect(find.text('Save Alien for later'), findsOneWidget);
    await tester.tap(find.text('Keep exploring'));
    await tester.pumpAndSettle();
    expect(GuestAccess.destination, isNull);
    await tester.tap(find.text('Add to watchlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Registration'), findsOneWidget);
    expect(GuestAccess.destination, '/movies/348');
    expect(GuestAccess.action, 'watchlist');
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    auth.dispose();
  });
}
