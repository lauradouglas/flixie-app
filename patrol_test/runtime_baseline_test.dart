import 'package:flixie_app/core/widgets/flixie_refresh.dart';
import 'package:flixie_app/features/movies/presentation/pages/search_screen.dart';
import 'package:flixie_app/features/social/presentation/widgets/insights_tab.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/watch_plans/presentation/pages/group_watch_plan_v2_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/person_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_list_detail_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/features/social/presentation/pages/social_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/home/data/recommendation_service.dart';
import 'package:flixie_app/features/home/presentation/pages/home_screen.dart';
import 'package:flixie_app/features/profile/presentation/pages/profile_screen.dart';
import 'package:flixie_app/features/profile/presentation/pages/friend_profile_screen.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/show_detail_screen.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import '../test/support/api_fixture.dart';
import '../test/support/watchlist_auth.dart';
import 'support/runtime_database_fixture.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/user.dart';

class _LedgerDatabaseClient extends RuntimeDatabaseClient {
  _LedgerDatabaseClient({required super.onStart, required super.onEnd});
  final insightQueries = <String>[];
  final searchQueries = <Map<String, Object?>>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.path.endsWith('/insights')) {
      insightQueries.add('${request.url.path}?${request.url.query}');
    }
    if (request.url.path.startsWith('/search')) {
      searchQueries
          .add({'path': request.url.path, ...request.url.queryParameters});
    }
    return super.send(request);
  }
}

class RuntimeAuth extends TestAuth {
  @override
  int get unreadNotificationCount => 0;
}

