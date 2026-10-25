import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/taste/presentation/pages/build_taste_page.dart';
import 'package:flixie_app/features/taste/presentation/widgets/taste_home_card.dart';
import 'package:flixie_app/features/taste/data/taste_setup_store.dart';
import '../../../authentication/signup_journey_test.dart' show JourneyAuth;
import '../controllers/taste_controller_test.dart' show TasteFixture;

class TasteAuth extends JourneyAuth {
  int version = 0;
  @override
  int get activityVersion => version;
  @override
  void markActivityChanged() {
    version++;
    notifyListeners();
  }
}

Future<GoRouter> mount(
    WidgetTester tester, TasteFixture service, JourneyAuth auth) async {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => BuildTastePage(service: service))
  ]);
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth, child: MaterialApp.router(routerConfig: router)));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final systemBack in [false, true]) {
    testWidgets('taste exit returns to profile, system back: $systemBack',
        (tester) async {
      final router = GoRouter(initialLocation: '/profile', routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('Home fixture'))),
        GoRoute(path: '/profile', builder: (context, _) => Scaffold(
          body: TextButton(onPressed: () => context.push('/build-your-taste'),
              child: const Text('Refine your taste')))),
        GoRoute(path: '/build-your-taste',
            builder: (_, __) => BuildTastePage(service: TasteFixture())),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: JourneyAuth(), child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refine your taste'));
      await tester.pumpAndSettle();
      expect(find.byType(BuildTastePage), findsOneWidget);
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byTooltip('Close taste setup'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Refine your taste'), findsOneWidget);
      expect(find.byType(BuildTastePage), findsNothing);
      expect(find.text('Home fixture'), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/profile');
    });
  }
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 768)
  ]) {
    testWidgets('taste selection/rating reflows at $size with larger text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final service = TasteFixture();
      final router = await mount(tester, service, JourneyAuth());
      await tester.ensureVisible(find.byTooltip('Add Alien to favourites'));
      await tester.tap(find.byTooltip('Add Alien to favourites'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove Alien from favourites'), findsOneWidget);
      await tester
          .ensureVisible(find.byTooltip('Remove Alien from favourites'));
      await tester.tap(find.byTooltip('Remove Alien from favourites'));
      await tester.pumpAndSettle();
      expect(service.saved, isEmpty);
      await tester.ensureVisible(find.text('Continue to ratings'));
      await tester.tap(find.text('Continue to ratings'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Seen it? Give us your take.')).dy,
          greaterThanOrEqualTo(0));
      await tester.ensureVisible(find.byTooltip('Rate Alien'));
      await tester.tap(find.byTooltip('Rate Alien'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FlixiePill, '8'));
      await tester.tap(find.widgetWithText(FlixiePill, '8'));
      await tester.ensureVisible(find.text('Save rating'));
      await tester.tap(find.text('Save rating'));
      await tester.pumpAndSettle();
      expect(find.text('A little more you.'), findsOneWidget);
      expect(find.text('Your streaming services'), findsOneWidget);
      expect(find.text('Add or edit watch providers'), findsOneWidget);
      expect(service.calls, contains('fixture:348:8:avoid'));
      expect(tester.takeException(), isNull);
      router.dispose();
    });
  }
  testWidgets(
      'Home card requires a saved action and respects account-scoped dismissal',
      (tester) async {
    final auth = TasteAuth();
    auth.account = auth.account!.copyWith(completedSetup: true);
    Future<void> show() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(home: Scaffold(body: TasteHomeCard()))));
      await tester.pumpAndSettle();
    }

    await show();
    expect(find.text('Build my taste'), findsNothing);
    await const TasteSetupStore().enable('fixture');
    await tester.pumpAndSettle();
    expect(find.text('Build my taste'), findsOneWidget);
    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();
    expect(find.text('Build my taste'), findsNothing);
    expect(await const TasteSetupStore().hidden('fixture'), true);
  });
  testWidgets('Home invitation opens the same optional native taste flow',
      (tester) async {
    final auth = TasteAuth();
    auth.account = auth.account!.copyWith(completedSetup: true);
    await const TasteSetupStore().enable('fixture');
    final router = GoRouter(routes: [
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: TasteHomeCard())),
      GoRoute(
          path: '/build-your-taste',
          builder: (_, __) => BuildTastePage(service: TasteFixture())),
    ]);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth, child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Build my taste'));
    await tester.pumpAndSettle();
    expect(find.text('Which films are your favourites?'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    router.dispose();
  });
}
