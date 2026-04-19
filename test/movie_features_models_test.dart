import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/movie_wrapped.dart';

void main() {
  group('MovieList', () {
    test('parses create-list response shape', () {
      final model = MovieList.fromJson({
        'id': 'list-1',
        'userId': 'user-1',
        'name': 'Date Night',
        'removed': false,
        'createdAt': '2025-01-01T00:00:00.000Z',
        'updatedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(model.name, 'Date Night');
      expect(model.removed, isFalse);
    });
  });

  group('MovieWatchEntry', () {
    test('supports nullable rating/notes', () {
      final model = MovieWatchEntry.fromJson({
        'id': 'watch-1',
        'userId': 'user-1',
        'movieId': 550,
        'watchedAt': '2025-08-10T20:00:00.000Z',
        'rating': null,
        'notes': null,
        'removed': false,
      });
      expect(model.movieId, 550);
      expect(model.rating, isNull);
      expect(model.notes, isNull);
    });
  });

  group('MovieWrapped', () {
    test('sorts monthly buckets ascending', () {
      final wrapped = MovieWrapped.fromJson({
        'year': 2025,
        'totalMoviesWatched': 10,
        'rewatchCount': 2,
        'totalHoursWatched': 20.0,
        'monthlyWatchCounts': [
          {'month': 12, 'count': 1},
          {'month': 1, 'count': 3},
        ],
      });
      expect(wrapped.monthlyWatchCounts.map((e) => e.month).toList(), [1, 12]);
    });
  });
}
