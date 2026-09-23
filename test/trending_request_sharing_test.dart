import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/home/data/trending_service.dart';

void main() {
  test('startup callers share one pending trending request', () async {
    final response = Completer<http.Response>();
    var calls = 0;
    await http.runWithClient(() async {
      final first = TrendingService.getTrendingMovies(refresh: true);
      final second = TrendingService.getTrendingMovies(refresh: true);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      response.complete(http.Response('[{"id":123,"title":"Fixture"}]', 200));
      expect((await first).single.id, 123);
      expect((await second).single.id, 123);
      await TrendingService.getTrendingMovies(refresh: true);
      expect(calls, 2, reason: 'completed requests must not block refresh');
    },
        () => MockClient((request) {
              expect(request.url.path, '/trending/movie/day');
              calls++;
              return response.future;
            }));
  });
}
