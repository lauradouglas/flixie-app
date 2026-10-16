import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/router/router.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/pending_watch_invite_store.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/models/user.dart';
import 'shared_link_startup_test.dart' show StartupAuth;
import '../../features/guest/guest_router_test.dart' show GuestReferrals;
import '../../features/movies/movie_detail_action_flow_test.dart'
    show ActionAnalytics;

class InviteAuth extends StartupAuth {
  bool setup = false;
  bool profileNeeded = false;
  @override
  bool get needsSocialProfile => profileNeeded;
  @override
  User? get dbUser => current == AuthStatus.authenticated
      ? User(
          id: 'fixture',
          username: 'NewMember',
          email: 'new@example.invalid',
          iconColorId: 1,
          completedSetup: setup,
          darkMode: true)
      : null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GuestAccess.clear();
  });
  testWidgets(
      'watch invite survives signup and opens its viewing before optional onboarding',
      (tester) async {
    final token = 'a' * 43;
    final auth = InviteAuth();
    final analytics = ActionAnalytics();
    var router = buildRouter(auth, analytics, GuestReferrals());
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

    expect((await parse('https://www.flixie.co.uk/invite?watch=$token')).path,
        '/splash');
    auth.current = AuthStatus.unauthenticated;
    expect((await parse('/splash')).path, '/watch-invites/$token');
    expect(await PendingWatchInviteStore.read(), token);
    auth.current = AuthStatus.authenticated;
    auth.profileNeeded = true;
    expect((await parse('/auth/signup')).path, '/auth/signup');
    expect(await PendingWatchInviteStore.read(), token);
    auth.profileNeeded = false;
    expect((await parse('/auth/signup')).path, '/watch-invites/$token');
    expect(auth.dbUser!.completedSetup, isFalse);
    auth.acceptedTerms = false;
    expect((await parse('/watch-invites/$token')).path, '/terms-required');
    auth.acceptedTerms = true;
    expect((await parse('/terms-required')).path, '/watch-invites/$token');
    await PendingWatchInviteStore.beginLog('shared-plan', 'fixture');
    expect(await PendingWatchInviteStore.read(), isNull);
    expect(await PendingWatchInviteStore.readLog('another-account'), isNull);
    expect((await parse('/watch-requests/shared-plan?log=true')).path,
        '/watch-requests/shared-plan');
    expect((await parse('/watch-entry-saved/shared-plan')).path,
        '/watch-entry-saved/shared-plan');
    expect((await parse('/watch-requests/unrelated')).path, '/onboarding');
    router.dispose();
    router = buildRouter(auth, analytics, GuestReferrals());
    expect((await parse('/')).path, '/watch-requests/shared-plan');
    await PendingWatchInviteStore.clear();
    GuestAccess.clear();
    expect((await parse('/')).path, '/onboarding');
    router.dispose();
    auth.dispose();
    analytics.dispose();
  });
}
