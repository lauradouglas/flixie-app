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

  group('MovieCredits parsing', () {
    test('tolerates null string fields in cast/crew', () {
      final credits = MovieCredits.fromJson({
        'castMembers': [
          {
            'id': 1,
            'name': null,
            'character': null,
            'profileImage': null,
            'knownForDepartment': null,
            'gender': null,
            'order': null,
          }
        ],
        'crewMembers': [
          {
            'id': 2,
            'name': null,
            'profileImage': null,
            'knownForDepartment': null,
            'gender': null,
            'department': null,
            'job': null,
          }
        ],
      });

      expect(credits.castMembers.first.name, 'Unknown');
      expect(credits.castMembers.first.character, 'Unknown Character');
      expect(credits.crewMembers.first.department, 'Unknown');
      expect(credits.crewMembers.first.job, 'Unknown');
    });

    test('supports snake_case credits shape', () {
      final credits = MovieCredits.fromJson({
        'cast': [
          {
            'id': 10,
            'name': 'Lead',
            'character': null,
            'profile_path': '/lead.jpg',
            'known_for_department': 'Acting',
            'gender': 1,
            'order': 0,
          }
        ],
        'crew': [
          {
            'id': 11,
            'name': 'Director',
            'profile_path': '/director.jpg',
            'known_for_department': 'Directing',
            'gender': 2,
            'department': null,
            'job': null,
          }
        ],
      });

      expect(credits.castMembers, hasLength(1));
      expect(credits.crewMembers, hasLength(1));
      expect(credits.castMembers.first.profileImage, '/lead.jpg');
      expect(credits.crewMembers.first.profileImage, '/director.jpg');
    });
  });
}
