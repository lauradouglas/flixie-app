import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import 'package:flixie_app/features/home/data/recommendation_service.dart';

http.Response response(Object value) => http.Response(jsonEncode(value), 200,
    headers: {'content-type': 'application/json'});
Map<String, Object> movie(int id) =>
    {'id': id, 'name': 'Alien $id', 'title': 'Alien $id'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RecommendationService.invalidateCache();
  });
  tearDown(() {
    RecommendationService.invalidateCache();
    ApiClient.useClientForTesting(null);
  });

  test(
      'feed and seed calls overlap, preserve exclusions, and refresh reuses seed ordering',
      () async {
    await SetupTasteStore.save(
        'viewer', [const SetupTitle(91001, 'Alien', null)]);
    final feedGate = Completer<void>();
    final seedStarted = Completer<void>();
    int feeds = 0, seeds = 0;
    ApiClient.useClientForTesting(MockClient((request) async {
      if (request.url.path == '/users/viewer/recommendations') {
        feeds++;
        if (feeds > 1) {
          expect(request.url.queryParameters,
              {'refresh': 'true', 'refreshProfile': 'false'});
        }
        await feedGate.future;
        return response([movie(1), movie(2)]);
      }
      expect(request.url.path, '/movies/91001/recommendations');
      seeds++;
      seedStarted.complete();
      return response([movie(2), movie(99)]);
    }));
    final results = List.generate(
        20, (_) => RecommendationService.getUserRecommendations('viewer'));
    await seedStarted.future.timeout(const Duration(seconds: 2));
    expect(feeds, 1); // Seed work began while feed response is still blocked.
    feedGate.complete();
    for (final result in await Future.wait(results)) {
      expect(result.map((m) => m.id),
          [2, 1]); // Excluded seed 99 is never inserted.
    }
    await RecommendationService.getUserRecommendations('viewer', refresh: true);
    expect(feeds, 2);
    expect(seeds, 1);
  });

  test('changed onboarding choices invalidate ordering on the next refresh',
      () async {
    await SetupTasteStore.save(
        'viewer', [const SetupTitle(91002, 'Alien', null)]);
    final seedPaths = <String>[];
    ApiClient.useClientForTesting(MockClient((request) async {
      if (request.url.path.startsWith('/users/')) {
        return response([movie(1), movie(2)]);
      }
      seedPaths.add(request.url.path);
      return response([movie(request.url.path.contains('91002') ? 2 : 1)]);
    }));
    expect(
        (await RecommendationService.getUserRecommendations('viewer')).first.id,
        2);
    await SetupTasteStore.save(
        'viewer', [const SetupTitle(91003, 'Spider-Man', null)]);
    expect(
        (await RecommendationService.getUserRecommendations('viewer',
                refresh: true))
            .first
            .id,
        1);
    expect(seedPaths.length, 2);
  });

  test(
      'invalidation during a load prevents obsolete results from refilling cache',
      () async {
    final old = Completer<void>();
    var calls = 0;
    ApiClient.useClientForTesting(MockClient((request) async {
      final call = ++calls;
      if (call == 1) await old.future;
      return response([movie(call)]);
    }));
    final first = RecommendationService.getUserRecommendations('viewer');
    final obsolete = expectLater(first, throwsA(isA<StateError>()));
    await Future<void>.delayed(Duration.zero);
    RecommendationService.invalidateCache(userId: 'viewer');
    expect(
        (await RecommendationService.getUserRecommendations('viewer'))
            .single
            .id,
        2);
    old.complete();
    await obsolete;
    expect(
        (await RecommendationService.getUserRecommendations('viewer'))
            .single
            .id,
        2);
    expect(calls, 2);
  });

  test(
      'failed feed calculation is retryable and optional seed failure retains server results',
      () async {
    await SetupTasteStore.save(
        'viewer', [const SetupTitle(91004, 'Alien', null)]);
    var calls = 0;
    ApiClient.useClientForTesting(MockClient((request) async {
      if (request.url.path.startsWith('/movies/')) {
        return http.Response('{}', 403);
      }
      calls++;
      if (calls == 1) return http.Response('{}', 403);
      return response([movie(1)]);
    }));
    await expectLater(RecommendationService.getUserRecommendations('viewer'),
        throwsA(isA<ApiException>()));
    expect(
        (await RecommendationService.getUserRecommendations('viewer'))
            .single
            .id,
        1);
  });
  test('account change rejects a late response and isolates the next account',
      () async {
    final gate = Completer<void>();
    final started = Completer<void>();
    ApiClient.setToken('fictional-first');
    addTearDown(() => ApiClient.setToken(null));
    ApiClient.useClientForTesting(MockClient((request) async {
      if (request.url.path.contains('/first/')) {
        started.complete();
        await gate.future;
        return response([movie(1)]);
      }
      return response([movie(2)]);
    }));
    final first = RecommendationService.getUserRecommendations('first');
    final rejected = expectLater(first, throwsA(isA<StateError>()));
    await started.future;
    ApiClient.setToken(null);
    ApiClient.setToken('fictional-second');
    expect(
        (await RecommendationService.getUserRecommendations('second'))
            .single
            .id,
        2);
    gate.complete();
    await rejected;
    expect(
        (await RecommendationService.getUserRecommendations('second'))
            .single
            .id,
        2);
  });
  test('a watched-film invalidation regenerates an ordinary Home reload',
      () async {
    var watched = false;
    final refreshes = <bool>[];
    ApiClient.useClientForTesting(MockClient((request) async {
      final refresh = request.url.queryParameters['refresh'] == 'true';
      refreshes.add(refresh);
      // Model the server cache: without refresh the watched film remains cached.
      return response([movie(watched && refresh ? 2 : 1)]);
    }));
    expect(
        (await RecommendationService.getUserRecommendations('viewer'))
            .single
            .id,
        1);
    watched = true;
    RecommendationService.invalidateCache(userId: 'viewer');
    expect(
        (await RecommendationService.getUserRecommendations('viewer'))
            .single
            .id,
        2);
    expect(
        (await RecommendationService.getUserRecommendations('viewer'))
            .single
            .id,
        2);
    expect(refreshes, [false, true]);
  });
}
