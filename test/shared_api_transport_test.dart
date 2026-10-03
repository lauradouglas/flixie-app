import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';

class _Transport extends MockClient {
  _Transport(super.handler);
  bool closed = false;
  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  tearDown(() {
    ApiClient.useClientForTesting(null);
    ApiClient.closeTransport();
    ApiClient.setToken(null);
  });
  test(
      'app transport serves successive verbs with fresh credentials until shutdown',
      () async {
    final headers = <String?>[];
    final verbs = <String>[];
    final transport = _Transport((request) async {
      headers.add(request.headers['Authorization']);
      verbs.add(request.method);
      return http.Response('{}', 200);
    });
    ApiClient.initializeTransport(client: transport);
    ApiClient.setToken('fixture-one');
    await ApiClient.get('/fixture');
    ApiClient.setToken('fixture-two');
    await ApiClient.post('/fixture');
    await ApiClient.put('/fixture');
    await ApiClient.patch('/fixture');
    await ApiClient.delete('/fixture');
    expect(verbs, ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']);
    expect(headers,
        ['Bearer fixture-one', ...List.filled(4, 'Bearer fixture-two')]);
    expect(transport.closed, false);
    ApiClient.closeTransport();
    expect(transport.closed, true);
  });
  test(
      'fixture override takes precedence and restoring it retains app transport',
      () async {
    ApiClient.initializeTransport(
        client: MockClient((_) async => http.Response('{"app":true}', 200)));
    ApiClient.useClientForTesting(
        MockClient((_) async => http.Response('{"fixture":true}', 200)));
    expect(await ApiClient.get('/fixture'), {'fixture': true});
    ApiClient.useClientForTesting(null);
    expect(await ApiClient.get('/fixture'), {'app': true});
  });
}
