import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/router/router.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'watch_invite_startup_test.dart' show InviteAuth;
import '../../features/guest/guest_router_test.dart' show GuestReferrals;
import '../../features/movies/movie_detail_action_flow_test.dart'
    show ActionAnalytics;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GuestAccess.clear();
  });
  tearDown(GuestAccess.clear);
  for (final media in ['movies', 'shows']) {
    testWidgets(
        '$media bookmark returns before setup, with terms and profile required',
        (tester) async {
      final auth = InviteAuth()..current = AuthStatus.unauthenticated;
      final analytics = ActionAnalytics();
      final router = buildRouter(auth, analytics, GuestReferrals());
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        context = c;
        return const SizedBox();
      })));
      Future<Uri> parse(String path) async {
        router.go(path);
        return (await router.routeInformationParser
                .parseRouteInformationWithDependencies(
                    router.routeInformationProvider.value, context))
            .uri;
      }

      await parse('/auth/signup');
      GuestAccess.destination = '/$media/348';
      GuestAccess.action = 'watchlist';
      GuestAccess.bookmarkTitle = 'Alien';
      GuestAccess.awaitingAccount = true;
      auth.current = AuthStatus.authenticated;
      auth.profileNeeded = true;
      expect((await parse('/')).path, '/auth/signup');
      auth.profileNeeded = false;
      auth.acceptedTerms = false;
      expect((await parse('/')).path, '/terms-required');
      auth.acceptedTerms = true;
      expect((await parse('/')).path, '/signup-journey');
      expect(auth.dbUser!.completedSetup, isFalse);
      expect(GuestAccess.journey!.userId, auth.dbUser!.id);
      expect(GuestAccess.journey!.path, '/$media/348');
      expect(GuestAccess.journey!.action, 'watchlist');
      expect((await parse('/signup-journey')).path, '/signup-journey');
      // Until the explicit save and finish, unrelated routes stay in this journey.
      expect((await parse('/watchlist')).path, '/signup-journey');
      expect(
          (await parse('/${media == 'movies' ? 'shows' : 'movies'}/348')).path,
          '/signup-journey');
      auth.current = AuthStatus.unauthenticated;
      expect((await parse('/')).path, '/');
      expect(GuestAccess.journey, isNull);
      expect(GuestAccess.bookmarkSetupPath, isNull);
      expect(GuestAccess.pendingBookmarkPath, isNull);
      auth.current = AuthStatus.authenticated;
      expect((await parse('/$media/348')).path, '/onboarding');
      router.dispose();
      auth.dispose();
      analytics.dispose();
    });
  }
  for (final setup in [false, true]) {
    testWidgets(
        'guest collection merge resumes for ${setup ? 'existing' : 'new'} account',
        (tester) async {
      final auth = InviteAuth()
        ..current = AuthStatus.unauthenticated
        ..setup = setup;
      final analytics = ActionAnalytics();
      final router = buildRouter(auth, analytics, GuestReferrals());
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        context = c;
        return const SizedBox();
      })));
      Future<String> parse(String path) async {
        router.go(path);
        return (await router.routeInformationParser
                .parseRouteInformationWithDependencies(
                    router.routeInformationProvider.value, context))
            .uri
            .path;
      }

      expect(await parse('/guest-watchlist'), '/guest-watchlist');
      GuestAccess.action = 'guest-watchlist';
      GuestAccess.destination = '/guest-watchlist';
      GuestAccess.awaitingAccount = true;
      await parse('/auth/signup');
      auth.current = AuthStatus.authenticated;
      expect(await parse('/auth/signup'), '/signup-journey');
      expect(GuestAccess.journey!.userId, 'fixture');
      expect(await parse('/watchlist'), '/signup-journey');
      router.dispose();
      auth.dispose();
      analytics.dispose();
    });
  }
}
