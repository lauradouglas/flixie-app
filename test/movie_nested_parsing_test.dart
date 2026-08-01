import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/models/genre.dart';
import 'package:flixie_app/models/movie_video.dart';
import 'package:flixie_app/models/review.dart';

void main() {
  test('Review tolerates null string fields from hosted payloads', () {
    final review = Review.fromJson({
      'id': 99,
      'userId': 100,
      'rating': 7,
      'title': null,
      'body': null,
      'language': null,
      'createdAt': null,
      'updatedAt': null,
    });

    expect(review.id, '99');
    expect(review.userId, '100');
    expect(review.title, 'Untitled review');
    expect(review.body, '');
    expect(review.language, 'en');
  });

  test('MovieVideo tolerates nullable text fields', () {
    final video = MovieVideo.fromJson({
      'id': 1,
      'movieId': 2,
      'name': null,
      'key': null,
      'size': null,
      'official': null,
      'languageAbr': null,
      'countryAbr': null,
      'publishedAt': null,
      'videoTypeName': null,
      'createdAt': null,
      'updatedAt': null,
    });

    expect(video.name, 'Trailer');
    expect(video.key, '');
    expect(video.languageAbr, 'en');
    expect(video.countryAbr, 'US');
  });

  test('Genre tolerates null name', () {
    final genre = Genre.fromJson({
      'id': 12,
      'name': null,
    });

    expect(genre.id, 12);
    expect(genre.name, 'Unknown');
  });
}
