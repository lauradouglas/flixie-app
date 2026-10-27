import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/watchlist/presentation/widgets/guest_picks_recovery_button.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/watchlist/data/guest_watchlist_store.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/guest_watchlist_page.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 844.0, 1024.0]) {
    testWidgets(
        'guest collection shows title, type, poster and safe removal at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await GuestWatchlistStore.instance
          .toggle(const SetupTitle(348, 'Alien', '/alien.jpg'));
      await tester.pumpWidget(const MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: GuestWatchlistPage())));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text('Create account & keep my picks'), 160);
      expect(find.text('Create account & keep my picks'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Alien'), 160);
      expect(find.text('Alien'), findsOneWidget);
      expect(find.text('Film'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byTooltip('Remove Alien').hitTestable(), 160);
      await tester.tap(find.byTooltip('Remove Alien'));
      await tester.pumpAndSettle();
      expect(await GuestWatchlistStore.instance.read(), isEmpty);
      expect(find.text('What’s on your someday list?'), findsOneWidget);
      expect(find.text('Create account & keep my picks'), findsNothing);
    });
  }
  testWidgets('find more switches to Discover without stacking the guest page',
      (tester) async {
    await GuestWatchlistStore.instance
        .toggle(const SetupTitle(348, 'Alien', null));
    final router = GoRouter(initialLocation: '/guest-watchlist', routes: [
      GoRoute(
          path: '/guest-watchlist',
          builder: (_, __) => const GuestWatchlistPage()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => Scaffold(body: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const Text('Guest Home')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/search',
                builder: (_, __) => const Center(child: Text('Discover films'))),
          ]),
        ],
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Find more to watch'), 200);
    await tester.tap(find.text('Find more to watch'));
    await tester.pumpAndSettle();
    expect(find.text('Discover films'), findsOneWidget);
    expect(find.byType(GuestWatchlistPage), findsNothing);
    expect(router.canPop(), isFalse);
    expect(await GuestWatchlistStore.instance.read(), hasLength(1));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'unmerged picks can be recovered explicitly from the member watchlist',
      (tester) async {
    await GuestWatchlistStore.instance
        .toggle(const SetupTitle(348, 'Alien', null));
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: GuestPicksRecoveryButton())),
      GoRoute(
          path: '/signup-journey',
          builder: (_, __) => const Scaffold(body: Text('Resume saving'))),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep 1 pick from this device'));
    await tester.pumpAndSettle();
    expect(find.text('Resume saving'), findsOneWidget);
    expect(GuestAccess.action, 'guest-watchlist');
    expect(GuestAccess.awaitingAccount, true);
    expect(await GuestWatchlistStore.instance.read(), hasLength(1));
    GuestAccess.clear();
    router.dispose();
  });
}
