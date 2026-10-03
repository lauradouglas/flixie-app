import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/social/data/activity_state_batch.dart';

void main() {
  setUp(ActivityStateBatch.clear);
  tearDown(() {
    ActivityStateBatch.clear();
    ApiClient.useClientForTesting(null);
  });
  Future<Map<String, dynamic>> load(String id, {String viewer = 'viewer'}) =>
      ActivityStateBatch.load(
          viewer: viewer,
          owner: 'friend',
          type: 'movie-review',
          id: id,
          community: true);
  http.Response response(List targets) => http.Response(
      jsonEncode({
        'items': [
          for (final target in targets)
            {
              ...target,
              'reactions': {
                'counts': {'❤️': 2},
                'mine': null
              },
              'saved': true
            }
        ]
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'});

  test(
      '30 cards and duplicate bookmark reads share one request and viewer cache',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.url.path, '/community/activity-state');
      final targets = jsonDecode(request.body)['targets'] as List;
      expect(targets.length, 30);
      return response(targets);
    });
    ApiClient.useClientForTesting(client);
    addTearDown(client.close);
    final results = await Future.wait([
      for (var i = 0; i < 30; i++) ...[load('$i'), load('$i')]
    ]);
    expect(calls, 1);
    expect(results.every((row) => row['saved'] == true), isTrue);
    await load('0');
    expect(calls, 1);
  });
  test('large visible sets are split into at most 50 targets per request',
      () async {
    final sizes = <int>[];
    final client = MockClient((request) async {
      final targets = jsonDecode(request.body)['targets'] as List;
      sizes.add(targets.length);
      return response(targets);
    });
    ApiClient.useClientForTesting(client);
    addTearDown(client.close);
    await Future.wait([for (var i = 0; i < 75; i++) load('$i')]);
    expect(sizes, [50, 25]);
  });
  test('an old account response cannot populate the new account cache',
      () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) {
        started.complete();
        return pending.future;
      }
      return response(jsonDecode(request.body)['targets'] as List);
    });
    ApiClient.useClientForTesting(client);
    addTearDown(client.close);
    final old = load('same');
    final oldFails = expectLater(old, throwsStateError);
    await started.future;
    final current = await load('same', viewer: 'another');
    pending.complete(response([]));
    await oldFails;
    expect(current['saved'], true);
    await load('same', viewer: 'another');
    expect(calls, 2);
  });
  test('only an absent batch endpoint falls back; denial never fans out',
      () async {
    var absent = true;
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      if (request.method == 'POST')
        return http.Response('{}', absent ? 404 : 403);
      return http.Response(
          jsonEncode(request.url.path.endsWith('/bookmark')
              ? {'saved': false}
              : {'counts': {}, 'mine': null}),
          200);
    });
    ApiClient.useClientForTesting(client);
    addTearDown(client.close);
    expect((await load('old-server'))['saved'], false);
    expect(paths.length, 3);
    ActivityStateBatch.clear();
    absent = false;
    paths.clear();
    await expectLater(load('denied'), throwsA(isA<ApiException>()));
    expect(paths, ['/community/activity-state']);
  });
  test('missing authorized target is not cached as empty reactions', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return response([]);
    });
    ApiClient.useClientForTesting(client);
    addTearDown(client.close);
    await expectLater(load('removed'), throwsStateError);
    await expectLater(load('removed'), throwsStateError);
    expect(calls, 2);
  });
}
