import 'package:flixie_app/features/watchlist/data/watchlist_repository_impl.dart';
import 'package:flixie_app/features/watchlist/data/watchlist_actions_usecase.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/movie_friend_list_entry.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';

class WatchlistActionsController {
  WatchlistActionsController({WatchlistActionsUseCase? useCase}) : _useCase = useCase ?? WatchlistActionsUseCase(WatchlistRepositoryImpl());

  static final WatchlistActionsController instance = WatchlistActionsController();

  final WatchlistActionsUseCase _useCase;

  Future<List<WatchlistMovie>> getUserWatchlist(String userId) => _useCase.getUserWatchlist(userId);
  Future<WatchlistMovie> addToWatchlist(String userId, int movieId) => _useCase.addToWatchlist(userId, movieId);
  Future<WatchlistMovie> removeFromWatchlist(String userId, int movieId) => _useCase.removeFromWatchlist(userId, movieId);

  Future<WatchedMovie?> addToWatched(String userId, int movieId) => _useCase.addToWatched(userId, movieId);
  Future<WatchedMovie?> removeFromWatched(String userId, int movieId) => _useCase.removeFromWatched(userId, movieId);

  Future<FavoriteMovie> addToFavorites(String userId, int movieId) => _useCase.addToFavorites(userId, movieId);
  Future<void> removeFromFavorites(String userId, int movieId) => _useCase.removeFromFavorites(userId, movieId);

  Future<List<MovieWatchEntry>> getMovieWatchHistory(String userId, int movieId) => _useCase.getMovieWatchHistory(userId, movieId);
  Future<MovieWatchEntry> logMovieWatch(String userId, LogMovieWatchRequest request) => _useCase.logMovieWatch(userId, request);
  Future<MovieWatchEntry> updateMovieWatch(String userId, String watchEntryId, UpdateMovieWatchRequest request) =>
      _useCase.updateMovieWatch(userId, watchEntryId, request);
  Future<void> deleteMovieWatch(String userId, String watchEntryId) => _useCase.deleteMovieWatch(userId, watchEntryId);

  Future<List<MovieList>> getMyListsContainingMovie(String userId, int movieId) => _useCase.getMyListsContainingMovie(userId, movieId);
  Future<List<MovieFriendListEntry>> getFriendsListsContainingMovie(String userId, int movieId) =>
      _useCase.getFriendsListsContainingMovie(userId, movieId);

  Future<List<WatchProvider>> getUserWatchProviders(String userId) =>
      UserService.getUserWatchProviders(userId);
}
