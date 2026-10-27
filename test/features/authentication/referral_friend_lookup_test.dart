import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import '../../support/api_fixture.dart';

void main() {
  test('referral shortcut resolves the exact username with the supported route', () async {
    final paths = <String>[];
    useApiFixture(MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(jsonEncode({'id': 'inviter-id', 'username': 'Dougasaur'}), 200);
    }));
    expect(await const SetupService().friendId('@Dougasaur'), 'inviter-id');
    expect(paths, ['/users/username/Dougasaur']);
  });
  test('removed referrer falls back without treating setup as a failed save', () async {
    useApiFixture(MockClient((_) async => http.Response('{"error":"User not found"}', 404)));
    expect(await const SetupService().friendId('Dougasaur'), isNull);
  });
  test('temporary lookup failure remains retryable rather than reporting no friend', () async {
    useApiFixture(MockClient((_) async => http.Response('{"error":"Unavailable"}', 503)));
    await expectLater(const SetupService().friendId('Dougasaur'), throwsA(isA<ApiException>()));
  });
}
