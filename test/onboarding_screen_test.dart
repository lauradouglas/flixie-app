import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/features/authentication/presentation/pages/onboarding_screen.dart';

void main() {
  group('validateFavouriteMovieCount', () {
    test('returns error when fewer than 3 favourites selected', () {
      expect(
        validateFavouriteMovieCount(2),
        'Please select between 3 and 5 favourite movies.',
      );
    });

    test('returns null when within supported range', () {
      expect(validateFavouriteMovieCount(3), isNull);
      expect(validateFavouriteMovieCount(5), isNull);
    });

    test('returns error when more than 5 favourites selected', () {
      expect(
        validateFavouriteMovieCount(6),
        'Please select between 3 and 5 favourite movies.',
      );
    });
  });

  group('canAddOnboardingMovie', () {
    test('allows adding when list is below max', () {
      expect(canAddOnboardingMovie({}, 101), isTrue);
    });

    test('disallows adding new movie when list is full', () {
      final selected = {
        for (var i = 0; i < 5; i++) i: MovieShort(id: i, name: 'Movie $i'),
      };
      expect(canAddOnboardingMovie(selected, 999), isFalse);
    });

    test('allows re-selecting movie already in full list', () {
      final selected = {
        for (var i = 0; i < 5; i++) i: MovieShort(id: i, name: 'Movie $i'),
      };
      expect(canAddOnboardingMovie(selected, 3), isTrue);
    });
  });
}
