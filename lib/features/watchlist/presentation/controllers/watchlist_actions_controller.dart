import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/movie_friend_list_entry.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';

class WatchlistActionsController {
  const WatchlistActionsController();

  static const WatchlistActionsController instance =
      WatchlistActionsController();

  Future<List<WatchlistMovie>> getUserWatchlist(String userId) =>
      UserService.getUserWatchlist(userId);
  Future<WatchlistMovie> addToWatchlist(String userId, int movieId) =>
      UserService.addToWatchlist(userId, movieId);
  Future<WatchlistMovie> removeFromWatchlist(String userId, int movieId) =>
      UserService.removeFromWatchlist(userId, movieId);

  Future<WatchedMovie?> addToWatched(String userId, int movieId) =>
      UserService.addToWatched(userId, movieId);
  Future<WatchedMovie?> removeFromWatched(String userId, int movieId) =>
      UserService.removeFromWatched(userId, movieId);

  Future<FavoriteMovie> addToFavorites(String userId, int movieId) =>
      UserService.addToFavorites(userId, movieId);
  Future<void> removeFromFavorites(String userId, int movieId) =>
      UserService.removeFromFavorites(userId, movieId);

  Future<List<MovieWatchEntry>> getMovieWatchHistory(
          String userId, int movieId) =>
      UserService.getMovieWatchHistory(userId, movieId);
  Future<MovieWatchEntry> logMovieWatch(
          String userId, LogMovieWatchRequest request) =>
      UserService.logMovieWatch(userId, request);
  Future<MovieWatchEntry> updateMovieWatch(String userId, String watchEntryId,
          UpdateMovieWatchRequest request) =>
      UserService.updateMovieWatch(userId, watchEntryId, request);
  Future<void> deleteMovieWatch(String userId, String watchEntryId) =>
      UserService.deleteMovieWatch(userId, watchEntryId);

  Future<List<MovieList>> getMyListsContainingMovie(
          String userId, int movieId) =>
      UserService.getMyListsContainingMovie(userId, movieId);
  Future<List<MovieFriendListEntry>> getFriendsListsContainingMovie(
          String userId, int movieId) =>
      UserService.getFriendsListsContainingMovie(userId, movieId);

  Future<List<WatchProvider>> getUserWatchProviders(String userId) =>
      UserService.getUserWatchProviders(userId);
}
