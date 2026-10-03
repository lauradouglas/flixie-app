import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/home/data/recommendation_service.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/home/presentation/pages/home_screen.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'home_startup_recovery_test.dart' show Session;
import 'auth_recovery_test.dart' show profile;

void main() {
  testWidgets(
      'saved viewing activity automatically regenerates Home recommendations',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    RecommendationService.invalidateCache();
    final session = Session();
    final auth = AuthProvider(session, MovieService(),
        prefetchAfterAuth: false, profileLoader: (id) async => profile(id));
    final cache = WatchRequestCache();
    final requests = <Map<String, String>>[];
    http.Response response(Object value) =>
        http.Response(jsonEncode(value), 200,
            headers: {'content-type': 'application/json'});
    ApiClient.useClientForTesting(MockClient((request) async {
      if (request.url.path.endsWith('/recommendations')) {
        requests.add(request.url.queryParameters);
      }
      if (request.url.path == '/community/activity') {
        return response({'items': [], 'nextCursor': null});
      }
      if (request.url.path == '/groups/home/watch-plans') {
        return response({'groups': []});
      }
      return response([]);
    }));
    addTearDown(() {
      ApiClient.useClientForTesting(null);
      RecommendationService.invalidateCache();
    });
    session.events.add(session.identity);
    await tester.pump();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<WatchRequestCache>.value(value: cache),
    ], child: const MaterialApp(home: HomeScreen())));
    await tester.pumpAndSettle();
    expect(requests, [<String, String>{}]);
    // The saved-watch flow emits this activity change after persistence succeeds.
    auth.markActivityChanged();
    await tester.pumpAndSettle();
    expect(requests, [
      <String, String>{},
      {'refresh': 'true', 'refreshProfile': 'false'}
    ]);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    cache.dispose();
    await session.events.close();
  });
}
