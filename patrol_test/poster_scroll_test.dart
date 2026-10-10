// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/home/data/recommendation_service.dart';
import 'package:flixie_app/features/home/presentation/controllers/home_controller.dart';
import 'package:flixie_app/features/home/presentation/pages/home_screen.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/presentation/pages/search_screen.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import 'package:flixie_app/models/user.dart';
import '../test/support/api_fixture.dart';
import '../tool/runtime_fixture_endpoint.dart';
import 'support/runtime_database_fixture.dart';
import 'support/controlled_poster_cache.dart';

class _PosterAuth extends RuntimeDatabaseAuth {
  _PosterAuth(super.user, super.movies);
  @override
  bool get activityIncludesRefreshedProfile => true;
}

void main() {
  patrolTest('controlled image memory and scrolling for Home Watchlist Search',
      ($) async {
    verifyRuntimeFixtureEndpoint(ApiClient.baseUrl);
    SharedPreferences.setMockInitialValues({});
    const capture = String.fromEnvironment('POSTER_CAPTURE_ID');
    const variant = String.fromEnvironment('POSTER_VARIANT');
    expect(capture, isNotEmpty);
    final requests = <String, int>{};
    var active = 0;
    final client = RuntimeDatabaseClient(
        onStart: (path) {
          requests.update(path, (n) => n + 1, ifAbsent: () => 1);
          active++;
        },
        onEnd: () => active--);
    useApiFixture(client);
    final manifest = await client.load('/benchmark/manifest');
    expect(manifest['database'], 'flixie_runtime_fixture');
    final viewer = manifest['largeViewer'] as String;
    ApiClient.setToken(viewer);
    final user = User.fromJson(await client.load('/benchmark/users/$viewer'));
    expect(user.movieWatchlist, hasLength(400));
    final images = ControlledPosterCache();
    await images.prepare();
    final original = CachedNetworkImageProvider.defaultCacheManager;
    CachedNetworkImageProvider.defaultCacheManager = images;
    addTearDown(() async {
      CachedNetworkImageProvider.defaultCacheManager = original;
      await images.cleanUp();
    });
    final analytics = AnalyticsController(
        backend: RuntimeAnalyticsBackend(),
        consentStore: RuntimeAnalyticsConsentStore());
    await analytics.initialize();
    addTearDown(analytics.dispose);
    final samples = <Map<String, Object?>>[];
    final cache = PaintingBinding.instance.imageCache;
    Map<String, int> memory() => {
          'image_bytes': cache.currentSizeBytes,
          'image_count': cache.currentSize,
          'live_images': cache.liveImageCount,
          'pending_images': cache.pendingImageCount,
          'rss_bytes': ProcessInfo.currentRss
        };
    Future<void> settle() async {
      await $.pumpAndSettle();
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (active > 0 || cache.pendingImageCount > 0) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Unsettled API/images: $active/${cache.pendingImageCount}');
        }
        await $.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await $.pumpAndSettle();
    }

    Future<void> save(bool complete) async {
      final body = {
        'complete': complete,
        'method': {
          'suite': 'poster_scroll_v1',
          'capture_id': capture,
          'variant': variant,
          'mode': 'debug simulator',
          'manifest': manifest,
          'images':
              'controlled disk PNGs, 2:3, CDN URL width; non-width URLs 342px; no image network',
          'scope':
              'cold Flutter image cache, warm local disk; 400-title account; mounted page; 6 down then 6 up 350px flings at 1200px/s',
          'dpr': $.tester.view.devicePixelRatio,
          'physical_size': '${$.tester.view.physicalSize}',
          'rss': 'process RSS without forced GC; not live Dart heap'
        },
        'samples': samples
      };
      final response = await client.post(
          Uri.parse('${ApiClient.baseUrl}/benchmark/results'),
          headers: {
            'authorization': 'Bearer $viewer',
            'content-type': 'application/json'
          },
          body: jsonEncode(body));
      expect(response.statusCode, 200);
    }

    // First repetition exercises compilation/cache paths and is excluded by analysis.
    for (var repetition = 0; repetition < 6; repetition++) {
      for (final scenario in ['home', 'watchlist', 'search']) {
        HomeController.clearSessionSnapshotForTesting();
        RecommendationService.invalidateCache();
        final movies = MovieService()..clearCache();
        final auth = _PosterAuth(user, movies);
        final plans = WatchRequestCache();
        cache.clear();
        cache.clearLiveImages();
        images.reads.clear();
        requests.clear();
        client.responses.clear();
        client.transportErrors.clear();
        final baseline = memory();
        final router = GoRouter(routes: [
          GoRoute(
              path: '/',
              builder: (_, __) => switch (scenario) {
                    'home' => const HomeScreen(),
                    'watchlist' => const WatchlistScreen(),
                    _ => const SearchScreen()
                  })
        ]);
        await $.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider<AnalyticsController>.value(
                  value: analytics),
              Provider<MovieService>.value(value: movies),
              ChangeNotifierProvider<WatchRequestCache>.value(value: plans)
            ],
            child: MaterialApp.router(
                theme: AppTheme.darkTheme, routerConfig: router)));
        await settle();
        if (scenario == 'search') {
          await $.tester.enterText(find.byType(TextField), 'a');
          FocusManager.instance.primaryFocus?.unfocus();
          await $.pump(const Duration(milliseconds: 450));
          await Future<void>.delayed(const Duration(milliseconds: 450));
          await settle();
          expect(find.textContaining('Search for', findRichText: true),
              findsOneWidget);
        }
        final mounted = memory();
        expect(mounted['image_bytes'], greaterThan(0),
            reason: 'No decoded images on $scenario');
        final vertical = find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .hitTestable()
            .first;
        final frames = <FrameTiming>[];
        void collect(List<FrameTiming> batch) => frames.addAll(batch);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        SchedulerBinding.instance.addTimingsCallback(collect);
        final offsets = <double>[];
        var peakBytes = cache.currentSizeBytes;
        final poll = Timer.periodic(const Duration(milliseconds: 20), (_) {
          if (cache.currentSizeBytes > peakBytes) {
            peakBytes = cache.currentSizeBytes;
          }
        });
        for (final direction in [-1, 1]) {
          for (var i = 0; i < 6; i++) {
            await $.tester.fling(vertical, Offset(0, direction * 350.0), 1200);
            await settle();
            offsets
                .add($.tester.state<ScrollableState>(vertical).position.pixels);
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
        SchedulerBinding.instance.removeTimingsCallback(collect);
        poll.cancel();
        expect(frames, isNotEmpty);
        expect(offsets.any((v) => v > 300), true, reason: 'No real scrolling');
        expect(client.transportErrors, isEmpty);
        expect(
            client.responses.values
                .expand((v) => v.keys)
                .every((s) => int.parse(s) < 400),
            true,
            reason: jsonEncode(client.responses));
        final scrolled = memory();
        final reads = Map<String, int>.from(images.reads);
        final requestCounts = Map<String, int>.from(requests);
        final responses = jsonDecode(jsonEncode(client.responses));
        await $.pumpWidget(const SizedBox());
        await settle();
        final unmounted = memory();
        cache.clear();
        cache.clearLiveImages();
        final cleared = memory();
        samples.add({
          'scenario': scenario,
          'repetition': repetition,
          'warmup': repetition == 0,
          'baseline': baseline,
          'mounted': mounted,
          'scrolled': scrolled,
          'unmounted': unmounted,
          'cleared': cleared,
          'peak_image_bytes': peakBytes,
          'image_file_reads': reads,
          'requests': requestCounts,
          'responses': responses,
          'offsets': offsets,
          'frames': [
            for (final f in frames)
              {
                'build_us': f.buildDuration.inMicroseconds,
                'raster_us': f.rasterDuration.inMicroseconds,
                'total_us': f.totalSpan.inMicroseconds
              }
          ]
        });
        await save(false);
        router.dispose();
        auth.dispose();
        plans.dispose();
      }
    }
    await save(true);
    ApiClient.setToken(null);
  });
}
