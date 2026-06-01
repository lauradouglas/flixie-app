import '../../models/favorite_movie.dart';
import '../../models/movie_friend_list_entry.dart';
import '../../models/movie_list.dart';
import '../../models/movie_watch_entry.dart';
import '../../models/watched_movie.dart';
import '../../models/watchlist_movie.dart';
import '../repositories/watchlist_repository.dart';

class WatchlistActionsUseCase {
  WatchlistActionsUseCase(this._watchlistRepository);

  final WatchlistRepository _watchlistRepository;

  Future<List<WatchlistMovie>> getUserWatchlist(String userId) => _watchlistRepository.getUserWatchlist(userId);
  Future<WatchlistMovie> addToWatchlist(String userId, int movieId) => _watchlistRepository.addToWatchlist(userId, movieId);
  Future<WatchlistMovie> removeFromWatchlist(String userId, int movieId) =>
      _watchlistRepository.removeFromWatchlist(userId, movieId);

  Future<WatchedMovie?> addToWatched(String userId, int movieId) => _watchlistRepository.addToWatched(userId, movieId);
  Future<WatchedMovie?> removeFromWatched(String userId, int movieId) => _watchlistRepository.removeFromWatched(userId, movieId);

  Future<FavoriteMovie> addToFavorites(String userId, int movieId) => _watchlistRepository.addToFavorites(userId, movieId);
  Future<void> removeFromFavorites(String userId, int movieId) => _watchlistRepository.removeFromFavorites(userId, movieId);

  Future<List<MovieWatchEntry>> getMovieWatchHistory(String userId, int movieId) =>
      _watchlistRepository.getMovieWatchHistory(userId, movieId);

  Future<MovieWatchEntry> logMovieWatch(String userId, LogMovieWatchRequest request) =>
      _watchlistRepository.logMovieWatch(userId, request);

  Future<MovieWatchEntry> updateMovieWatch(String userId, String watchEntryId, UpdateMovieWatchRequest request) =>
      _watchlistRepository.updateMovieWatch(userId, watchEntryId, request);

  Future<void> deleteMovieWatch(String userId, String watchEntryId) =>
      _watchlistRepository.deleteMovieWatch(userId, watchEntryId);

  Future<List<MovieList>> getMyListsContainingMovie(String userId, int movieId) =>
      _watchlistRepository.getMyListsContainingMovie(userId, movieId);

  Future<List<MovieFriendListEntry>> getFriendsListsContainingMovie(String userId, int movieId) =>
      _watchlistRepository.getFriendsListsContainingMovie(userId, movieId);
}
