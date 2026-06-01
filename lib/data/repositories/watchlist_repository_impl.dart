import '../../domain/repositories/watchlist_repository.dart';
import '../../models/favorite_movie.dart';
import '../../models/movie_friend_list_entry.dart';
import '../../models/movie_list.dart';
import '../../models/movie_watch_entry.dart';
import '../../models/watched_movie.dart';
import '../../models/watchlist_movie.dart';
import '../../services/user_service.dart';

class WatchlistRepositoryImpl implements WatchlistRepository {
  @override
  Future<List<WatchlistMovie>> getUserWatchlist(String userId) => UserService.getUserWatchlist(userId);

  @override
  Future<WatchlistMovie> addToWatchlist(String userId, int movieId) => UserService.addToWatchlist(userId, movieId);

  @override
  Future<WatchlistMovie> removeFromWatchlist(String userId, int movieId) =>
      UserService.removeFromWatchlist(userId, movieId);

  @override
  Future<WatchedMovie?> addToWatched(String userId, int movieId) => UserService.addToWatched(userId, movieId);

  @override
  Future<WatchedMovie?> removeFromWatched(String userId, int movieId) => UserService.removeFromWatched(userId, movieId);

  @override
  Future<FavoriteMovie> addToFavorites(String userId, int movieId) => UserService.addToFavorites(userId, movieId);

  @override
  Future<void> removeFromFavorites(String userId, int movieId) => UserService.removeFromFavorites(userId, movieId);

  @override
  Future<List<MovieWatchEntry>> getMovieWatchHistory(String userId, int movieId) =>
      UserService.getMovieWatchHistory(userId, movieId);

  @override
  Future<MovieWatchEntry> logMovieWatch(String userId, LogMovieWatchRequest request) =>
      UserService.logMovieWatch(userId, request);

  @override
  Future<MovieWatchEntry> updateMovieWatch(String userId, String watchEntryId, UpdateMovieWatchRequest request) =>
      UserService.updateMovieWatch(userId, watchEntryId, request);

  @override
  Future<void> deleteMovieWatch(String userId, String watchEntryId) =>
      UserService.deleteMovieWatch(userId, watchEntryId);

  @override
  Future<List<MovieList>> getMyListsContainingMovie(String userId, int movieId) =>
      UserService.getMyListsContainingMovie(userId, movieId);

  @override
  Future<List<MovieFriendListEntry>> getFriendsListsContainingMovie(String userId, int movieId) =>
      UserService.getFriendsListsContainingMovie(userId, movieId);
}
