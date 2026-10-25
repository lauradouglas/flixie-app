import 'package:flixie_app/features/home/data/recommendation_service.dart';
import 'package:flixie_app/features/home/data/trending_service.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'dart:async';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/widgets/pip_startup_brand.dart';
import 'package:flixie_app/features/home/presentation/widgets/trending_carousel.dart';
import 'package:flixie_app/models/user.dart';
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
import 'auth_recovery_test.dart'
    show Identity, Firebase, profile, libraryProfile;
import 'package:firebase_auth/firebase_auth.dart' as fb;

class Session extends AuthService {
  Session() : super(firebaseAuth: Firebase());
  final events = StreamController<fb.User?>.broadcast(sync: true);
  var identity = Identity('home-startup-fixture');
  @override
  Stream<fb.User?> get authStateChanges => events.stream;
  @override
  fb.User? get currentUser => identity;
}

void main() {
  setUp(() {
    TrendingService.clearSessionCacheForTesting();
    RecommendationService.invalidateCache();
  });
  testWidgets('real Home reveals before the full library request completes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    MovieCacheService().clearCache();
    HomeScreen.clearSessionSnapshotForTesting();
    final session = Session();
    final library = Completer<User>();
    var fullReads = 0;
    final opening = Completer<http.Response>();
    final paths = <String>[];
    final auth = AuthProvider(session, MovieService(),
        prefetchAfterAuth: false,
        startupProfileLoader: (id) async => profile(id),
        profileLoader: (_) {
          fullReads++;
          return library.future;
        },
        termsStatusLoader: () async => true);
    final cache = WatchRequestCache();
    final client = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.contains('/trending/')) return opening.future;
      return http.Response(
          jsonEncode(request.url.path == '/groups/home/watch-plans'
              ? {'groups': []}
              : request.url.path == '/community/activity'
                  ? {'items': [], 'nextCursor': null}
                  : []),
          200);
    });
    ApiClient.useClientForTesting(client);
    addTearDown(() {
      ApiClient.useClientForTesting(null);
      client.close();
    });
    session.events.add(session.identity);
    await tester.pump();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<WatchRequestCache>.value(value: cache)
    ], child: const MaterialApp(home: HomeScreen())));
    await tester.pump();
    expect(find.byType(PipStartupBrand), findsOneWidget);
    expect(fullReads, 0);
    expect(
        paths.where((path) =>
            path.contains('/now_playing') ||
            path.startsWith('/community/') ||
            path.contains('/interactions/')),
        isEmpty);
    opening.complete(http.Response(
        jsonEncode([
          {'id': 348, 'title': 'Alien', 'mediaType': 'MOVIE'}
        ]),
        200));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(PipStartupBrand), findsNothing);
    expect(find.text('Trending now'), findsOneWidget);
    expect(
        tester
            .widget<TrendingCarousel>(find.byType(TrendingCarousel))
            .movies
            .single
            .name,
        'Alien');
    expect(fullReads, 1);
    expect(library.isCompleted, false);
    expect(auth.libraryReady, false);
    library.complete(libraryProfile(session.identity.uid));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(auth.libraryReady, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    cache.dispose();
    await session.events.close();
  });

  testWidgets(
      'Home is usable before trending, secondary failure retains content and manual retry recovers',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    MovieCacheService().clearCache();
    HomeScreen.clearSessionSnapshotForTesting();
    var profileCalls = 0;
    final profileUsers = <String>[];
    final session = Session();
    final auth = AuthProvider(session, MovieService(),
        prefetchAfterAuth: false,
        profileLoader: (id) async {
          profileCalls++;
          profileUsers.add(id);
          return libraryProfile(id);
        },
        termsStatusLoader: () async => true);
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
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.text('Pick for me'), findsOneWidget);
      expect(recommendationCalls, 0,
          reason: 'secondary HTTP waits until opening content is ready');
      trending.complete(response([
        {
          'id': 123,
          'title': 'Useful fixture',
          'mediaType': 'MOVIE',
          'popularity': 10
        }
      ]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Trending now'), findsOneWidget);
      expect(recommendationCalls, 1);
      expect(find.byType(ActivityRowsSkeleton), findsNothing,
          reason:
              'Completed empty friend activity must not wait for recommendations');
      expect(find.text('Friends watching'), findsNothing);
      expect(find.text('On Your Watchlist'), findsNothing);
      await tester.scrollUntilVisible(find.text('Around Flixie'), 250,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Around Flixie'), findsOneWidget);
      expect(find.text('Friends’ activity'), findsNothing);
      recommendations.complete(response({'error': 'offline'}, 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Some Home sections couldn’t refresh.'), findsOneWidget);
      expect(find.text('Trending now'), findsOneWidget);
      expect(profileCalls, 1);
      // Use Home's refresh action; the profile remains available throughout.
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await refresh;
      expect(recommendationCalls, 2);
      expect(profileCalls, 2, reason: 'manual refresh fetches a new profile');
      expect(find.text('Some Home sections couldn’t refresh.'), findsNothing);
      expect(find.text('Trending now'), findsOneWidget);
      // Resume updates the profile once; Home refreshes sections using that data.
      await auth.handleAppResumed();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(profileCalls, 3,
          reason: 'Home must not refetch the resume profile');
      expect(auth.activityIncludesRefreshedProfile, isTrue);
      expect(find.text('Trending now'), findsOneWidget);
      await auth.handleAppResumed();
      await tester.pump();
      expect(profileCalls, 3, reason: 'quick resume remains throttled');

      final refreshAfterResume = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await refreshAfterResume;
      expect(profileCalls, 4,
          reason: 'manual refresh ignores the resume reuse marker');

      auth.markActivityChanged();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(auth.activityIncludesRefreshedProfile, isFalse);
      expect(profileCalls, 5,
          reason: 'action updates still fetch a new profile');

      session.identity = Identity('other-home-fixture');
      session.events.add(session.identity);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(auth.dbUser?.id, 'other-home-fixture');
      expect(auth.activityIncludesRefreshedProfile, isTrue,
          reason: 'Home reuses the fresh profile belonging to the new account');
      expect(profileCalls, 6,
          reason: 'switch restores the new account profile');
      expect(profileUsers.last, 'other-home-fixture');
      final switchedRefresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await switchedRefresh;
      expect(profileCalls, 7,
          reason: 'the new account can still explicitly refresh its profile');
      expect(profileUsers.sublist(5),
          ['other-home-fixture', 'other-home-fixture']);
      expect(auth.dbUser?.id, 'other-home-fixture');
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      cache.dispose();
      await session.events.close();
      await tester.pump();
    },
        () => MockClient((request) async {
              final path = request.url.path;
              if (path == '/community/activity') {
                return response({'items': [], 'nextCursor': null});
              }
              if (path.contains('/trending/')) {
                if (!trending.isCompleted) return await trending.future;
                return response([
                  {'id': 123, 'title': 'Useful fixture', 'mediaType': 'MOVIE'}
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
