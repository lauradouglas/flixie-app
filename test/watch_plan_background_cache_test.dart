import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'home_watch_plan_retrieval_test.dart' show plan;

http.Response response(Object body, [int code = 200]) =>
    http.Response(jsonEncode(body), code);
void main() {
  tearDown(() => ApiClient.useClientForTesting(null));
  test('both active snapshots expire after thirty seconds', () async {
    var now = DateTime(2026, 9, 23);
    final cache = WatchRequestCache(now: () => now);
    addTearDown(cache.dispose);
    var calls = 0;
    ApiClient.useClientForTesting(MockClient((request) async {
      calls++;
      return request.url.path.startsWith('/groups/')
          ? response({'groups': []})
          : response([]);
    }));
    cache.syncUser('laura');
    await Future.wait(
        [cache.refreshDirect(force: false), cache.refreshHome(force: false)]);
    expect(calls, 2);
    now = now.add(const Duration(seconds: 31));
    await Future.wait(
        [cache.refreshDirect(force: false), cache.refreshHome(force: false)]);
    expect(calls, 4);
  });
  test('sign-in warms both active sources and freshness avoids duplicate reads',
      () async {
    final cache = WatchRequestCache();
    addTearDown(cache.dispose);
    final direct = Completer<http.Response>();
    var directCalls = 0, groupCalls = 0;
    ApiClient.useClientForTesting(MockClient((request) {
      if (request.url.path.startsWith('/requests/')) {
        directCalls++;
        expect(request.url.queryParameters['activeOnly'], 'true');
        return direct.future;
      }
      groupCalls++;
      return Future.value(response({'groups': []}));
    }));
    cache.syncUser('laura');
    final loading = cache.refreshDirect(force: false);
    direct.complete(response([
      plan('active'),
      {...plan('completed'), 'watchedStatus': 'WATCHED'}
    ]));
    await loading;
    await cache.refreshHome(force: false);
    expect(cache.direct.map((p) => p.id), ['active']);
    await cache.refreshDirect(force: false);
    await cache.refreshHome(force: false);
    expect(directCalls, 1);
    expect(groupCalls, 1);
  });
  test(
      'background check replaces old plans, transient failures retain them, access denial clears',
      () async {
    final cache = WatchRequestCache();
    addTearDown(cache.dispose);
    var mode = 0;
    final changed = Completer<http.Response>();
    ApiClient.useClientForTesting(MockClient((r) async {
      if (r.url.path.startsWith('/groups/')) return response({'groups': []});
      if (mode == 1) return changed.future;
      if (mode == 2) return response({}, 400);
      if (mode == 3) return response({}, 403);
      return response([plan('old')]);
    }));
    cache.syncUser('laura');
    await cache.refreshDirect();
    mode = 1;
    final refresh = cache.refreshDirect();
    expect(cache.direct.single.id, 'old');
    changed.complete(response([plan('new')]));
    await refresh;
    expect(cache.direct.single.id, 'new');
    mode = 2;
    await expectLater(cache.refreshDirect(), throwsException);
    expect(cache.direct.single.id, 'new');
    mode = 3;
    await expectLater(cache.refreshDirect(), throwsException);
    expect(cache.direct, isEmpty);
  });
  test('late response cannot restore another account plans', () async {
    final cache = WatchRequestCache();
    addTearDown(cache.dispose);
    final old = Completer<http.Response>();
    ApiClient.useClientForTesting(MockClient((r) {
      if (r.url.path.startsWith('/groups/')) {
        return Future.value(response({'groups': []}));
      }
      return r.url.path.contains('/old/')
          ? old.future
          : Future.value(response([]));
    }));
    cache.syncUser('old');
    final previous = cache.refreshDirect();
    cache.syncUser('new');
    await cache.refreshDirect();
    old.complete(response([plan('private')]));
    await previous;
    expect(cache.direct, isEmpty);
    cache.syncUser(null);
    expect(cache.direct, isEmpty);
    expect(cache.hasDirectSnapshot, isFalse);
  });
}
