import 'package:flutter/foundation.dart';

import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/movie_list_movie.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/core/api/api_client.dart';

class MovieListsProvider extends ChangeNotifier {
  MovieListsProvider({
    required this.userId,
  });

  final String userId;

  List<MovieList> lists = [];
  final Map<String, List<MovieListMovie>> listMovies = {};

  bool isLoading = false;
  String? error;

  Future<void> loadLists() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      lists = await UserService.getMovieLists(userId);
    } catch (e) {
      error = _friendlyError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<MovieList?> createList(
    String name, {
    String? description,
    String visibility = ListVisibility.private,
    String? coverImageUrl,
    String whoCanAddMovies = 'owner',
    String scope = ListScope.personal,
    String? groupId,
    List<String> collaboratorIds = const [],
  }) async {
    try {
      final created = await UserService.createMovieList(
        userId,
        CreateMovieListRequest(
          name: name,
          description: description,
          visibility: visibility,
          coverImageUrl: coverImageUrl,
          whoCanAddMovies: whoCanAddMovies,
          scope: scope,
          groupId: groupId,
          collaboratorIds: collaboratorIds,
        ),
      );
      lists = [...lists, created]
        ..sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));
      notifyListeners();
      return created;
    } catch (e) {
      error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> renameList(
    String listId,
    String name, {
    String? description,
    String? visibility,
    String? coverImageUrl,
    String? whoCanAddMovies,
    String? scope,
    String? groupId,
    List<String>? collaboratorIds,
  }) async {
    try {
      await UserService.renameMovieList(
        userId,
        listId,
        UpdateMovieListRequest(
          name: name,
          description: description,
          visibility: visibility,
          coverImageUrl: coverImageUrl,
          whoCanAddMovies: whoCanAddMovies,
          scope: scope,
          groupId: groupId,
          collaboratorIds: collaboratorIds,
        ),
      );
      // PATCH returns a deliberately small list record. Refresh the collection
      // so counts and poster previews are not temporarily replaced with zeroes.
      lists = await UserService.getMovieLists(userId);
      notifyListeners();
      return true;
    } catch (e) {
      error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteList(String listId) async {
    try {
      await UserService.deleteMovieList(userId, listId);
      lists = lists.where((l) => l.id != listId).toList();
      listMovies.remove(listId);
      notifyListeners();
      return true;
    } catch (e) {
      error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> loadListMovies(String listId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      listMovies[listId] = await UserService.getMovieListMovies(userId, listId);
    } catch (e) {
      error = _friendlyError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addMovieToList(String listId, int movieId) async {
    try {
      final entry = await UserService.addMovieToList(userId, listId, movieId);
      final current = List<MovieListMovie>.from(listMovies[listId] ?? []);
      current.removeWhere((e) => _entryMatchesMovie(e, movieId));
      current.insert(0, entry);
      listMovies[listId] = current;
      notifyListeners();
      return true;
    } catch (e) {
      error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMovieFromList(String listId, int movieId) async {
    try {
      await UserService.removeMovieFromList(userId, listId, movieId);
      final current = List<MovieListMovie>.from(listMovies[listId] ?? []);
      current.removeWhere((e) => _entryMatchesMovie(e, movieId));
      listMovies[listId] = current;
      notifyListeners();
      return true;
    } catch (e) {
      error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeShowFromList(String listId, int showId) async {
    try {
      await UserService.removeShowFromList(userId, listId, showId);
      final current = List<MovieListMovie>.from(listMovies[listId] ?? []);
      current.removeWhere((e) => _entryMatchesShow(e, showId));
      listMovies[listId] = current;
      notifyListeners();
      return true;
    } catch (e) {
      error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<List<MovieList>> getListsContainingMovie(int movieId) async {
    try {
      final containing = await UserService.getMyListsContainingMovie(
        userId,
        movieId,
      );
      return containing.where((list) => !list.removed).toList(growable: false);
    } catch (e) {
      error = _friendlyError(e);
      notifyListeners();
      return const <MovieList>[];
    }
  }

  String _friendlyError(Object e) {
    if (e is ApiException) {
      final msg = e.message.toLowerCase();
      if (e.statusCode == 409 ||
          msg.contains('duplicate') ||
          msg.contains('already exists')) {
        return 'A list with that name already exists.';
      }
      return e.message;
    }
    return e.toString();
  }

  bool _entryMatchesMovie(MovieListMovie entry, int movieId) {
    return entry.movieId == movieId || entry.movie?.id == movieId;
  }

  bool _entryMatchesShow(MovieListMovie entry, int showId) {
    return entry.showId == showId || entry.show?.id == showId;
  }
}
