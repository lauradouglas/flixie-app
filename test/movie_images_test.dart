import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/movie_images.dart';

void main() {
  test('parses movie image groups and builds TMDB URLs', () {
    final images = MovieImages.fromJson({
      'backdrops': [
        {
          'movieId': 12,
          'aspectRatio': 1.778,
          'height': 1080,
          'width': 1920,
          'imageUrl': '/backdrop.jpg',
        },
      ],
      'posters': [
        {
          'movieId': 12,
          'aspectRatio': 0.667,
          'height': 1500,
          'width': 1000,
          'imageUrl': '/poster.jpg',
        },
      ],
      'logos': [],
    });

    expect(images.gallery, hasLength(2));
    expect(
      images.gallery.first.thumbnailUrl,
      'https://image.tmdb.org/t/p/w500/backdrop.jpg',
    );
    expect(
      images.gallery.last.originalUrl,
      'https://image.tmdb.org/t/p/original/poster.jpg',
    );
  });

  test('keeps absolute image URLs and ignores empty paths', () {
    final images = MovieImages.fromJson({
      'posters': [
        {'imageUrl': 'https://example.com/poster.jpg'},
        {'imageUrl': ''},
      ],
    });

    expect(images.posters, hasLength(1));
    expect(
      images.posters.single.thumbnailUrl,
      'https://example.com/poster.jpg',
    );
  });
}