/// Native simulator measurements with isolated fictional accounts.
/// RUNTIME_DATABASE=true selects the real local database/API fixture.
/// Results include debug/test overhead. This is an observational benchmark;
/// correctness assertions remain, but there are no machine-dependent speed gates.
void main() {
  patrolTest('record simulator runtime ledger', ($) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final requests = <String, int>{};
    var active = 0;
    var maxActive = 0;
    const database = bool.fromEnvironment('RUNTIME_DATABASE');
    const selectedScenario = String.fromEnvironment('RUNTIME_SCENARIO');
    final mockedClient = MockClient((request) async {
      final path = request.url.path;
      requests.update('${request.method} $path', (count) => count + 1,
          ifAbsent: () => 1);
      active++;
      if (active > maxActive) maxActive = active;
      try {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        Object? body = [];
        if (RegExp(r'^/movies/id/\d+$').hasMatch(path)) {
          body = {
            'id': 1,
            'title': 'The Odyssey',
            'overview': 'A fixture journey.',
            'runtime': 120,
            'voteAverage': 8.0,
            'voteCount': 25
          };
        } else if (RegExp(r'^/shows/id/\d+$').hasMatch(path)) {
          body = {
            'id': 101,
            'name': 'Alien: Earth',
            'overview': 'A fixture story.',
            'numberOfEpisodes': 8,
            'numberOfSeasons': 1,
            'seasons': []
          };
        } else if (path.contains('/trending/')) {
          body = [
            {'id': 1, 'title': 'The Odyssey', 'popularity': 10}
          ];
        } else if (path.endsWith('/images') || path.endsWith('/credits')) {
          body = {};
        } else if (path.endsWith('/friend-summary')) {
          body = {
            'friendCount': 0,
            'watchedCount': 0,
            'favouriteCount': 0,
            'watchlistCount': 0
          };
        } else if (path.endsWith('/friend-recommendation')) {
          body = {
            'movieId': '1',
            'friendCount': 0,
            'friends': [],
            'recommendPercent': 0,
            'recommendedCount': 0
          };
        } else if (path == '/movies/friend-recommendations') {
          final ids =
              (jsonDecode(request.body)['movieIds'] as List).cast<int>();
          body = {
            'items': [
              for (final id in ids)
                {
                  'movieId': '$id',
                  'friendCount': 0,
                  'friends': [],
                  'recommendPercent': 0,
                  'recommendedCount': 0
                }
            ]
          };
        } else if (path.endsWith('/watch-providers')) {
          body = {'watchProviders': []};
        } else if (path.contains('/rating')) {
          body = null;
        } else if (path == '/groups/home/watch-plans') {
          body = {'groups': []};
        } else if (path.contains('/community/')) {
          body = {'items': [], 'nextCursor': null};
        } else if (path.contains('from-highly-rated')) {
          body = {'recommendations': []};
        }
        return http.Response(jsonEncode(body), 200,
            headers: {'content-type': 'application/json'});
      } finally {
        active--;
      }
    });
    final databaseClient = _LedgerDatabaseClient(
        onStart: (path) {
          requests.update(path, (value) => value + 1, ifAbsent: () => 1);
          active++;
          if (active > maxActive) maxActive = active;
        },
        onEnd: () => active--);
    final client = database ? databaseClient : mockedClient;
    useApiFixture(client);
    addTearDown(() {
      ApiClient.setToken(null);
      if (database) {
        mockedClient.close();
      } else {
        databaseClient.close();
      }
    });
    final manifest = database
        ? await databaseClient.load('/benchmark/manifest')
        : <String, dynamic>{};
    final analytics = AnalyticsController(
        backend: RuntimeAnalyticsBackend(),
        consentStore: RuntimeAnalyticsConsentStore());
    await analytics.initialize();
    addTearDown(analytics.dispose);
    final samples = <Map<String, Object?>>[];
    final export =
        File('${Directory.systemTemp.path}/flixie-runtime-baseline.json');
    final method = {
      'fixture_http_delay_ms': database ? 0 : 25,
      'data_source':
          database ? 'local PostgreSQL + real API routes' : 'mock HTTP',
      if (database) 'database_manifest': manifest,
      'mode': 'debug',
      'selected_scenario': selectedScenario.isEmpty ? 'all' : selectedScenario,
      'image_fixture':
          database ? 'catalogue posters; external image network' : 'no posters',
      'scope':
          'mounted screens; excludes app bootstrap/auth and physical-device performance'
    };
    Future<void> save(bool complete) async {
      final body = jsonEncode(
          {'complete': complete, 'method': method, 'samples': samples});
      await export.writeAsString(body);
      if (database && samples.isNotEmpty) {
        final result = await databaseClient.post(
            Uri.parse('${ApiClient.baseUrl}/benchmark/results'),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer ${ApiClient.getToken()}'
            },
            body: body);
        expect(result.statusCode, 200,
            reason: 'Persist native measurements before simulator cleanup');
      }
    }

    await save(false);
    final scenarios = [
      'home',
      'movie_detail',
      'tv_detail',
      'watchlist_20',
      'watchlist_400',
      if (selectedScenario == 'profile') 'profile',
      if (selectedScenario == 'friend_profile') 'friend_profile',
      if (selectedScenario == 'social') 'social',
      if (selectedScenario == 'watch_requests') 'watch_requests',
      if (selectedScenario == 'movie_list_detail') 'movie_list_detail',
      if (selectedScenario == 'group_watch_plan') 'group_watch_plan',
      if (selectedScenario == 'search') 'search',
      if (selectedScenario == 'group_insights') 'group_insights',
      if (selectedScenario == 'watch_composer') 'watch_composer',
      if (selectedScenario == 'person_detail') 'person_detail'
    ]
        .where((scenario) =>
            selectedScenario.isEmpty || scenario == selectedScenario)
        .toList();
    expect(scenarios, isNotEmpty,
        reason: 'Runtime scenario must be recognised');
    for (final scenario in scenarios) {
      for (var repetition = 0; repetition < 5; repetition++) {
        final movies = MovieService();
        final viewer = manifest[
            scenario == 'watchlist_400' ? 'largeViewer' : 'smallViewer'];
        final TestAuth auth;
        if (database) {
          ApiClient.setToken(viewer as String);
          final user = User.fromJson(
              await databaseClient.load('/benchmark/users/$viewer'));
          expect(user.movieWatchlist?.length,
              scenario == 'watchlist_400' ? 400 : 20);
          auth = RuntimeDatabaseAuth(user, movies);
        } else {
          auth = RuntimeAuth()
            ..ids = List.generate(
                scenario == 'watchlist_400' ? 400 : 20, (i) => i + 1);
        }
        final plans = WatchRequestCache();
        for (final cache in ['cold', 'warm']) {
          if (cache == 'cold') {
            movies.clearCache();
            ShowService.clearSummaryCache();
            RecommendationService.invalidateCache();
            PaintingBinding.instance.imageCache.clear();
            PaintingBinding.instance.imageCache.clearLiveImages();
          }
          await $.pumpWidgetAndSettle(const SizedBox.shrink());
          await Future<void>.delayed(const Duration(milliseconds: 600));
          if (scenario == 'search') {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('device_recent_searches_v1');
          }
          requests.clear();
          databaseClient.searchQueries.clear();
          databaseClient.insightQueries.clear();
          databaseClient.responses.clear();
          databaseClient.transportErrors.clear();
          maxActive = 0;
          final frames = <FrameTiming>[];
          void collect(List<FrameTiming> batch) => frames.addAll(batch);
          SchedulerBinding.instance.addTimingsCallback(collect);
          final memoryStart = ProcessInfo.currentRss;
          var memoryPeak = memoryStart;
          final poll = Timer.periodic(const Duration(milliseconds: 20), (_) {
            final rss = ProcessInfo.currentRss;
            if (rss > memoryPeak) memoryPeak = rss;
          });
          addTearDown(poll.cancel);
          final screen = switch (scenario) {
            'watch_composer' => Scaffold(
                body: MovieWatchRequestSheet(
                    movieId: manifest['movie']['id'] as int,
                    movieTitle: manifest['movie']['title'] as String,
                    requesterId: viewer as String,
                    friends: const [],
                    onSuccess: () {},
                    onError: () {})),
            'search' => const SearchScreen(),
            'group_watch_plan' => const GroupWatchPlanV2Screen(),
            'group_insights' => const Scaffold(
                body: GroupInsightsTab(groupId: 'runtime-plan-group-0')),
            'person_detail' =>
              PersonDetailScreen(personId: '${manifest['person']['id']}'),
            'movie_list_detail' => MovieListDetailScreen(
                listId: manifest['movieLists']['listId'] as String,
                listName: manifest['movieLists']['name'] as String),
            'home' => const HomeScreen(),
            'social' => const SocialScreen(),
            'watch_requests' => const WatchRequestsScreen(),
            'profile' => const ProfileScreen(),
            'friend_profile' =>
              const FriendProfileScreen(userId: 'runtime-fixture-2'),
            'movie_detail' => MovieDetailScreen(
                movieId: database ? '${manifest['movie']['id']}' : '1'),
            'tv_detail' => ShowDetailScreen(
                showId: database ? '${manifest['show']['id']}' : '101'),
            _ => const WatchlistScreen(),
          };
          final useful = switch (scenario) {
            'watch_composer' => find.text('runtime_2'),
            'group_watch_plan' => find.textContaining('Runtime film club'),
            'search' => find.text('Alien'),
            'group_insights' => find.text('Highlights'),
            'person_detail' => find.text(manifest['person']['name'] as String),
            'movie_list_detail' =>
              find.text(manifest['movieLists']['name'] as String),
            'profile' => find.text('Profile'),
            'social' => find.byType(ActivityTile),
            'watch_requests' => find.text('Needs your response'),
            'friend_profile' => find.byKey(const ValueKey('profile-totals')),
            'home' => find.text(database
                ? manifest['trendingFirstTitle'] as String
                : 'Trending now'),
            'movie_detail' => find.text(database
                ? manifest['movie']['title'] as String
                : 'The Odyssey'),
            'tv_detail' => find.text(database
                ? manifest['show']['title'] as String
                : 'Alien: Earth'),
            _ => find.text(database
                ? auth.dbUser.movieWatchlist!.first.movie!.title
                : 'Film 1'),
          };
          final watch = Stopwatch()..start();
          await $.pumpWidget(MultiProvider(providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<AnalyticsController>.value(value: analytics),
            Provider<MovieService>.value(value: movies),
            ChangeNotifierProvider<WatchRequestCache>.value(value: plans),
          ], child: MaterialApp(theme: AppTheme.darkTheme, home: screen)));
          if (scenario == 'social') {
            // A review card can extend below the viewport: observe its visible header.
            await $(find.text('American History X')).waitUntilVisible();
          } else {
            await $(useful).waitUntilVisible();
          }
          final usefulUs = watch.elapsedMicroseconds;
          await $.pumpAndSettle();
          final deadline = DateTime.now().add(const Duration(seconds: 30));
          while (active > 0 && DateTime.now().isBefore(deadline)) {
            await $.pump(const Duration(milliseconds: 100));
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          await $.pumpAndSettle();
          expect(active, 0,
              reason: 'Requests must settle before ending load timing');
          final settledUs = watch.elapsedMicroseconds;
          final loadRequests = Map<String, int>.from(requests);
          final loadFrameCount = frames.length;
          final scroll = scenario == 'social' ||
                  scenario == 'watch_requests' ||
                  scenario == 'search'
              ? find
                  .byWidgetPredicate((w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down)
                  .hitTestable()
                  .first
              : find.byType(Scrollable).first;
          for (var gesture = 0; gesture < 5; gesture++) {
            await $.tester.fling(scroll, const Offset(0, -400), 1200);
            await $.pumpAndSettle();
          }
          final searchStages = <String, Object?>{};
          if (scenario == 'search') {
            Future<void> stage(
                String name, Future<void> Function() action) async {
              final before = Map<String, int>.from(requests);
              final start = databaseClient.searchQueries.length;
              final timer = Stopwatch()..start();
              await action();
              await $.pumpAndSettle();
              final deadline = DateTime.now().add(const Duration(seconds: 30));
              while (active > 0 && DateTime.now().isBefore(deadline)) {
                await $.pump(const Duration(milliseconds: 100));
                await Future<void>.delayed(const Duration(milliseconds: 100));
              }
              await $.pumpAndSettle();
              expect(active, 0);
              debugPrint(
                  'SEARCH_STAGE $name ${jsonEncode(databaseClient.searchQueries.sublist(start))}');
              searchStages[name] = {
                'settled_us': timer.elapsedMicroseconds,
                'requests': {
                  for (final e in requests.entries)
                    if (e.value > (before[e.key] ?? 0))
                      e.key: e.value - (before[e.key] ?? 0)
                },
                'queries': databaseClient.searchQueries.sublist(start)
              };
            }

            Future<void> type(String value) async {
              await $.tester.tap(find.byType(TextField));
              await $.pump();
              await $.tester.enterText(find.byType(TextField), value);
              expect($.tester.widget<TextField>(find.byType(TextField)).controller!.text, value);
              FocusManager.instance.primaryFocus?.unfocus();
              await $.pump(const Duration(milliseconds: 450));
              await Future<void>.delayed(const Duration(milliseconds: 450));
            }

            Future<void> mode(String label) async {
              await $.tester.ensureVisible(find.text(label));
              await $.tester.tap(find.text(label));
            }

            await stage('typing', () async {
              await $.tester.enterText(find.byType(TextField), 'al');
              await $.pump(const Duration(milliseconds: 100));
              await type('a');
            });
            expect(find.textContaining('Search for', findRichText: true),
                findsOneWidget);
            await stage('paging', () async {
              await $.tester.scrollUntilVisible(find.text('Load more'), 500,
                  scrollable: find
                      .byWidgetPredicate((w) =>
                          w is Scrollable &&
                          w.axisDirection == AxisDirection.down)
                      .first);
              final button = find.ancestor(of: find.text('Load more'), matching: find.byType(TextButton));
              await Scrollable.ensureVisible($.tester.element(button), alignment: .5);
              await $.pumpAndSettle();
              expect(button.hitTestable(), findsOneWidget);
              await $.tester.tap(button);
            });
            await stage('movies', () => mode('Movies'));
            await stage('shows', () => mode('Shows'));
            await stage('people', () => mode('People'));
            expect(
                find.text('Casey Runtime', findRichText: true), findsOneWidget);
            await stage('collections', () => mode('Collections'));
            await stage(
                'refresh',
                () => $.tester
                    .widget<FlixieRefresh>(find.byType(FlixieRefresh))
                    .onRefresh());
            await stage('empty', () async {
              await type('zzzz-no-runtime-match');
              try {
                await $(find.textContaining('No results for')).waitUntilVisible();
              } catch (_) {
                throw StateError('Empty state missing: queries=${databaseClient.searchQueries}; statuses=${databaseClient.responses}; text=${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}');
              }
            });
            expect(find.textContaining('No results for'), findsOneWidget);
            await stage(
                'clear', () => $.tester.tap(find.byTooltip('Clear search')));
            expect(find.text('Trending movies'), findsOneWidget);
          }
          final insightsStages = <String, Object?>{};
          if (scenario == 'group_insights') {
            Future<void> stage(
                String name, Future<void> Function() action) async {
              final before = Map<String, int>.from(requests);
              final queryStart = databaseClient.insightQueries.length;
              final timer = Stopwatch()..start();
              await action();
              await $.pumpAndSettle();
              final deadline = DateTime.now().add(const Duration(seconds: 30));
              while (active > 0 && DateTime.now().isBefore(deadline)) {
                await $.pump(const Duration(milliseconds: 100));
                await Future<void>.delayed(const Duration(milliseconds: 100));
              }
              await $.pumpAndSettle();
              expect(active, 0);
              expect(find.text('Highlights'), findsOneWidget);
              insightsStages[name] = {
                'settled_us': timer.elapsedMicroseconds,
                'requests': {
                  for (final e in requests.entries)
                    if (e.value > (before[e.key] ?? 0))
                      e.key: e.value - (before[e.key] ?? 0)
                },
                'queries': databaseClient.insightQueries.sublist(queryStart),
              };
            }

            $.tester.state<ScrollableState>(scroll).position.jumpTo(0);
            await $.pumpAndSettle();
            await stage('all_time', () => $.tester.tap(find.text('All time')));
            await stage(
                'same_period', () => $.tester.tap(find.text('All time')));
            await stage('month', () => $.tester.tap(find.text('This month')));
            await stage('refresh', () async {
              await $.tester
                  .widget<RefreshIndicator>(find.byType(RefreshIndicator))
                  .onRefresh();
            });
            await stage('refresh_burst', () async {
              final refresh = $.tester
                  .widget<RefreshIndicator>(find.byType(RefreshIndicator))
                  .onRefresh;
              await Future.wait([refresh(), refresh()]);
            });
            expect(databaseClient.transportErrors, isEmpty);
            expect(
                databaseClient.responses.values.expand((v) => v.keys).toSet(),
                {'200'});
          }
          final listStages = <String, Object?>{};
          if (scenario == 'movie_list_detail') {
            Future<void> recordListStage(
                String label, Future<void> Function() action) async {
              final before = Map<String, int>.from(requests);
              final timer = Stopwatch()..start();
              await action();
              await $.pumpAndSettle();
              final deadline = DateTime.now().add(const Duration(seconds: 30));
              while (active > 0 && DateTime.now().isBefore(deadline)) {
                await $.pump(const Duration(milliseconds: 100));
                await Future<void>.delayed(const Duration(milliseconds: 100));
              }
              await $.pumpAndSettle();
              expect(active, 0);
              listStages[label] = {
                'settled_us': timer.elapsedMicroseconds,
                'requests': {
                  for (final e in requests.entries)
                    if (e.value > (before[e.key] ?? 0))
                      e.key: e.value - (before[e.key] ?? 0)
                }
              };
            }

            await recordListStage('members', () async {
              await $(find.byTooltip('List actions')).tap();
              await $('View members').tap();
              await $('3 members').waitUntilVisible();
              Navigator.of($.tester.element(find.text('3 members')),
                      rootNavigator: true)
                  .pop();
            });
            await recordListStage('refresh', () async {
              await $(find.byTooltip('List actions')).tap();
              await $('Refresh').tap();
            });
            await $.tester.fling(scroll, const Offset(0, 5000), 4000);
            await $.pumpAndSettle();
            await recordListStage('sort_title', () async {
              await $(find.byTooltip('Sort list')).tap();
              await $('Title').tap();
            });
          }
          final personStages = <String, Object?>{};
          if (scenario == 'person_detail') {
            Future<void> recordPersonStage(
                String label, Future<void> Function() action) async {
              final before = Map<String, int>.from(requests);
              final timer = Stopwatch()..start();
              await action();
              await $.pumpAndSettle();
              expect(active, 0);
              personStages[label] = {
                'settled_us': timer.elapsedMicroseconds,
                'requests': {
                  for (final entry in requests.entries)
                    if (entry.value > (before[entry.key] ?? 0))
                      entry.key: entry.value - (before[entry.key] ?? 0)
                }
              };
            }

            await $.tester.ensureVisible(find.textContaining('View All').first);
            await $.pumpAndSettle();
            await recordPersonStage('all_credits', () async {
              await $(find.textContaining('View All').first).tap();
              await $('All Credits').waitUntilVisible();
              final sheetScroll = find.byType(Scrollable).hitTestable().last;
              for (var i = 0; i < 5; i++) {
                await $.tester.fling(sheetScroll, const Offset(0, -400), 1200);
                await $.pumpAndSettle();
              }
              Navigator.of($.tester.element(find.text('All Credits')),
                      rootNavigator: true)
                  .pop();
            });
            await $.tester.ensureVisible(find.byType(TextField));
            await $.pumpAndSettle();
            await recordPersonStage('search_alien', () async {
              await $(find.byType(TextField)).enterText('Alien');
            });
            await recordPersonStage('tv_filter', () async {
              FocusManager.instance.primaryFocus?.unfocus();
              await $.tester.ensureVisible(find.text('TV').first);
              await $.pumpAndSettle();
              await $(find.text('TV').first).tap();
            });
          }
          final socialStages = <String, Object?>{};
          if (scenario == 'social') {
            Future<void> recordStage(
                String label, Future<void> Function() action) async {
              final before = Map<String, int>.from(requests);
              final timer = Stopwatch()..start();
              await action();
              await $.pumpAndSettle();
              final deadline = DateTime.now().add(const Duration(seconds: 30));
              while (active > 0 && DateTime.now().isBefore(deadline)) {
                await $.pump(const Duration(milliseconds: 100));
                await Future<void>.delayed(const Duration(milliseconds: 100));
              }
              await $.pumpAndSettle();
              expect(active, 0);
              socialStages[label] = {
                'settled_us': timer.elapsedMicroseconds,
                'requests': {
                  for (final e in requests.entries)
                    if (e.value > (before[e.key] ?? 0))
                      e.key: e.value - (before[e.key] ?? 0)
                },
                'activity_tiles': find.byType(ActivityTile).evaluate().length,
              };
            }

            await recordStage('following_page', () async {
              await $.tester.scrollUntilVisible(find.text('Show more'), 500,
                  scrollable: find
                      .byWidgetPredicate((w) =>
                          w is Scrollable &&
                          w.axisDirection == AxisDirection.down)
                      .hitTestable()
                      .first,
                  maxScrolls: 40);
              for (var retry = 0;
                  retry < 10 &&
                      find.text('Show more').hitTestable().evaluate().isEmpty;
                  retry++) {
                await $.tester.ensureVisible(find.text('Show more'));
                await $.pumpAndSettle();
              }
              expect(find.text('Show more').hitTestable(), findsOneWidget);
              await $.tester.tap(find.text('Show more').hitTestable().first);
            });
            for (final tab in ['People', 'Groups', 'Activity']) {
              await recordStage(
                  tab, () => $.tester.tap(find.text(tab).hitTestable().first));
            }
            await recordStage(
                'Around Flixie',
                () => $.tester
                    .tap(find.text('Around Flixie').hitTestable().first));
            await recordStage('around_page', () async {
              await $.tester.scrollUntilVisible(find.text('Show more'), 500,
                  scrollable: find
                      .byWidgetPredicate((w) =>
                          w is Scrollable &&
                          w.axisDirection == AxisDirection.down)
                      .hitTestable()
                      .first,
                  maxScrolls: 40);
              for (var retry = 0;
                  retry < 10 &&
                      find.text('Show more').hitTestable().evaluate().isEmpty;
                  retry++) {
                await $.tester.ensureVisible(find.text('Show more'));
                await $.pumpAndSettle();
              }
              expect(find.text('Show more').hitTestable(), findsOneWidget);
              await $.tester.tap(find.text('Show more').hitTestable().first);
            });
          }
          final requestStages = <String, Object?>{};
          if (scenario == 'watch_requests') {
            Future<void> stage(
                String name, Future<void> Function() action) async {
              final before = Map<String, int>.from(requests);
              final timer = Stopwatch()..start();
              await action();
              await $.pumpAndSettle();
              final deadline = DateTime.now().add(const Duration(seconds: 30));
              while (active > 0 && DateTime.now().isBefore(deadline)) {
                await $.pump(const Duration(milliseconds: 100));
                await Future<void>.delayed(const Duration(milliseconds: 100));
              }
              await $.pumpAndSettle();
              expect(active, 0);
              requestStages[name] = {
                'settled_us': timer.elapsedMicroseconds,
                'requests': {
                  for (final e in requests.entries)
                    if (e.value > (before[e.key] ?? 0))
                      e.key: e.value - (before[e.key] ?? 0)
                }
              };
            }

            await stage(
                'Past',
                () => $.tester
                    .tap(find.textContaining('Past ·').hitTestable().first));
            await stage(
                'Active',
                () => $.tester
                    .tap(find.textContaining('Active ·').hitTestable().first));
            await stage('refresh', () async {
              TabRefreshController.watchPlans.value++;
            });
            await stage(
                'Groups',
                () => $.tester
                    .tap(find.textContaining('Groups ·').hitTestable().first));
            await stage(
                'Friends',
                () => $.tester
                    .tap(find.textContaining('Friends ·').hitTestable().first));
          }
          final composerStages = <String, Object?>{};
          if (scenario == 'watch_composer') {
            Future<void> stage(String name, String label) async {
              for (final state in $.tester
                  .stateList<ScrollableState>(find.byType(Scrollable))) {
                if (state.position.axis == Axis.vertical) {
                  state.position.jumpTo(0);
                }
              }
              await $.pumpAndSettle();
              expect(find.text(label), findsWidgets,
                  reason:
                      '$name: visible labels ${$.tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).whereType<String>().join(" | ")}');
              final before = Map<String, int>.from(requests);
              final timer = Stopwatch()..start();
              final text = find.text(label).first;
              final tile =
                  find.ancestor(of: text, matching: find.byType(InkWell));
              final target = tile.evaluate().isEmpty ? text : tile.first;
              await Scrollable.ensureVisible($.tester.element(target),
                  alignment: .5);
              await $.pumpAndSettle();
              expect(target.hitTestable(), findsOneWidget,
                  reason:
                      '$name target must accept input at ${$.tester.getRect(target)}');
              await $.tester.tap(target);
              await $.pumpAndSettle();
              final deadline = DateTime.now().add(const Duration(seconds: 30));
              while (active > 0 && DateTime.now().isBefore(deadline)) {
                await $.pump(const Duration(milliseconds: 100));
                await Future<void>.delayed(const Duration(milliseconds: 100));
              }
              await $.pumpAndSettle();
              expect(active, 0);
              if (!name.endsWith('_mode')) {
                expect(
                    find.descendant(
                        of: target,
                        matching: find.byIcon(Icons.check_circle_rounded)),
                    findsOneWidget,
                    reason: '$name must select the recipient');
              }
              composerStages[name] = {
                'settled_us': timer.elapsedMicroseconds,
                'requests': {
                  for (final e in requests.entries)
                    if (e.value > (before[e.key] ?? 0))
                      e.key: e.value - (before[e.key] ?? 0)
                }
              };
            }

            for (final state in $.tester
                .stateList<ScrollableState>(find.byType(Scrollable))) {
              if (state.position.axis == Axis.vertical) {
                state.position.jumpTo(0);
              }
            }
            await $.pumpAndSettle();
            await stage('friend_first', 'runtime_2');
            await stage('friend_second', 'runtime_3');
            await stage('group_mode', 'A Group');
            await stage('group_first', 'Runtime film club 1');
            await stage('group_second', 'Runtime film club 2');
            await stage('group_return', 'Runtime film club 1');
            await stage('friend_mode', 'A Friend');
            await stage('friend_return', 'runtime_2');
            expect(databaseClient.transportErrors, isEmpty);
            expect(
                databaseClient.responses.values.expand((v) => v.keys).toSet(),
                {'200'});
          }
          final groupStages = <String, Object?>{};
          if (scenario == 'group_watch_plan') {
            Future<void> stage(
                String name, Future<void> Function() action) async {
              final before = Map<String, int>.from(requests);
              final timer = Stopwatch()..start();
              await action();
              await $.pumpAndSettle();
              final deadline = DateTime.now().add(const Duration(seconds: 30));
              while (active > 0 && DateTime.now().isBefore(deadline)) {
                await $.pump(const Duration(milliseconds: 100));
                await Future<void>.delayed(const Duration(milliseconds: 100));
              }
              await $.pumpAndSettle();
              expect(active, 0);
              groupStages[name] = {
                'settled_us': timer.elapsedMicroseconds,
                'requests': {
                  for (final e in requests.entries)
                    if (e.value > (before[e.key] ?? 0))
                      e.key: e.value - (before[e.key] ?? 0)
                }
              };
            }

            Future<void> top() async {
              $.tester.state<ScrollableState>(scroll).position.jumpTo(0);
              await $.pumpAndSettle();
            }

            await top();
            await stage('past',
                () => $.tester.tap(find.textContaining('Past ·').first));
            await stage('active',
                () => $.tester.tap(find.textContaining('Active ·').first));
            await stage('refresh', () async {
              TabRefreshController.watchPlans.value++;
            });
            await stage('refresh_burst', () async {
              TabRefreshController.watchPlans.value++;
              TabRefreshController.social.value++;
            });
            await stage('open_detail', () async {
              final card = find.textContaining('Runtime film club').first;
              await $.tester.ensureVisible(card);
              await $.tester.tap(card);
            });
            expect(find.byTooltip('Back to Watch Plans'), findsOneWidget);
            await stage('back',
                () => $.tester.tap(find.byTooltip('Back to Watch Plans')));
            expect(find.textContaining('Active ·'), findsOneWidget);
            expect(databaseClient.transportErrors, isEmpty);
            expect(
                databaseClient.responses.values.expand((v) => v.keys).toSet(),
                {'200'});
          }
          final profileTabs = <String, Object?>{};
          if (scenario == 'profile' || scenario == 'friend_profile') {
            if (scenario == 'profile') {
              expect(
                  requests.keys.where((path) =>
                      path.contains('/wrapped/') || path.endsWith('/reviews')),
                  isEmpty,
                  reason: 'Stats data must remain lazy in Library');
            }
            for (final tab in scenario == 'profile'
                ? ['Activity', 'Stats', 'Library', 'Stats']
                : ['Activity', 'Reviews', 'Overview', 'Reviews']) {
              final before = Map<String, int>.from(requests);
              final timer = Stopwatch()..start();
              if (scenario == 'friend_profile') {
                for (var attempt = 0;
                    attempt < 20 &&
                        find.text(tab).hitTestable().evaluate().isEmpty;
                    attempt++) {
                  await $.tester
                      .drag(find.byType(ListView).first, const Offset(0, 600));
                  await $.pumpAndSettle();
                }
                expect(find.text(tab).hitTestable(), findsOneWidget);
              }
              await $.tester.tap(find.text(tab).first);
              await $.pumpAndSettle();
              final deadline = DateTime.now().add(const Duration(seconds: 30));
              while (active > 0 && DateTime.now().isBefore(deadline)) {
                await $.pump(const Duration(milliseconds: 100));
                await Future<void>.delayed(const Duration(milliseconds: 100));
              }
              await $.pumpAndSettle();
              expect(active, 0);
              final reads = {
                for (final entry in requests.entries)
                  if (entry.value > (before[entry.key] ?? 0))
                    entry.key: entry.value - (before[entry.key] ?? 0)
              };
              final key = (tab == 'Stats' || tab == 'Reviews') &&
                      profileTabs.containsKey(tab)
                  ? '${tab}_cached'
                  : tab;
              profileTabs[key] = {
                'settled_us': timer.elapsedMicroseconds,
                'requests': reads
              };
              if (key.endsWith('_cached')) {
                expect(reads, isEmpty,
                    reason: 'Returning to Stats reuses loaded data');
              }
            }
          }
          final visibleContentErrors = $.tester.takeException();
          expect(visibleContentErrors, isNull);
          await Future<void>.delayed(const Duration(milliseconds: 600));
          poll.cancel();
          SchedulerBinding.instance.removeTimingsCallback(collect);
          final view = WidgetsBinding.instance.platformDispatcher.views.first;
          final sample = <String, Object?>{
            'scenario': scenario,
            'cache': cache,
            'repetition': repetition + 1,
            'useful_content_us': usefulUs,
            'settled_us': settledUs,
            'rss_start_bytes': memoryStart,
            'rss_peak_bytes': memoryPeak,
            'rss_end_bytes': ProcessInfo.currentRss,
            'image_cache_bytes':
                PaintingBinding.instance.imageCache.currentSizeBytes,
            'requests_load': loadRequests,
            if (scenario == 'movie_list_detail') 'list_stages': listStages,
            if (scenario == 'person_detail') 'person_stages': personStages,
            if (scenario == 'group_watch_plan') 'group_stages': groupStages,
            if (scenario == 'search') ...{
              'search_stages': searchStages,
              'search_queries': databaseClient.searchQueries,
            },
            if (scenario == 'group_insights') ...{
              'insights_stages': insightsStages,
              'insights_queries':
                  List<String>.from(databaseClient.insightQueries),
            },
            if (scenario == 'watch_composer') 'composer_stages': composerStages,
            if (scenario == 'social') 'social_stages': socialStages,
            if (scenario == 'watch_requests') 'request_stages': requestStages,
            if (scenario == 'profile' || scenario == 'friend_profile')
              'profile_tabs': profileTabs,
            if (database)
              'response_statuses': {
                for (final entry in databaseClient.responses.entries)
                  entry.key: Map<String, int>.from(entry.value),
              },
            if (database)
              'transport_errors': {
                for (final entry in databaseClient.transportErrors.entries)
                  entry.key: List<String>.from(entry.value),
              },
            'requests_total': Map<String, int>.from(requests),
            'max_active_fixture_http': maxActive,
            'provider_enrichment_batches':
                auth.providerRequests.map((ids) => ids.length).toList(),
            'load_frame_count_at_settle': loadFrameCount,
            'frame_build_us': frames
                .map((frame) => frame.buildDuration.inMicroseconds)
                .toList(),
            'frame_raster_us': frames
                .map((frame) => frame.rasterDuration.inMicroseconds)
                .toList(),
            'display_refresh_hz': view.display.refreshRate,
            'physical_width': view.physicalSize.width,
            'physical_height': view.physicalSize.height,
            'device_pixel_ratio': view.devicePixelRatio,
          };
          samples.add(sample);
          await save(false);
          await $.pumpWidgetAndSettle(const SizedBox.shrink());
        }
        auth.dispose();
        plans.dispose();
      }
    }
    await save(true);
  }, timeout: const Timeout(Duration(minutes: 25)));
}
