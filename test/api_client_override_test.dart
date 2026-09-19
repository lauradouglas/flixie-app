import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';

void main() {
  test('native fixture client covers every verb outside its zone and restores normal networking', () async {
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
    }, () => MockClient((request) async => http.Response('{"fixture":false}', 200)));
    expect(methods.length, 5);
  });
}
