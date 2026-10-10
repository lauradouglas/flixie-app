import 'dart:async';
import 'package:flixie_app/core/auth/startup_trace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';

void main() {
  test('Home timing captures numeric phases without recording private paths',
      () async {
    final events = <Map<String, Object?>>[];
    StartupTrace.observer = events.add;
    ApiClient.useClientForTesting(MockClient((request) async => http.Response(
          '{"plans":[]}',
          200,
          headers: {'server-timing': 'app;dur=12.5, data;dur=8.2'},
        )));
    addTearDown(() {
      StartupTrace.observer = null;
      ApiClient.useClientForTesting(null);
    });
    expect(await ApiClient.get('/requests/private-account/all'), {'plans': []});
    final response = events
        .singleWhere((e) => e['phase'] == 'api.home-plans-direct.response');
    expect(response['status'], 200);
    expect(response['appMs'], 12.5);
    expect(response['dataMs'], 8.2);
    expect(events.toString(), isNot(contains('private-account')));
    expect(
        events
            .where((e) => e['phase'] == 'api.home-plans-direct.decode')
            .map((e) => e['kind']),
        ['start', 'end']);
  });
  test(
      'native fixture client covers every verb outside its zone and restores normal networking',
      () async {
    final methods = <String>[];
    final client = MockClient((request) async {
      methods.add(request.method);
      return http.Response('{"fixture":true}', 200);
    });
    ApiClient.useClientForTesting(client);
    addTearDown(() {
      ApiClient.useClientForTesting(null);
      client.close();
    });
    final operations = [
      () => ApiClient.get('/fixture'),
      () => ApiClient.post('/fixture', body: {'id': 1}),
      () => ApiClient.put('/fixture', body: {'id': 1}),
      () => ApiClient.patch('/fixture', body: {'id': 1}),
      () => ApiClient.delete('/fixture', body: {'id': 1}),
    ];
    for (final operation in operations) {
      expect(await Zone.root.run(operation), {'fixture': true});
    }
    expect(methods, ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']);
    ApiClient.useClientForTesting(null);
    await http.runWithClient(() async {
      expect(await ApiClient.get('/fixture'), {'fixture': false});
    },
        () => MockClient(
            (request) async => http.Response('{"fixture":false}', 200)));
    expect(methods.length, 5);
  });
}
