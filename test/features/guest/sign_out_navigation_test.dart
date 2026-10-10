import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/router/router.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/settings/presentation/widgets/logout_sheet.dart';
import 'guest_router_test.dart';
import '../movies/movie_detail_action_flow_test.dart' show ActionAnalytics;

class SigningOutAuth extends GuestAuth {
  AuthStatus currentStatus = AuthStatus.authenticated;
  @override
  AuthStatus get status => currentStatus;
  @override
  bool get termsVerified => true;
  @override
  User? get dbUser => currentStatus == AuthStatus.authenticated
      ? const User(
          id: 'fixture',
          username: 'AlienFan',
          email: 'fixture@example.com',
          iconColorId: 1,
          completedSetup: true,
          darkMode: true)
      : null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'real router sends a signed-out Settings session to Home and clears intent',
      (tester) async {
    final auth = SigningOutAuth();
    final analytics = ActionAnalytics();
    final router = buildRouter(auth, analytics, GuestReferrals());
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      context = c;
      return const SizedBox();
    })));
    router.go('/settings');
    final signedIn = await router.routeInformationParser
        .parseRouteInformationWithDependencies(
            router.routeInformationProvider.value, context);
    expect(signedIn.uri.path, '/settings');
    GuestAccess.destination = '/watchlist';
    GuestAccess.awaitingAccount = true;
    auth.currentStatus = AuthStatus.unauthenticated;
    router.go('/settings');
    final signedOut = await router.routeInformationParser
        .parseRouteInformationWithDependencies(
            router.routeInformationProvider.value, context);
    expect(signedOut.uri.path, '/');
    expect(GuestAccess.destination, isNull);
    expect(GuestAccess.awaitingAccount, isFalse);
    router.go('/settings');
    final privateLink = await router.routeInformationParser
        .parseRouteInformationWithDependencies(
            router.routeInformationProvider.value, context);
    expect(privateLink.uri.path, '/auth/signup');
    router.dispose();
    auth.dispose();
    analytics.dispose();
    GuestAccess.clear();
  });

  testWidgets('logout confirmation returns Home after successful sign out',
      (tester) async {
    var calls = 0;
    final router = GoRouter(initialLocation: '/settings', routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Guest Home'))),
      GoRoute(
          path: '/settings',
          builder: (context, _) => Scaffold(
              body: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      useRootNavigator: true,
                      useSafeArea: true,
                      builder: (_) => LogoutSheet(onSignOut: () async {
                            calls++;
                          })),
                  child: const Text('Open logout')))),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Log Out'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Guest Home'), findsOneWidget);
    expect(router.canPop(), isFalse);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}
