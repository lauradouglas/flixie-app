import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/router/router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/models/movie.dart';
import '../test/features/guest/guest_router_test.dart'
    show GuestAuth, GuestReferrals;
import '../test/features/movies/movie_detail_action_flow_test.dart'
    show ActionAnalytics;
import '../test/movie_detail_loading_test.dart' show DelayedMovies;
import '../test/support/api_fixture.dart';

void main() {
  patrolTest(
      'guest browses Home and a film; save prompts without a write; You offers signup',
      ($) async {
    SharedPreferences.setMockInitialValues({'guest_welcome_seen_v1': true});
    final requests = <http.Request>[];
    useApiFixture(MockClient((request) async {
      requests.add(request);
      return http.Response(
          jsonEncode(request.url.path == '/guest/home'
              ? {
                  'activity': [],
                  'communities': [
                    {'id': 27, 'name': 'Horror'}
                  ]
                }
              : [
                  {'id': 348, 'title': 'Alien'}
                ]),
          200);
    }));
    final auth = GuestAuth(), analytics = ActionAnalytics();
    final movies = DelayedMovies();
    movies.providers.complete([]);
    movies.reviews.complete([]);
    final router = buildRouter(auth, analytics, GuestReferrals());
    addTearDown(() {
      router.dispose();
      auth.dispose();
      analytics.dispose();
    });
    await $.pumpWidgetAndSettle(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<AnalyticsController>.value(value: analytics),
          Provider<MovieService>.value(value: movies),
        ],
        child: MaterialApp.router(
            routerConfig: router, theme: AppTheme.darkTheme)));
    await $('Alien').tap();
    movies.core[348]!.complete(const Movie(
        id: 348,
        title: 'Alien',
        overview: 'A spacecraft crew answers a distress call.',
        runtime: 117));
    await $.pumpAndSettle();
    await $('Watchlist').scrollTo().tap();
    await $('Save this film for later').waitUntilVisible();
    await $('Keep exploring').tap();
    expect(requests.where((r) => r.method != 'GET'), isEmpty);
    expect(movies.reviewCalls, 0);
    router.pop();
    await $.pumpAndSettle();
    await $('You').tap();
    await $('Create account').waitUntilVisible();
    expect(find.text('Create your account'), findsOneWidget);
    expect($.tester.takeException(), isNull);
  });
}
