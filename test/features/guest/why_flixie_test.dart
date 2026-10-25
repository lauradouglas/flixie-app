import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/guest/presentation/guest_home_screen.dart';
import 'package:flixie_app/features/guest/presentation/pages/why_flixie_screen.dart';
import 'package:flixie_app/features/guest/presentation/widgets/guest_home_welcome.dart';
import 'package:flixie_app/features/guest/presentation/widgets/why_flixie_button.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_badges.dart';

GoRouter _router(String initialLocation) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
                body: SingleChildScrollView(child: GuestHomeWelcome()))),
        GoRoute(
            path: '/welcome', builder: (_, __) => const GuestWelcomeScreen()),
        GoRoute(
            path: '/profile',
            builder: (_, __) => const GuestWelcomeScreen(you: true)),
        GoRoute(
            path: '/why-flixie', builder: (_, __) => const WhyFlixieScreen()),
        GoRoute(
            path: '/auth/signup',
            builder: (_, __) =>
                const Scaffold(body: Text('Signup destination'))),
      ],
    );

Future<void> _mount(WidgetTester tester, GoRouter router,
    {double scale = 1}) async {
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(
    theme: AppTheme.darkTheme,
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data:
          MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  setUp(GuestAccess.clear);
  test('the tour is a public path without opening other private routes', () {
    expect(GuestAccess.isPublicPath('/why-flixie'), isTrue);
    expect(GuestAccess.isPublicPath('/why-flixie/private'), isFalse);
    expect(GuestAccess.isPublicPath('/watchlist'), isFalse);
  });

  for (final path in ['/welcome', '/', '/profile']) {
    testWidgets('$path offers tour only after an explicit tap; system Back returns',
        (tester) async {
      final router = _router(path);
      GuestAccess.destination = '/movies/348';
      GuestAccess.action = 'watchlist';
      await _mount(tester, router);
      expect(find.byType(WhyFlixieScreen), findsNothing);
      await _tap(tester, WhyFlixieButton.label);
      expect(
          GoRouterState.of(tester.element(find.byType(WhyFlixieScreen)))
              .uri
              .path,
          '/why-flixie');
      expect(find.text('Films are better\nwith your people.'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(find.byType(WhyFlixieButton), findsOneWidget);
      expect(GuestAccess.destination, '/movies/348');
      expect(GuestAccess.action, 'watchlist');
    });
  }

  testWidgets('story demos keep independent watch ratings and TV progress',
      (tester) async {
    final router = _router('/why-flixie');
    await _mount(tester, router);
    await _tap(tester, 'Show me around');
    final avatars = tester
        .widgetList<ProfileAvatarView>(find.byType(ProfileAvatarView))
        .toList();
    expect(avatars, hasLength(2));
    expect(avatars[0].profileBadges, ['EARLY_ADOPTER']);
    expect(avatars[1].profileBadges, ['FOUNDING_FILM_FRIEND']);
    expect(
        avatars.every((avatar) => avatar.imageProvider is AssetImage), isTrue);
    expect(find.byType(SpecialAvatarFrame), findsNWidgets(2));
    await _tap(tester, 'Add Alien to your watchlist');
    expect(find.text('On your watchlist too'), findsOneWidget);
    await _tap(tester, 'Next');
    await _tap(tester, 'Disney+');
    expect(find.text('Alien\nDisney+ · Included with subscription'),
        findsOneWidget);
    await _tap(tester, 'Netflix');
    expect(find.text('No saved films match this service in this example.'),
        findsOneWidget);
    await _tap(tester, 'Disney+');
    await _tap(tester, 'Next');
    await _tap(tester, 'Preview the watch plan');
    expect(find.textContaining('You + Robin · Film night planned.'),
        findsOneWidget);
    await _tap(tester, 'Next');
    await _tap(tester, '8');
    expect(find.text('Your film-night rating: 8/10'), findsOneWidget);
    expect(find.text('Robin’s rating: 7/10'), findsOneWidget);
    await _tap(tester, 'See a separate rewatch entry');
    expect(find.textContaining('First-watch rating: 8/10.'), findsOneWidget);
    await _tap(tester, '9');
    expect(find.text('Your rewatch rating: 9/10'), findsOneWidget);
    await _tap(tester, 'Back to the first watch');
    expect(find.text('Your film-night rating: 8/10'), findsOneWidget);
    await _tap(tester, 'Next');
    await _tap(tester, 'Poll');
    expect(
        find.textContaining('Alien · The Thing · The Descent'), findsOneWidget);
    await _tap(tester, 'Discover');
    expect(find.textContaining('Explore films rated by community members'),
        findsOneWidget);
    await _tap(tester, 'Next');
    await _tap(tester, 'Mark episode 4 watched');
    expect(find.text('Season 1 · Episode 5 is up next'), findsOneWidget);
    await _tap(tester, 'Back');
    await _tap(tester, 'Next');
    expect(find.text('Season 1 · Episode 5 is up next'), findsOneWidget);
    await _tap(tester, 'Undo example watch');
    expect(find.text('Season 1 · Episode 4 is up next'), findsOneWidget);
    await _tap(tester, 'Next');
    await _tap(tester, 'Finish tour');
    expect(find.text('Find a film.\nBring your people.'), findsOneWidget);
    await _tap(tester, 'Create account');
    expect(find.text('Signup destination'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Find a film.\nBring your people.'), findsOneWidget);
    await _tap(tester, 'Explore Flixie');
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(GuestAccess.destination, isNull);
  });

  testWidgets(
      'Explore and Skip exit the tour without app navigation chrome',
      (tester) async {
    final router = _router('/why-flixie');
    await _mount(tester, router);
    expect(find.byType(AppBar), findsNothing);
    await _tap(tester, 'Explore Flixie instead');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    router.go('/why-flixie');
    await tester.pumpAndSettle();
    await _tap(tester, 'Show me around');
    await _tap(tester, 'Skip tour & explore');
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(GuestAccess.awaitingAccount, isFalse);
  });

  for (final (size, scale) in [
    (const Size(320, 568), 2.0),
    (const Size(844, 390), 2.0),
    (const Size(430, 932), 1.0),
    (const Size(1024, 768), 2.0),
  ]) {
    testWidgets('all tour steps fit $size at text scale $scale',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = _router('/why-flixie');
      await _mount(tester, router, scale: scale);
      await _tap(tester, 'Show me around');
      for (var step = 1; step <= 7; step++) {
        expect(find.text('$step of 7'), findsOneWidget);
        await tester
            .ensureVisible(find.text('Example preview · fictional activity'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Story step $step');
        await _tap(tester, step == 7 ? 'Finish tour' : 'Next');
      }
      expect(tester.takeException(), isNull);
      await _tap(tester, 'Explore Flixie');
      expect(router.routeInformationProvider.value.uri.path, '/');
    });
  }
}
