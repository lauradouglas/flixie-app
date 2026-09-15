import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/movie_wrapped.dart';

void main() {
  test('older wrapped responses do not invent profile insights', () {
    final stats = MovieWrapped.fromJson({'year': 2026, 'totalWatchCount': 14});
    expect(stats.insights, isNull);
    expect(stats.rewatchCount, 14);
  });
  test('new profile insights preserve zeroes and milestone data', () {
    final stats = MovieWrapped.fromJson({
      'year': 2026,
      'insights': {
        'monthMovies': 0,
        'monthEpisodes': 18,
        'milestone': {'count': 100, 'reachedAt': '2026-08-10T00:00:00Z'},
        'distribution': [0,0,0,0,0,0,2,0,0,0],
      },
    });
    expect(stats.insights!['monthMovies'], 0);
    expect(stats.insights!['monthEpisodes'], 18);
    expect(stats.insights!['milestone']['count'], 100);
    expect(stats.insights!['distribution'][6], 2);
  });
}
