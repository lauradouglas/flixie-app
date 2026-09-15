import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/show_watch_entry.dart';

void main() {
  test('an undated watch never uses its creation timestamp as a viewing date',
      () {
    final json = <String, dynamic>{
      'id': 'watch',
      'userId': 'user',
      'movieId': 603,
      'showId': 1396,
      'watchedAt': null,
      'createdAt': '2026-09-15T12:00:00Z',
      'rating': 8
    };
    final movie = MovieWatchEntry.fromJson(json);
    expect(movie.watchedAt, isNull);
    expect(movie.toJson()['watchedAt'], isNull);
    expect(movie.rating, 8);
    expect(ShowWatchEntry.fromJson(json).watchedAt, isNull);
  });
  test('a Watch Plan watch-entry payload keeps rating and recommendation', () {
    final payload = const LogMovieWatchRequest(
      movieId: 123,
      watchedAt: '2026-08-30T20:00:00.000Z',
      rating: 8,
      recommended: true,
      notes: 'A great group watch.',
    ).toJson();

    expect(payload['movieId'], 123);
    expect(payload['rating'], 8);
    expect(payload['recommended'], isTrue);
    expect(payload['notes'], 'A great group watch.');
  });
}
