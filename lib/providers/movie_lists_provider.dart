import 'package:flutter/foundation.dart';

import '../models/movie_list.dart';
import '../models/movie_list_movie.dart';
import '../repositories/movie_features_repository.dart';
import '../services/api_client.dart';

class MovieListsProvider extends ChangeNotifier {
  MovieListsProvider({
    required this.repository,
    required this.userId,
  });

  final MovieFeaturesRepository repository;
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
      lists = await repository.getMovieLists(userId);
    } catch (e) {
      error = _friendlyError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<MovieList?> createList(String name) async {
    try {
      final created = await repository.createMovieList(userId, name);
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

  Future<bool> renameList(String listId, String name) async {
    try {
      final updated = await repository.renameMovieList(userId, listId, name);
      lists = lists.map((l) => l.id == listId ? updated : l).toList();
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
      await repository.deleteMovieList(userId, listId);
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
      listMovies[listId] = await repository.getMovieListMovies(userId, listId);
    } catch (e) {
      error = _friendlyError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addMovieToList(String listId, int movieId) async {
    try {
      final entry = await repository.addMovieToList(userId, listId, movieId);
      final current = List<MovieListMovie>.from(listMovies[listId] ?? []);
      current.removeWhere((e) => e.movieId == movieId);
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
      await repository.removeMovieFromList(userId, listId, movieId);
      final current = List<MovieListMovie>.from(listMovies[listId] ?? []);
      current.removeWhere((e) => e.movieId == movieId);
      listMovies[listId] = current;
      notifyListeners();
      return true;
    } catch (e) {
      error = _friendlyError(e);
      notifyListeners();
      return false;
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
}
