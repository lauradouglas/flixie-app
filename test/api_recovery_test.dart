import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';

void main() {
  tearDown(() {
    ApiClient.setAuthTokenRefresher(null);
    ApiClient.setToken(null);
  });
  testWidgets(
      'shared hung refresh times out, releases GETs, retries, ignores late token',
      (tester) async {
    var refreshes = 0;
    var requests = 0;
    final held = Completer<String>();
    ApiClient.setToken('old');
    ApiClient.setAuthTokenRefresher(() {
      refreshes++;
      return refreshes == 1 ? held.future : Future.value('fresh');
    });
    await http.runWithClient(() async {
      final first = ApiClient.get('/recovery');
      final second = ApiClient.get('/recovery');
      expect(identical(first, second), true);
      final failed = expectLater(first, throwsA(isA<TimeoutException>()));
      await tester.pump();
      expect(refreshes, 1);
      expect(requests, 1);
      await tester.pump(const Duration(seconds: 8));
      await failed;
      final recovered = await ApiClient.get('/recovery');
      expect(refreshes, 2);
      expect(recovered, {'ok': true});
      expect(ApiClient.getToken(), 'fresh');
      held.complete('late');
      await tester.pump();
      expect(ApiClient.getToken(), 'fresh');
    },
        () => MockClient((request) async {
              requests++;
              return request.headers['Authorization'] == 'Bearer fresh'
                  ? http.Response('{"ok":true}', 200)
                  : http.Response('expired', 401);
            }));
  });
  testWidgets(
      'old account requests cannot retry or return data under new account',
      (tester) async {
    final held = Completer<http.Response>();
    var calls = 0;
    var refreshes = 0;
    ApiClient.setToken('A');
    ApiClient.setAuthTokenRefresher(() async {
      refreshes++;
      return 'new';
    });
    await http.runWithClient(() async {
      final old = ApiClient.get('/profile');
      final fails = expectLater(old, throwsStateError);
      await tester.pump();
      ApiClient.setToken(null);
      ApiClient.setToken('B');
      final current = await ApiClient.get('/profile');
      expect(current, {'user': 'B'});
      held.complete(http.Response('expired', 401));
      await tester.pump();
      await fails;
      expect(calls, 2);
      expect(refreshes, 0);
      expect(ApiClient.getToken(), 'B');
    },
        () => MockClient((request) async {
              calls++;
              return calls == 1
                  ? await held.future
                  : http.Response('{"user":"B"}', 200);
            }));
  });
}
