import 'package:flutter_test/flutter_test.dart';
import '../tool/runtime_fixture_endpoint.dart';

void main() {
  test('simulator localhost and paired private IPv6 fixture are allowed', () {
    expect(
        isRuntimeFixtureEndpoint('http://127.0.0.1:3007', '127.0.0.1'), true);
    expect(
        isRuntimeFixtureEndpoint(
            'http://[fd29:c5c4:d6fb::2]:3007', 'fd29:c5c4:d6fb::2'),
        true);
  });
  test('private Wi-Fi fixture addresses are allowed', () {
    for (final host in ['10.0.0.2', '172.16.0.2', '172.31.255.2', '192.168.1.203']) {
      expect(isRuntimeFixtureEndpoint('http://$host:3007', host), true);
    }
  });
  test('production, public addresses, wrong host/port/path are rejected', () {
    for (final host in ['example.com', '8.8.8.8', '172.15.0.2', '172.32.0.2', '169.254.1.2', '2001:4860:4860::8888']) {
      expect(
          isRuntimeFixtureEndpoint(
              Uri(scheme: 'http', host: host, port: 3007).toString(), host),
          false);
    }
    for (final url in [
      'https://127.0.0.1:3007',
      'http://127.0.0.1:3008',
      'http://127.0.0.1:3007/api',
      'http://127.0.0.1:3007#other',
      'http://127.0.0.1:3007?production=true',
      'http://user@127.0.0.1:3007',
      'http://192.168.1.1:3007'
    ]) {
      expect(isRuntimeFixtureEndpoint(url, '127.0.0.1'), false);
    }
  });
}
