import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/movie_friend_list_entry.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/movie_wrapped.dart';
import 'package:flixie_app/services/recommendation_service.dart';

void main() {
  group('MovieList', () {
    test('parses create-list response shape', () {
      final model = MovieList.fromJson({
        'id': 'list-1',
        'userId': 'user-1',
        'name': 'Date Night',
        'description': 'Romance picks',
        'visibility': 'FRIENDS',
        'coverImageUrl': 'https://img.example/cover.jpg',
        'whoCanAddMovies': 'friends',
        'previewPosterUrls': [
          'https://img.example/p1.jpg',
          'https://img.example/p2.jpg',
        ],
        'movieCount': '4',
        'removed': false,
        'createdAt': '2025-01-01T00:00:00.000Z',
        'updatedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(model.name, 'Date Night');
      expect(model.description, 'Romance picks');
      expect(model.visibility, ListVisibility.friends);
      expect(model.coverImageUrl, 'https://img.example/cover.jpg');
      expect(model.whoCanAddMovies, 'friends');
      expect(model.previewPosterUrls, hasLength(2));
      expect(model.movieCount, 4);
      expect(model.removed, isFalse);
    });

    test('create request includes new optional list metadata', () {
      const request = CreateMovieListRequest(
        name: 'Sci-Fi',
        description: 'Mind-bending favorites',
        visibility: ListVisibility.public,
        coverImageUrl: 'https://img.example/scifi.jpg',
        whoCanAddMovies: 'friends',
      );
      expect(request.toJson(), {
        'name': 'Sci-Fi',
        'description': 'Mind-bending favorites',
        'visibility': ListVisibility.public,
        'coverImageUrl': 'https://img.example/scifi.jpg',
        'whoCanAddMovies': 'friends',
      });
    });

    test('create request omits blank optional fields', () {
      const request = CreateMovieListRequest(name: 'Watch Later');
      expect(request.toJson(), {
        'name': 'Watch Later',
        'visibility': ListVisibility.private,
        'whoCanAddMovies': 'owner',
      });
    });

    test('update request serializes only provided fields', () {
      const request = UpdateMovieListRequest(
        description: 'Updated description',
        visibility: ListVisibility.friends,
      );
      expect(request.toJson(), {
        'description': 'Updated description',
        'visibility': ListVisibility.friends,
      });
    });
  });

  group('MovieFriendListEntry', () {
    test('parses nested friend/list response shape', () {
      final model = MovieFriendListEntry.fromJson({
        'friend': {
          'id': 'u-1',
          'username': 'Sean',
        },
        'list': {
          'id': 'l-1',
          'name': 'Nolan Masterpieces',
          'movieCount': 12,
          'previewPosterUrls': ['https://img.example/poster.jpg'],
        },
      });

      expect(model.friendUserId, 'u-1');
      expect(model.friendName, 'Sean');
      expect(model.listId, 'l-1');
      expect(model.listName, 'Nolan Masterpieces');
      expect(model.movieCount, 12);
      expect(model.previewPosterUrls, hasLength(1));
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

  group('RecommendationFromHighlyRatedResponse', () {
    test('parses source movie and recommendation list', () {
      final model = RecommendationFromHighlyRatedResponse.fromJson({
        'sourceMovie': {
          'id': 123,
          'title': 'Interstellar',
          'rating': 9,
        },
        'recommendations': [
          {
            'id': 321,
            'title': 'Arrival',
            'poster': '/abc.jpg',
          },
        ],
      });

      expect(model.sourceMovie, isNotNull);
      expect(model.sourceMovie!.title, 'Interstellar');
      expect(model.sourceMovie!.rating, 9.0);
      expect(model.recommendations, hasLength(1));
      expect(model.recommendations.first.name, 'Arrival');
    });
  });
}
