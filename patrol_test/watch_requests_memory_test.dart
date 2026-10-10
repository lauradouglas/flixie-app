import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import 'package:flixie_app/models/user.dart';
import 'support/runtime_database_fixture.dart';

class _RealHttp extends HttpOverrides {}

/// Separate diagnostics: service-GC requests are deliberately outside timed
/// baselines. They measure one debug isolate, not native/GPU allocation ownership.
void main() {
  patrolTest('Watch Requests post-unmount allocation diagnostic', ($) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    var active = 0;
    final client =
        RuntimeDatabaseClient(onStart: (_) => active++, onEnd: () => active--);
    // Patrol fixture transport; analyzer does not recognise this native test directory.
    // ignore: invalid_use_of_visible_for_testing_member
    ApiClient.useClientForTesting(client);
    addTearDown(() {
      // ignore: invalid_use_of_visible_for_testing_member
      ApiClient.useClientForTesting(null);
      client.close();
    });
    final manifest = await client.load('/benchmark/manifest');
    expect(manifest['database'], 'flixie_runtime_fixture');
    final viewer = manifest['smallViewer'] as String;
    ApiClient.setToken(viewer);
    final user = User.fromJson(await client.load('/benchmark/users/$viewer'));
    final vm = (await developer.Service.getInfo()).serverUri;
    expect(vm, isNotNull,
        reason: 'A debug VM service is required for heap evidence');
    final isolate = developer.Service.getIsolateId(Isolate.current)!;
    final rpc = IOClient(
        HttpOverrides.runWithHttpOverrides(() => HttpClient(), _RealHttp()));
    addTearDown(rpc.close);
    final samples = <Map<String, Object?>>[];
    Future<void> profile(String phase) async {
      final response = await rpc.get(vm!
          .resolve('getAllocationProfile')
          .replace(queryParameters: {'isolateId': isolate, 'gc': 'true'}));
      expect(response.statusCode, 200);
      final envelope = jsonDecode(response.body) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(envelope['result'] ?? envelope);
      expect(data['type'], 'AllocationProfile');
      final members = (data['members'] as List).cast<Map<String, dynamic>>();
      members.sort((a, b) =>
          (b['bytesCurrent'] as int).compareTo(a['bytesCurrent'] as int));
      samples.add({
        'phase': phase,
        'rss_bytes': ProcessInfo.currentRss,
        'image_cache_bytes':
            PaintingBinding.instance.imageCache.currentSizeBytes,
        'memoryUsage': data['memoryUsage'],
        'dateLastServiceGC': data['dateLastServiceGC'],
        'owned_classes': [
          for (final item in members)
            if ((item['class']['name'] as String).contains('WatchRequest') ||
                (item['class']['name'] as String).contains('WatchPlan'))
              {
                'name': item['class']['name'],
                'instancesCurrent': item['instancesCurrent'],
                'bytesCurrent': item['bytesCurrent']
              }
        ],
        'largest_classes': [
          for (final item in members.take(12))
            {
              'name': item['class']['name'],
              'instancesCurrent': item['instancesCurrent'],
              'bytesCurrent': item['bytesCurrent']
            }
        ],
      });
      final result = await client.post(
          Uri.parse('${ApiClient.baseUrl}/benchmark/results'),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $viewer'
          },
          body: jsonEncode({
            'complete': false,
            'method': {
              'suite': 'watch_requests_memory_diagnostic',
              'gc': 'service request; collection is attempted, not guaranteed',
              'database_manifest': manifest
            },
            'samples': samples
          }));
      expect(result.statusCode, 200);
    }

    await $.pumpWidgetAndSettle(const SizedBox.shrink());
    await profile('empty');
    for (var cycle = 1; cycle <= 5; cycle++) {
      final movies = MovieService();
      final auth = RuntimeDatabaseAuth(user, movies);
      final plans = WatchRequestCache();
      final analytics = AnalyticsController(
          backend: RuntimeAnalyticsBackend(),
          consentStore: RuntimeAnalyticsConsentStore());
      await analytics.initialize();
      await $.pumpWidgetAndSettle(MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<AnalyticsController>.value(value: analytics),
            Provider<MovieService>.value(value: movies),
            ChangeNotifierProvider<WatchRequestCache>.value(value: plans),
          ],
          child: MaterialApp(
              theme: AppTheme.darkTheme, home: const WatchRequestsScreen())));
      await $(find.text('Needs your response')).waitUntilVisible();
      await $.tester.fling(
          find
              .byWidgetPredicate((w) =>
                  w is Scrollable && w.axisDirection == AxisDirection.down)
              .hitTestable()
              .first,
          const Offset(0, -500),
          1200);
      await $.pumpAndSettle();
      for (final label in ['Past ·', 'Active ·', 'Groups ·', 'Friends ·']) {
        await $.tester.tap(find.textContaining(label).hitTestable().first);
        await $.pumpAndSettle();
      }
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (active > 0 && DateTime.now().isBefore(deadline)) {
        await $.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(active, 0);
      await $.pumpWidgetAndSettle(const SizedBox.shrink());
      auth.dispose();
      plans.dispose();
      analytics.dispose();
      movies.clearCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await $.pump(const Duration(milliseconds: 600));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await profile('unmounted_$cycle');
      expect($.tester.takeException(), isNull);
    }
    final result = await client.post(
        Uri.parse('${ApiClient.baseUrl}/benchmark/results'),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $viewer'
        },
        body: jsonEncode({
          'complete': true,
          'method': {
            'suite': 'watch_requests_memory_diagnostic',
            'gc': 'service request; collection is attempted, not guaranteed',
            'database_manifest': manifest
          },
          'samples': samples
        }));
    expect(result.statusCode, 200);
  });
}
