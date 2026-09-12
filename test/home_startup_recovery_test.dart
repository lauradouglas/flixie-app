import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/auth_service.dart';
import 'package:flixie_app/core/storage/movie_cache_service.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/home/presentation/pages/home_screen.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'auth_recovery_test.dart' show Identity, Firebase, profile;
import 'package:firebase_auth/firebase_auth.dart' as fb;

class Session extends AuthService {
  Session() : super(firebaseAuth: Firebase());
  final events = StreamController<fb.User?>.broadcast(sync: true);
  final identity = Identity('home-startup-fixture');
  @override
  Stream<fb.User?> get authStateChanges => events.stream;
  @override
  fb.User? get currentUser => identity;
}

void main() {
  testWidgets(
      'Home gates on trending, secondary failure retains content and manual retry recovers',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    MovieCacheService().clearCache();
    final session = Session();
    final auth = AuthProvider(session, MovieService(),
        prefetchAfterAuth: false, profileLoader: (id) async => profile(id));
    final cache = WatchRequestCache();
    final trending = Completer<http.Response>();
    final recommendations = Completer<http.Response>();
    var recommendationCalls = 0;
    http.Response response(Object data, [int status = 200]) =>
        http.Response(jsonEncode(data), status,
            headers: {'content-type': 'application/json'});
    await http.runWithClient(() async {
      session.events.add(session.identity);
      await tester.pump();
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<WatchRequestCache>.value(value: cache)
      ], child: const MaterialApp(home: HomeScreen())));
      await tester.pump();
      expect(find.text('Trending now'), findsNothing);
      expect(recommendationCalls, 0,
          reason:
              'secondary HTTP is deferred until essential content is ready');
      trending.complete(response([
        {'id': 123, 'title': 'Useful fixture', 'popularity': 10}
      ]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Trending now'), findsOneWidget);
      expect(recommendationCalls, 1);
      recommendations.complete(response({'error': 'offline'}, 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Some Home sections couldn’t refresh.'), findsOneWidget);
      expect(find.text('Trending now'), findsOneWidget);
      // Use Home's refresh action; the profile remains available throughout.
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await refresh;
      expect(recommendationCalls, 2);
      expect(find.text('Some Home sections couldn’t refresh.'), findsNothing);
      expect(find.text('Trending now'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      cache.dispose();
      await session.events.close();
      await tester.pump();
    },
        () => MockClient((request) async {
              final path = request.url.path;
              if (path.contains('/trending/')) {
                if (!trending.isCompleted) return await trending.future;
                return response([
                  {'id': 123, 'title': 'Useful fixture'}
                ]);
              }
              if (path.endsWith('/recommendations')) {
                recommendationCalls++;
                return recommendationCalls == 1
                    ? await recommendations.future
                    : response([]);
              }
              if (path == '/groups/home/watch-plans') {
                return response({'groups': []});
              }
              return response([]);
            }));
  });
}
