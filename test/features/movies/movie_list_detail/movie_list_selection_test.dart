import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/movie_list_movie.dart';
import 'package:flixie_app/features/movies/presentation/movie_list_selection.dart';
import '../../../../patrol_test/support/movie_list_detail_fixture.dart';

void main() {
  test('all sort modes preserve source ordering and contributor badges', () {
    final source = [
      MovieListMovie.fromJson(listEntry(1, 'The Odyssey', contributor: 'Zed')),
      MovieListMovie.fromJson({
        ...listEntry(1, 'Alien: Earth', show: true, contributor: 'Amy'),
        'createdAt': '2026-10-02T00:00:00Z'
      })
    ];
    for (final mode in MovieListSort.values) {
      final result = sortedMovieList(source, mode);
      expect(result, hasLength(2));
      expect(identical(result, source), isFalse);
    }
    expect(sortedMovieList(source, MovieListSort.title).first.showId, 1);
    expect(
        sortedMovieList(source, MovieListSort.recentlyAdded).first.showId, 1);
    expect(
        movieListContributors(source).map((c) => c.username), ['Amy', 'Zed']);
    expect(
        movieListContributors(source)
            .every((c) => c.profileBadges.contains('EARLY_ADOPTER')),
        isTrue);
    expect(source.first.movieId, 1);
    expect(source.first.showId, 0);
  });
}
