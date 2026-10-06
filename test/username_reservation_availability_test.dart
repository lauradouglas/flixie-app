import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';

void main() {
  tearDown(() {
    ApiClient.setToken(null);
    ApiClient.useClientForTesting(null);
  });

  test('anonymous signup checks reservations without a token', () async {
    ApiClient.setToken(null);
    ApiClient.useClientForTesting(MockClient((request) async {
      expect(request.url.path, '/users/jessg/exists');
      expect(request.headers['Authorization'], isNull);
      return http.Response('true', 200);
    }));
    expect(await UserService.usernameExists('jessg'), isTrue);
  });

  test('signed-in checks include identity so the owner can select a reservation',
      () async {
    ApiClient.setToken('fixture-owner-token');
    ApiClient.useClientForTesting(MockClient((request) async {
      expect(request.url.path, '/users/jessg/exists');
      expect(request.headers['Authorization'], 'Bearer fixture-owner-token');
      return http.Response('false', 200);
    }));
    expect(await UserService.usernameExists('jessg'), isFalse);
  });
}
