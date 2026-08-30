import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';

void main() {
  test('a Watch Plan watch-entry payload keeps rating and recommendation', () {
    final payload = LogMovieWatchRequest(
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
