import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/models/movie.dart';

void main() {
  test('Movie accepts backdropUrl and trims backend whitespace', () {
    final movie = Movie.fromJson({
      'id': 1,
      'title': 'The Odyssey',
      'posterPath': '/poster.jpg',
      'backdropUrl': '/backdrop.jpg\n',
    });

    expect(movie.backdropPath, '/backdrop.jpg');
    expect(movie.posterPath, '/poster.jpg');
  });

  test('Movie prefers backdropPath when both field names are present', () {
    final movie = Movie.fromJson({
      'id': 1,
      'title': 'The Odyssey',
      'backdropPath': '/canonical.jpg',
      'backdropUrl': '/legacy.jpg',
    });

    expect(movie.backdropPath, '/canonical.jpg');
  });
}
