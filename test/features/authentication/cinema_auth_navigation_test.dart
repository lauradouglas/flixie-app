import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/guest/presentation/guest_home_screen.dart';
import 'package:flixie_app/features/authentication/presentation/cinema_auth_page.dart';
import 'package:flixie_app/features/authentication/presentation/widgets/cinema_auth_scaffold.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
        'iOS auth edge swipe returns to welcome, reduced motion $reduced',
        (tester) async {
      final router = GoRouter(initialLocation: '/welcome', routes: [
        GoRoute(
            path: '/welcome', builder: (_, __) => const GuestWelcomeScreen()),
        GoRoute(
            path: '/auth/login',
            pageBuilder: (context, state) => CinemaAuthPage(
                  key: state.pageKey,
                  child: CinemaAuthScaffold(
                      heading: 'Welcome back',
                      subtitle: 'Sign in to continue.',
                      onBack: () => context.pop(),
                      form: const TextField()),
                )),
      ]);
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(platform: TargetPlatform.iOS),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!),
      ));
      await tester.ensureVisible(find.text('Already a member? Sign in'));
      await tester.tap(find.text('Already a member? Sign in'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(CinemaAuthScaffold));
      final route = ModalRoute.of(context)!;
      expect(route, isA<CupertinoPageRoute<void>>());
      expect(
          route.transitionDuration, Duration(milliseconds: reduced ? 0 : 360));
      await tester.timedDragFrom(const Offset(5, 250), const Offset(600, 0),
          const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Explore Flixie'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
  }
  testWidgets('cancelled edge swipe keeps the form and its draft',
      (tester) async {
    final controller = TextEditingController(text: 'AlienFan');
    final router = GoRouter(initialLocation: '/welcome', routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const GuestWelcomeScreen()),
      GoRoute(
          path: '/auth/login',
          pageBuilder: (context, state) => CinemaAuthPage(
                key: state.pageKey,
                child: CinemaAuthScaffold(
                    heading: 'Welcome back',
                    subtitle: 'Sign in to continue.',
                    onBack: () => context.pop(),
                    form: TextField(controller: controller)),
              )),
    ]);
    await tester.pumpWidget(MaterialApp.router(
        routerConfig: router, theme: ThemeData(platform: TargetPlatform.iOS)));
    await tester.ensureVisible(find.text('Already a member? Sign in'));
    await tester.tap(find.text('Already a member? Sign in'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(5, 250));
    await gesture.moveBy(const Offset(35, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-25, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(controller.text, 'AlienFan');
    expect(router.canPop(), isTrue);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    controller.dispose();
  });
}
