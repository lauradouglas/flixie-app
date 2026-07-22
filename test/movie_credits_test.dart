import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/models/movie_credits.dart';

void main() {
  group('resolveCreditProfileImage', () {
    test('builds a TMDB URL from a stored profile path', () {
      expect(
        resolveCreditProfileImage('/profile.jpg'),
        'https://image.tmdb.org/t/p/w185/profile.jpg',
      );
    });

    test('keeps a complete database image URL unchanged', () {
      const image = 'https://cdn.example.com/people/profile.jpg';
      expect(resolveCreditProfileImage(image), image);
    });

    test('returns null for missing images', () {
      expect(resolveCreditProfileImage(null), isNull);
      expect(resolveCreditProfileImage('  '), isNull);
    });
  });
}
