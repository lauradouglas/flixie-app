import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/models/genre.dart';
import 'package:flixie_app/screens/auth/auth_ui.dart';

void main() {
  group('filterSupportedGenres', () {
    test('removes TV-only genres from signup choices', () {
      final genres = [
        const Genre(id: 1, name: 'Action'),
        const Genre(id: 2, name: 'TV Movie'),
        const Genre(id: 3, name: 'Drama'),
        const Genre(id: 4, name: 'Kids'),
        const Genre(id: 5, name: 'Sci-Fi & Fantasy'),
      ];

      final filtered = filterSupportedGenres(genres);

      expect(
        filtered.map((genre) => genre.name).toList(),
        ['Action', 'Drama'],
      );
    });

    test('keeps movie genres untouched', () {
      final genres = [
        const Genre(id: 1, name: 'Comedy'),
        const Genre(id: 2, name: 'Documentary'),
        const Genre(id: 3, name: 'War'),
      ];

      expect(filterSupportedGenres(genres), genres);
    });
  });

  group('evaluatePasswordStrength', () {
    test('returns weak for short lowercase password', () {
      expect(
        evaluatePasswordStrength('password'),
        PasswordStrengthLevel.weak,
      );
    });

    test('returns medium for mixed password without symbol', () {
      expect(
        evaluatePasswordStrength('Password123'),
        PasswordStrengthLevel.medium,
      );
    });

    test('returns strong for mixed password with symbol', () {
      expect(
        evaluatePasswordStrength('Password123!'),
        PasswordStrengthLevel.strong,
      );
    });
  });

  group('isValidEmailFormat', () {
    test('accepts valid email', () {
      expect(isValidEmailFormat('doug@example.com'), isTrue);
    });

    test('rejects invalid email', () {
      expect(isValidEmailFormat('doug-example.com'), isFalse);
    });
  });
}
