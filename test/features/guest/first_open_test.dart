import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/router/router.dart';
import 'package:flixie_app/features/guest/data/first_open_store.dart';
import 'package:flixie_app/features/guest/presentation/guest_home_screen.dart';
import 'guest_router_test.dart';
import '../movies/movie_detail_action_flow_test.dart' show ActionAnalytics;

void main() {
  for (final (label, destination) in [
    ('Already a member? Sign in', '/auth/login'),
    ('Create account', '/auth/signup'),
  ]) {
    testWidgets('$label preserves welcome beneath auth and Back returns to it', (tester) async {
      final router = GoRouter(initialLocation: '/welcome', routes: [
        GoRoute(path: '/welcome', builder: (_, __) => const GuestWelcomeScreen()),
        GoRoute(path: destination, builder: (context, _) => Scaffold(
          appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
          body: const Text('Authentication'),
        )),
      ]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('Authentication'), findsOneWidget);
      expect(router.canPop(), isTrue);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Explore Flixie'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/welcome');
      await tester.pumpWidget(const SizedBox()); router.dispose();
    });
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('first launch welcomes once; a fresh router opens Home next time',
      (tester) async {
    final auth = GuestAuth(), analytics = ActionAnalytics();
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      context = c;
      return const SizedBox();
    })));
    for (final expected in ['/welcome', '/']) {
      final router = buildRouter(auth, analytics, GuestReferrals());
      router.go('/');
      final match = await router.routeInformationParser
          .parseRouteInformationWithDependencies(
              router.routeInformationProvider.value, context);
      expect(match.uri.path, expected);
      router.dispose();
    }
    expect(
        (await SharedPreferences.getInstance())
            .getBool(FirstOpenStore.welcomeSeenKey),
        isTrue);
    auth.dispose();
    analytics.dispose();
  });
  testWidgets('fresh-install movie deep link bypasses welcome', (tester) async {
    final auth = GuestAuth(), analytics = ActionAnalytics();
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      context = c;
      return const SizedBox();
    })));
    final router = buildRouter(auth, analytics, GuestReferrals());
    router.go('/movies/348');
    final match = await router.routeInformationParser
        .parseRouteInformationWithDependencies(
            router.routeInformationProvider.value, context);
    expect(match.uri.path, '/movies/348');
    router.dispose();
    auth.dispose();
    analytics.dispose();
  });
  for (final size in const [
    Size(320, 568),
    Size(844, 390),
    Size(1024, 768)
  ]) {
    testWidgets('welcome actions remain reachable at $size with doubled text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: GuestWelcomeScreen(),
      )));
      await tester.ensureVisible(find.text('Already a member? Sign in'));
      await tester.pump();
      expect(find.text('Explore Flixie'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
