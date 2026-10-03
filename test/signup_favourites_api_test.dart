import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import 'support/api_fixture.dart';

void main() {
  test(
      'explicit favourite save precedes forced server taste refresh without changing sharing',
      () async {
    final calls = <String>[];
    useApiFixture(MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/movies/favorites')) {
        expect(jsonDecode(request.body), {
          'movieIds': [348]
        });
        return http.Response(
            jsonEncode([
              {'movieId': 348}
            ]),
            200);
      }
      expect(request.url.path, '/users/fictional-signup/recommendations');
      expect(request.url.queryParameters, {'refresh': 'true'});
      return http.Response(
          jsonEncode([
            {'id': 1368337, 'title': 'The Odyssey', 'posterPath': null}
          ]),
          200);
    }));
    const service = SetupService();
    await service.addProfileFavourite(
        'fictional-signup', const SetupTitle(348, 'Alien', null));
    final recommendations =
        await service.favouriteRecommendations('fictional-signup');
    expect(recommendations.single.id, 1368337);
    expect(calls, [
      'POST /users/fictional-signup/movies/favorites',
      'GET /users/fictional-signup/recommendations'
    ]);
  });
}
