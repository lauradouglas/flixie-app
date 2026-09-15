import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/user.dart';

void main() {
  final cached = User.fromJson({
    'id': 'viewer',
    'countryId': 1,
    'showWatchlist': [
      {'showId': 42}
    ],
    'movieWatchlist': [],
    'watchedShows': [
      {'showId': 21}
    ]
  });
  test('country update preserves omitted saved collections', () {
    final updated = User.fromJson({'id': 'viewer', 'countryId': 2})
        .preservingCollectionsFrom(cached);
    expect(updated.countryId, 2);
    expect(updated.showWatchlist, cached.showWatchlist);
    expect(updated.movieWatchlist, cached.movieWatchlist);
    expect(updated.watchedShows, cached.watchedShows);
  });
  test('explicit empty collections replace cached values', () {
    final updated = User.fromJson({'id': 'viewer', 'showWatchlist': []})
        .preservingCollectionsFrom(cached);
    expect(updated.showWatchlist, isEmpty);
  });
  test('does not copy collections between accounts', () {
    final updated =
        User.fromJson({'id': 'other'}).preservingCollectionsFrom(cached);
    expect(updated.showWatchlist, isNull);
  });
}
