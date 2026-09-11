import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/storage/movie_cache_service.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/models/review.dart';

void main() {
  test(
      'refresh starts a new HTTP read and an old completion cannot repopulate metadata',
      () async {
    final service = MovieService();
    service.clearCache();
    addTearDown(service.clearCache);
    final pending = <Completer<http.Response>>[];
    await http.runWithClient(() async {
      final old = service.getMovieById(1);
      await Future<void>.delayed(Duration.zero);
      service.evictMovie(1);
      final fresh = service.getMovieById(1);
      await Future<void>.delayed(Duration.zero);
      expect(pending.length, 2);
      pending[1].complete(
          http.Response(jsonEncode({'id': 1, 'title': 'Fresh'}), 200));
      await fresh;
      pending[0]
          .complete(http.Response(jsonEncode({'id': 1, 'title': 'Old'}), 200));
      await old;
      expect((await service.getMovieById(1)).title, 'Fresh');
    },
        () => MockClient((request) {
              final response = Completer<http.Response>();
              pending.add(response);
              return response.future;
            }));
  });

  test('metadata is shared; review reactions are fetched for each viewer',
      () async {
    final service = MovieService();
    service.clearCache();
    addTearDown(service.clearCache);
    final requests = <Uri>[];
    await http.runWithClient(() async {
      await service.getMovieById(1, userId: 'a');
      await service.getMovieById(1, userId: 'b');
      await service.getMovieReviews(1, userId: 'a');
      await service.getMovieReviews(1, userId: 'b');
    },
        () => MockClient((request) async {
              requests.add(request.url);
              return http.Response(
                  jsonEncode(request.url.path.startsWith('/movies')
                      ? {'id': 1, 'title': 'Shared film'}
                      : []),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
    expect(requests.length, 3);
    expect(requests.first.queryParameters, {'includeReviews': 'false'});
    expect(requests[1].queryParameters['userId'], 'a');
    expect(requests[2].queryParameters['userId'], 'b');
    final cache = MovieCacheService();
    cache.cacheMovie(Movie(id: 1, title: 'Shared film', reviews: [
      Review.fromJson({'id': 'personal', 'myReaction': 'LOVE'})
    ]));
    expect(cache.getMovie(1)!.reviews, isEmpty);
    cache.cacheWatchProviders(1, 'GB', []);
    cache.cacheWatchProviders(1, 'US', []);
    service.evictMovie(1);
    expect(cache.getWatchProviders(1, 'GB'), isNull);
    expect(cache.getWatchProviders(1, 'US'), isNull);
  });
}
