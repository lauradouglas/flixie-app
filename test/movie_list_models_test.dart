import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/movie_list_movie.dart';

void main() {
  test('maps collaborative list ownership and contributor permissions', () {
    final list = MovieList.fromJson({
      'id': 'list-1',
      'name': 'Friday picks',
      'visibility': 'FRIENDS',
      'scope': 'FRIENDS',
      'canEdit': true,
      'isOwner': false,
      'whoCanAddItems': 'everyone',
      'collaborators': [
        {'id': 'jamie', 'username': 'jamie'},
      ],
    });

    expect(list.visibility, ListVisibility.friends);
    expect(list.scope, ListScope.friends);
    expect(list.canEdit, isTrue);
    expect(list.isOwner, isFalse);
    expect(list.whoCanAddMovies, 'everyone');
    expect(list.collaborators.single.username, 'jamie');
  });

  test('maps title contribution attribution and added timestamp', () {
    final entry = MovieListMovie.fromJson({
      'id': 'entry-1',
      'listId': 'list-1',
      'movieId': 42,
      'removed': false,
      'createdAt': '2026-08-16T10:00:00.000Z',
      'addedBy': {'id': 'mat', 'username': 'mat'},
      'movie': {'id': 42, 'title': 'The Prestige'},
    });

    expect(entry.addedBy?.id, 'mat');
    expect(entry.addedBy?.username, 'mat');
    expect(entry.createdAt, '2026-08-16T10:00:00.000Z');
  });
}
