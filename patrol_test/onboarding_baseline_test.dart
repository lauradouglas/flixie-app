import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import '../test/setup_flow_test.dart' show SetupFixture, setupApp;
import 'support/runtime_database_fixture.dart';

// Catalogue reads use the populated local database snapshot. Account writes,
// country/providers and completion remain isolated fixture operations.
class _CatalogueSetup extends SetupFixture {
  Future<List<SetupTitle>> _titles(String query, bool shows) async =>
      (await const SetupService().search(query, shows))
          .map((t) => SetupTitle(t.id, t.name, null, isShow: t.isShow))
          .toList();
  @override
  Future<List<SetupTitle>> popular(bool shows) => _titles('a', shows);
  @override
  Future<List<SetupTitle>> search(String query, bool shows) =>
      _titles(query, shows);
  @override
  Future<List<SetupTitle>> recommendations(List<SetupTitle> seeds) async =>
      (await _titles('Alien', false)).take(3).toList();
}

void main() {
  patrolTest('populated onboarding mounted baseline', ($) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final requests = <String, int>{};
    var active = 0;
    final client = RuntimeDatabaseClient(
        onStart: (key) {
          active++;
          requests.update(key, (n) => n + 1, ifAbsent: () => 1);
        },
        onEnd: () => active--);
    // Patrol runs outside test/, but this is isolated test-only networking.
    // ignore: invalid_use_of_visible_for_testing_member
    ApiClient.useClientForTesting(client);
    ApiClient.setToken('runtime-fixture-0');
    addTearDown(() {
      // ignore: invalid_use_of_visible_for_testing_member
      ApiClient.useClientForTesting(null);
      ApiClient.setToken(null);
      client.close();
    });
    final manifest = await client.load('/benchmark/manifest');
    expect(manifest['database'], 'flixie_runtime_fixture');
    expect((manifest['search'] as Map)['entries'], greaterThan(1000));
    final samples = <Map<String, Object?>>[];
    Future<void> settle() async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      await $.pump(const Duration(milliseconds: 100));
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pump();
      while (active > 0) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Onboarding API did not settle');
        }
        await $.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await $.pumpAndSettle();
    }

    Future<void> tap(String label) async {
      final text = find.text(label).first;
      await $.tester.ensureVisible(text);
      await $.tester.tap(text);
      await settle();
    }

    for (var run = 0; run <= 5; run++) {
      await $.pumpWidgetAndSettle(const MaterialApp(home: SizedBox()));
      debugPrint('ONBOARDING_RUN $run');
      final fixture = _CatalogueSetup();
      requests.clear();
      client.responses.clear();
      client.transportErrors.clear();
      final frames = <FrameTiming>[];
      void collect(List<FrameTiming> batch) => frames.addAll(batch);
      SchedulerBinding.instance.addTimingsCallback(collect);
      final rssStart = ProcessInfo.currentRss;
      final watch = Stopwatch()..start();
      await $.pumpWidget(setupApp(fixture));
      await settle();
      expect(
          find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('taste-movie:')),
          findsWidgets);
      final useful = watch.elapsedMicroseconds;
      await $.tester.tap(find.byType(TextField).first);
      await $.pump();
      await $.tester.enterText(find.byType(TextField).first, 'Alien');
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pump(const Duration(milliseconds: 450));
      await Future<void>.delayed(const Duration(milliseconds: 450));
      await settle();
      expect(find.byKey(const ValueKey('taste-movie:348')), findsOneWidget);
      await $.tester
          .ensureVisible(find.byKey(const ValueKey('taste-movie:348')));
      await $.tester.tap(find.byKey(const ValueKey('taste-movie:348')));
      await settle();
      await tap('Shows');
      expect(find.byKey(const ValueKey('taste-show:157239')), findsOneWidget);
      await $.tester
          .ensureVisible(find.byKey(const ValueKey('taste-show:157239')));
      await $.tester.tap(find.byKey(const ValueKey('taste-show:157239')));
      await settle();
      await tap('Continue');
      expect(fixture.taste.map((t) => t.key), ['movie:348', 'show:157239']);
      await tap('Choose country');
      await tap('United Kingdom');
      await tap('Show my first picks');
      await tap('Add to watchlist');
      expect(fixture.added, hasLength(1));
      await tap('Continue to favourites');
      await tap('Skip favourites');
      await tap('I’ll explore on my own');
      expect(find.text('Home destination'), findsOneWidget);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await $.pump();
      SchedulerBinding.instance.removeTimingsCallback(collect);
      expect(client.transportErrors, isEmpty);
      expect(requests, {'GET /search': 4});
      expect(client.responses, {
        'GET /search': {'200': 4}
      });
      if (run > 0) {
        samples.add({
          'run': run,
          'useful_us': useful,
          'journey_us': watch.elapsedMicroseconds,
          'rss_start_bytes': rssStart,
          'rss_end_bytes': ProcessInfo.currentRss,
          'frame_build_us':
              frames.map((f) => f.buildDuration.inMicroseconds).toList(),
          'frame_raster_us':
              frames.map((f) => f.rasterDuration.inMicroseconds).toList(),
          'requests': Map.of(requests),
          'responses': jsonDecode(jsonEncode(client.responses)),
          'saved_taste': fixture.taste.map((t) => t.key).toList(),
          'watchlist_adds': fixture.added.length,
        });
      }
    }
    final response = await client.post(
        Uri.parse('${ApiClient.baseUrl}/benchmark/results'),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer runtime-fixture-0'
        },
        body: jsonEncode({
          'complete': true,
          'method': {
            'suite': 'onboarding',
            'manifest': manifest,
            'scope':
                'Mounted debug UI; catalogue database snapshot reads; no images; account writes and reference data are fixtures; excludes bootstrap/auth and production recommendation latency',
            'warmups': 1
          },
          'samples': samples
        }));
    expect(response.statusCode, 200);
  });
}
