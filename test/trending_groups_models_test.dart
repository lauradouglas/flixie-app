import 'package:flixie_app/models/trending_groups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrendingGroupsResponse', () {
    test('parses summary and groups payload', () {
      final response = TrendingGroupsResponse.fromJson({
        'summary': {
          'totalActivities': 27,
          'moviesDiscussed': '18',
          'highlyRatedCount': 6,
          'newGroupsThisWeek': 2,
        },
        'groups': [
          {
            'id': 'group-1',
            'name': 'Sci-fi squad',
            'avatarUrl': null,
            'initials': 'SS',
            'memberCount': 15,
            'trendPercent': 18.2,
            'trendLabel': 'Most active this week',
            'activityCount': 9,
            'trendingMovies': [
              {
                'id': 'movie-1',
                'tmdbId': '157336',
                'title': 'Interstellar',
                'posterUrl': 'https://image.example/interstellar.jpg',
                'activityCount': '3',
                'averageRating': 8.7,
              },
            ],
          },
        ],
      });

      expect(response.summary.totalActivities, 27);
      expect(response.summary.moviesDiscussed, 18);
      expect(response.groups, hasLength(1));
      expect(response.groups.first.initials, 'SS');
      expect(response.groups.first.trendingMovies.first.tmdbId, 157336);
      expect(response.groups.first.trendingMovies.first.activityCount, 3);
    });

    test('builds fallback initials and default numbers', () {
      final response = TrendingGroupsResponse.fromJson({
        'summary': {},
        'groups': [
          {
            'id': 'group-2',
            'name': 'The BBGs',
            'trendLabel': 'Most active this week',
            'trendingMovies': [],
          },
        ],
      });

      expect(response.summary.totalActivities, 0);
      expect(response.groups.first.initials, 'TB');
      expect(response.groups.first.memberCount, 0);
      expect(response.groups.first.activityCount, 0);
    });

    test('parses snake_case movie keys and normalizes poster paths', () {
      final response = TrendingGroupsResponse.fromJson({
        'summary': {},
        'groups': [
          {
            'id': 'group-3',
            'name': 'Movie Club',
            'trendLabel': 'Hot now',
            'trending_movies': [
              {
                'id': 'movie-3',
                'tmdb_id': 603,
                'title': 'The Matrix',
                'poster_path': '/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg',
                'activity_count': 4,
              },
            ],
          },
        ],
      });

      final movie = response.groups.first.trendingMovies.first;
      expect(movie.tmdbId, 603);
      expect(
        movie.posterUrl,
        'https://image.tmdb.org/t/p/w342/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg',
      );
      expect(movie.activityCount, 4);
    });
  });
}
