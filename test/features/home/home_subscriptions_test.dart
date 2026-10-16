import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/storage/movie_cache_service.dart';
import 'package:flixie_app/features/home/data/recommendation_service.dart';
import 'package:flixie_app/features/home/presentation/pages/home_screen.dart';
import 'package:flixie_app/features/home/presentation/widgets/greeting_header.dart';
import 'package:flixie_app/features/home/presentation/widgets/trending_carousel.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import '../../home_startup_recovery_test.dart' show Session;
import '../../auth_recovery_test.dart' show profile;

void main() {
  testWidgets('unread notifications use the bell without a Home catch-up banner',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    HomeScreen.clearSessionSnapshotForTesting();
    final session = Session();
    final auth = AuthProvider(session, MovieService(),
        prefetchAfterAuth: false,
        profileLoader: (id) async => profile(id),
        termsStatusLoader: () async => true);
    final cache = WatchRequestCache();
    final client = MockClient((request) async => http.Response(
        jsonEncode(request.url.path == '/groups/home/watch-plans'
            ? {'groups': []}
            : request.url.path == '/community/activity'
                ? {'items': [], 'nextCursor': null}
                : []),
        200));
    ApiClient.useClientForTesting(client);
    addTearDown(() {
      ApiClient.useClientForTesting(null);
      client.close();
    });
    session.events.add(session.identity);
    await tester.pump();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<WatchRequestCache>.value(value: cache),
    ], child: const MaterialApp(home: HomeScreen())));
    await tester.pump();
    auth.setUnreadNotificationCount(3);
    await tester.pump();
    expect(find.text('Catch up on your Flixie'), findsNothing);
    expect(find.text('3 unread updates'), findsNothing);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    final badge = tester.widget<Badge>(find.byType(Badge).first);
    expect(badge.isLabelVisible, isTrue);
    expect((badge.label! as Text).data, '3');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    cache.dispose();
    await session.events.close();
  });

  testWidgets(
      'signed-in trending survives profile and recommendation updates without friend calls',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    HomeScreen.clearSessionSnapshotForTesting();
    MovieCacheService().clearCache();
    RecommendationService.invalidateCache();
    final session = Session();
    final auth = AuthProvider(session, MovieService(),
        prefetchAfterAuth: false,
        profileLoader: (id) async => profile(id),
        termsStatusLoader: () async => true);
    final cache = WatchRequestCache();
    final recommendations = Completer<http.Response>();
    final friendReads = <int>[];
    http.Response response(Object data) => http.Response(jsonEncode(data), 200,
        headers: {'content-type': 'application/json'});
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path == '/trending/movie/day') {
        return response([
          {'id': 13, 'title': 'Alien'},
          {'id': 14, 'title': 'The Odyssey'},
          {'id': 15, 'title': 'Obsession'}
        ]);
      }
      if (path.endsWith('/recommendations')) return recommendations.future;
      if (path.contains('/interactions/movie/')) {
        final id = int.parse(path.split('/').last);
        friendReads.add(id);
        return response([]);
      }
      if (path == '/community/activity') {
        return response({'items': [], 'nextCursor': null});
      }
      if (path == '/groups/home/watch-plans') return response({'groups': []});
      return response([]);
    });
    ApiClient.useClientForTesting(client);
    addTearDown(() {
      ApiClient.useClientForTesting(null);
      client.close();
      RecommendationService.invalidateCache();
    });
    session.events.add(session.identity);
    await tester.pump();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<WatchRequestCache>.value(value: cache),
    ], child: const MaterialApp(home: HomeScreen())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TrendingCarousel), findsOneWidget);
    expect(find.text('Alien'), findsOneWidget);
    expect(friendReads, isEmpty);

    auth.setUnreadNotificationCount(3);
    await tester.pump();
    expect(find.text('Catch up on your Flixie'), findsNothing);
    expect(find.text('3 unread updates'), findsNothing);
    final notificationBadge = tester.widget<Badge>(find.byType(Badge).first);
    expect(notificationBadge.isLabelVisible, isTrue);
    expect((notificationBadge.label! as Text).data, '3');
    auth.updateDbUser(profile(session.identity.uid)
        .copyWith(firstName: 'Taylor', profileBadges: ['EARLY_ADOPTER']));
    await tester.pump();
    final greeting = tester.widget<GreetingHeader>(find.byType(GreetingHeader));
    expect(greeting.name, 'Taylor');
    expect(greeting.profileBadges, ['EARLY_ADOPTER']);

    recommendations.complete(response([
      {'id': 99, 'title': 'Obsession'}
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Just for you'), findsOneWidget);
    expect(find.text('Alien'), findsOneWidget);
    await tester.drag(find.byType(PageView).first, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('The Odyssey'), findsOneWidget);
    expect(friendReads, isEmpty,
        reason: 'catalogue paging must not fetch friend activity');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    cache.dispose();
    await session.events.close();
  });
}
