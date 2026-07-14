import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/movie_friend_list_entry.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';

abstract class WatchlistRepository {
  Future<List<WatchlistMovie>> getUserWatchlist(String userId);
  Future<WatchlistMovie> addToWatchlist(String userId, int movieId);
  Future<WatchlistMovie> removeFromWatchlist(String userId, int movieId);

  Future<WatchedMovie?> addToWatched(String userId, int movieId);
  Future<WatchedMovie?> removeFromWatched(String userId, int movieId);

  Future<FavoriteMovie> addToFavorites(String userId, int movieId);
  Future<void> removeFromFavorites(String userId, int movieId);

  Future<List<MovieWatchEntry>> getMovieWatchHistory(String userId, int movieId);
  Future<MovieWatchEntry> logMovieWatch(String userId, LogMovieWatchRequest request);
  Future<MovieWatchEntry> updateMovieWatch(String userId, String watchEntryId, UpdateMovieWatchRequest request);
  Future<void> deleteMovieWatch(String userId, String watchEntryId);

  Future<List<MovieList>> getMyListsContainingMovie(String userId, int movieId);
  Future<List<MovieFriendListEntry>> getFriendsListsContainingMovie(String userId, int movieId);
}
