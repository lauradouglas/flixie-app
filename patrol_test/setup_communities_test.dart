import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/authentication/presentation/pages/onboarding_screen.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import 'package:flixie_app/features/social/data/genre_community_service.dart';
import 'package:flixie_app/features/social/presentation/pages/genre_communities_screen.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import '../test/setup_flow_test.dart' show SetupFixture;
import '../test/support/watchlist_auth.dart';
import '../test/support/api_fixture.dart';

class _Auth extends TestAuth {
  @override
  Future<void> refreshDbUser() async {}
  @override
  Future<bool> completeOnboarding() async => false;
}

class _Setup extends SetupFixture {
  _Setup() {
    browseTitles = [const SetupTitle(348, 'Alien', null)];
  }
  @override
  Future<List<GenreCommunity>> communities() =>
      const GenreCommunityService().list();
  @override
  Future<void> joinCommunity(int id) =>
      const GenreCommunityService().setJoined(id, true);
  @override
  Future<Set<int>> titleCommunityGenres(
          SetupTitle title, List<GenreCommunity> available) async =>
      {27};
}

void main() {
  patrolTest(
      'onboarding explicit join appears in Social after completion and resume',
      ($) async {
    // This is a Patrol test; keep preferences isolated from the simulator account.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    var joined = false;
    var joins = 0;
    useApiFixture(MockClient((request) async {
      if (request.method == 'PUT') {
        expectSync(request.url.path, '/community/genres/27/membership');
        expectSync(jsonDecode(request.body), {'joined': true});
        joined = true;
        joins++;
        return http.Response('{}', 200);
      }
      expectSync(request.url.path, '/community/genres');
      return http.Response(
          jsonEncode({
            'items': [
              {'id': 27, 'name': 'Horror', 'joined': joined}
            ]
          }),
          200,
          headers: {'content-type': 'application/json'});
    }));
    final auth = _Auth();
    addTearDown(auth.dispose);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/', builder: (_, __) => OnboardingScreen(service: _Setup())),
      GoRoute(
          path: '/social',
          builder: (_, state) {
            expectSync(state.uri.queryParameters['tab'], 'communities');
            return const Scaffold(
                appBar: null, body: SafeArea(child: GenreCommunitiesView()));
          }),
    ]);
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<MovieRatingPrivacy>(
              create: (_) => MovieRatingPrivacy(loadRatings: (_) async => {})
                ..syncUser('viewer')),
        ],
        child: MaterialApp.router(
            theme: AppTheme.darkTheme, routerConfig: router)));
    await $(find.byKey(const ValueKey('taste-movie:348'))).tap();
    await $('Continue').tap();
    await $('Skip services for now').tap();
    await $('Find my kind of people').tap();
    await $('Horror').waitUntilVisible();
    expect(joins, 0);
    await $('Horror').tap();
    expect(joins, 0);
    await $('Join 1 & explore').tap();
    await $('✓ Joined').waitUntilVisible();
    expect(joins, 1);
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $('✓ Joined').waitUntilVisible();
  });
}
