import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/router/router.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/models/user.dart';
import '../../features/guest/guest_router_test.dart'
    show GuestAuth, GuestReferrals;
import '../../features/movies/movie_detail_action_flow_test.dart'
    show ActionAnalytics;

class StartupAuth extends GuestAuth {
  AuthStatus current = AuthStatus.unknown;
  bool acceptedTerms = true;
  bool cachedProfile = false;
  @override
  AuthStatus get status => current;
  @override
  bool get termsVerified => acceptedTerms;
  @override
  User? get dbUser => cachedProfile || current == AuthStatus.authenticated
      ? const User(
          id: 'fictional-viewer',
          username: 'MovieFan',
          email: 'fixture@example.invalid',
          iconColorId: 1,
          completedSetup: true,
          darkMode: true)
      : null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GuestAccess.clear();
  });
  for (final type in ['movies', 'shows']) {
    testWidgets('signed-out HTTPS $type launch retains the public title', (tester) async {
      final auth = StartupAuth();
      final analytics = ActionAnalytics();
      final router = buildRouter(auth, analytics, GuestReferrals());
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        context = c;
        return const SizedBox();
      })));
      Future<Uri> parse(String path) async {
        router.go(path);
        final match = await router.routeInformationParser
            .parseRouteInformationWithDependencies(
                router.routeInformationProvider.value, context);
        return match.uri;
      }
      expect((await parse('https://www.flixie.co.uk/$type/348?source=shared_link')).path,
          '/splash');
      auth.current = AuthStatus.unauthenticated;
      final destination = await parse('/splash');
      expect(destination.path, '/$type/348');
      expect(destination.queryParameters['source'], 'shared_link');
      router.dispose();
      auth.dispose();
      analytics.dispose();
    });
  }
  for (final type in ['movies', 'shows']) {
    for (final absolute in [false, true]) {
      for (final cached in [false, true]) {
        testWidgets(
            'cold $type link absolute=$absolute cached=$cached survives auth',
            (tester) async {
          final auth = StartupAuth()..cachedProfile = cached;
          final analytics = ActionAnalytics();
          final router = buildRouter(auth, analytics, GuestReferrals());
          late BuildContext context;
          await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
            context = c;
            return const SizedBox();
          })));
          Future<Uri> parse(String path) async {
            router.go(path);
            final match = await router.routeInformationParser
                .parseRouteInformationWithDependencies(
                    router.routeInformationProvider.value, context);
            return match.uri;
          }

          final path = '/$type/348?source=shared_link';
          expect(
              (await parse(absolute ? 'https://www.flixie.co.uk$path' : path))
                  .path,
              '/splash');
          auth.current = AuthStatus.authenticated;
          final destination = await parse('/splash');
          expect(destination.path, '/$type/348');
          expect(destination.queryParameters['source'], 'shared_link');
          // Startup intent is consumed, never replayed on a later auth page.
          expect((await parse('/auth/login')).path, '/');
          router.dispose();
          auth.dispose();
          analytics.dispose();
        });
      }
    }
  }
}
