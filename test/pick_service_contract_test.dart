import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/pick_for_us/pick_for_us_screen.dart';
import 'support/api_fixture.dart';

void main() {
  test(
      'picker sends selected mood and optional session exclusions without changing defaults',
      () async {
    final requests = <Map<String, dynamic>>[];
    useApiFixture(MockClient((request) async {
      expect(request.url.path, '/recommendations/pick-for-us');
      requests.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode({'choices': [], 'message': null}), 200,
          headers: {'content-type': 'application/json'});
    }));
    final service = PickForUsService();
    await service.pick(
        maxMinutes: 120,
        mood: 'hooked',
        venue: 'streaming',
        watching: 'together',
        openToRent: false);
    await service.pick(
        maxMinutes: 150,
        mood: 'feel_good',
        venue: 'streaming',
        watching: 'together',
        openToRent: false,
        excludeMovieIds: {348, 571},
        genreIds: [35, 10749],
        avoid: {'violence'});
    expect(requests.first.containsKey('excludeMovieIds'), false);
    expect(requests.first['mood'], 'hooked');
    expect(requests.last['excludeMovieIds'], [348, 571]);
    expect(requests.last['mood'], 'feel_good');
    expect(requests.last['genreIds'], [35, 10749]);
    expect(requests.last['avoid'], ['violence']);
    expect(requests.last['includeUnknownContent'], false);
  });
}
