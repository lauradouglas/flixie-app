import 'package:flixie_app/features/movies/presentation/widgets/watch_history_card.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:flixie_app/features/profile/presentation/widgets/featured_person_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/ratings_section.dart';
import 'package:flixie_app/features/movies/presentation/pages/watch_history_screen.dart';
import '../../support/api_fixture.dart';
import 'profile_controller_test.dart' show ProfileAuth, ProfileData;

Future<void> historyMediaJourney(WidgetTester tester) async {
  final auth = ProfileAuth();
  useApiFixture(MockClient((request) async => http.Response(
      jsonEncode(request.url.path.endsWith('/shows/watched')
          ? [
              {
                'showId': 348,
                'watchedAt': '2026-10-25',
                'rating': 8,
                'show': {'title': 'Alien: Earth'}
              },
              {
                'showId': 2,
                'removed': true,
                'show': {'title': 'Removed show'}
              }
            ]
          : []),
      200,
      headers: {'content-type': 'application/json'})));
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const WatchHistoryScreen()),
    GoRoute(
        path: '/shows/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Show ${state.pathParameters['id']}')))
  ]);
  addTearDown(auth.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth, child: MaterialApp.router(routerConfig: router)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Shows'));
  await tester.pumpAndSettle();
  expect(find.text('Alien: Earth'), findsOneWidget);
  expect(find.byType(GridView), findsOneWidget);
  expect(find.byType(WatchHistoryCard), findsOneWidget);
  expect(find.text('1 shows watched'), findsOneWidget);
  expect(find.text('25 Oct 2026'), findsOneWidget);
  expect(find.text('Your rating: 8.0/10'), findsOneWidget);
  await tester.tap(find.byTooltip('Actions for Alien: Earth'));
  await tester.pumpAndSettle();
  expect(find.text('Write a review'), findsOneWidget);
  expect(find.text('Log another watch'), findsNothing);
  await tester.tap(find.text('View show details'));
  await tester.pumpAndSettle();
  expect(find.text('Show 348'), findsOneWidget);
  router.pop();
  await tester.pumpAndSettle();
  expect(find.text('Removed show'), findsNothing);
  await tester.enterText(find.byType(TextField), 'missing');
  await tester.pumpAndSettle();
  expect(find.text('No matching shows.'), findsOneWidget);
  await tester.enterText(find.byType(TextField), 'Alien');
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Alien: Earth'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Alien: Earth'));
  await tester.pumpAndSettle();
  expect(find.text('Show 348'), findsOneWidget);
}

void main() {
  testWidgets('history exposes shows and searches and opens the show route',
      historyMediaJourney);
  testWidgets('people selection survives failed save and retries explicitly',
      (tester) async {
    var fail = true;
    int? saved;
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FeaturedPersonSheet(
                role: 'director',
                initialId: null,
                people: const [
                  {'id': 1, 'name': 'Nolan', 'department': 'Directing'},
                  {'id': 2, 'name': 'Pugh', 'department': 'Acting'},
                  {'id': 3, 'name': 'Unknown'}
                ],
                onSave: (id) async {
                  calls++;
                  if (fail) throw Exception('offline');
                  saved = id;
                }))));
    expect(find.text('Pugh'), findsNothing);
    expect(find.text('Role information unavailable'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Nolan');
    await tester.pump();
    await tester.tap(find.widgetWithText(ListTile, 'Nolan'));
    await tester.pump();
    expect(calls, 0);
    await tester.tap(find.text('Save highlight'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Retry'), 150,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    expect(find.textContaining('Your selection is still here'), findsOneWidget);
    expect(saved, isNull);
    fail = false;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(saved, 1);
  });
  test('ratings failure is exposed and a successful retry clears it', () async {
    final auth = ProfileAuth();
    final service = ProfileData();
    final data = ProfileController(auth: auth, service: service);
    final gate = Completer<List<MovieRating>>();
    service.ratingsGates['viewer'] = gate;
    final task = data.loadRatings();
    gate.completeError(Exception('offline'));
    await task;
    expect(data.ratingsFailed, true);
    expect(data.ratingsLoading, false);
    service.ratingsGates.clear();
    await data.loadRatings(forceRefresh: true);
    expect(data.ratingsFailed, false);
    expect(data.ratings, isEmpty);
    data.dispose();
    auth.dispose();
  });
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(768, 1024)
  ]) {
    testWidgets('people picker remains usable with large text at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 100)),
              child: child!),
          home: Scaffold(
              body: FeaturedPersonSheet(
                  role: 'director',
                  people: const [
                    {
                      'id': 1,
                      'name': 'A favourite person with a long name',
                      'department': 'Directing'
                    }
                  ],
                  initialId: 1,
                  onSave: (_) async {}))));
      await tester.pumpAndSettle();
      expect(find.text('Save highlight'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ratings error never claims empty and retry preserves search',
      (tester) async {
    var failed = true;
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, update) => AllRatingsSheet(
                    ratings: const [],
                    failed: failed,
                    onRetry: () {
                      retries++;
                      update(() => failed = false);
                    })))));
    await tester.enterText(find.byType(TextField), 'Alien');
    await tester.pump();
    expect(find.text('No ratings yet.'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(retries, 1);
    expect(find.text('Alien'), findsOneWidget);
    expect(find.text('No ratings found.'), findsOneWidget);
  });
}
