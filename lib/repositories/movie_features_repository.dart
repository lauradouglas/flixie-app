import '../models/movie_list.dart';
import '../models/movie_list_movie.dart';
import '../models/movie_watch_entry.dart';
import '../models/movie_wrapped.dart';
import '../services/user_service.dart';

class MovieFeaturesRepository {
  const MovieFeaturesRepository();

  Future<List<MovieList>> getMovieLists(String userId) {
    return UserService.getMovieLists(userId);
  }

  Future<MovieList> createMovieList(String userId, String name) {
    return UserService.createMovieList(
      userId,
      CreateMovieListRequest(name: name),
    );
  }

  Future<MovieList> renameMovieList(String userId, String listId, String name) {
    return UserService.renameMovieList(
      userId,
      listId,
      UpdateMovieListRequest(name: name),
    );
  }

  Future<void> deleteMovieList(String userId, String listId) {
    return UserService.deleteMovieList(userId, listId);
  }

  Future<List<MovieListMovie>> getMovieListMovies(String userId, String listId) {
    return UserService.getMovieListMovies(userId, listId);
  }

  Future<MovieListMovie> addMovieToList(
    String userId,
    String listId,
    int movieId,
  ) {
    return UserService.addMovieToList(userId, listId, movieId);
  }

  Future<void> removeMovieFromList(String userId, String listId, int movieId) {
    return UserService.removeMovieFromList(userId, listId, movieId);
  }

  Future<MovieWatchEntry> logMovieWatch(
    String userId, {
    required int movieId,
    String? watchedAt,
    double? rating,
    String? notes,
  }) {
    return UserService.logMovieWatch(
      userId,
      LogMovieWatchRequest(
        movieId: movieId,
        watchedAt: watchedAt,
        rating: rating,
        notes: notes,
      ),
    );
  }

  Future<List<MovieWatchEntry>> getUserMovieWatches(String userId) {
    return UserService.getUserMovieWatches(userId);
  }

  Future<List<MovieWatchEntry>> getMovieWatchHistory(String userId, int movieId) {
    return UserService.getMovieWatchHistory(userId, movieId);
  }

  Future<MovieWatchEntry> updateMovieWatch(
    String userId,
    String watchEntryId, {
    String? watchedAt,
    double? rating,
    String? notes,
  }) {
    return UserService.updateMovieWatch(
      userId,
      watchEntryId,
      UpdateMovieWatchRequest(
        watchedAt: watchedAt,
        rating: rating,
        notes: notes,
      ),
    );
  }

  Future<void> deleteMovieWatch(String userId, String watchEntryId) {
    return UserService.deleteMovieWatch(userId, watchEntryId);
  }

  Future<MovieWrapped> getMovieWrapped(String userId, int year) {
    return UserService.getMovieWrapped(userId, year);
  }
}
