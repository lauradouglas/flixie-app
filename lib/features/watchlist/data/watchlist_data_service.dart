import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/friend_recommendation.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';

/// API access used by Watchlist loading. Inject a fake for controller tests.
class WatchlistDataService {
  const WatchlistDataService();

  Future<List<MovieShort>> searchMovies(String query) async {
    final response = await SearchService.search(query, type: 'movie');
    return response.results
        .where((item) => !item.isPerson && item.movie != null)
        .map((item) => item.movie!)
        .toList(growable: false);
  }

  Future<dynamic> getExperienceFits({required Map<String, dynamic> body}) =>
      ApiClient.post('/recommendations/watchlist-fit', body: body);

  Future<Map<int, FriendRecommendationResponse>> getMovieFriends(
    Iterable<int> ids, {
    required bool Function() isCurrent,
    required void Function(Map<int, FriendRecommendationResponse>) onProgress,
  }) =>
      MovieService().getFriendRecommendations(ids,
          isCurrent: isCurrent, onProgress: onProgress);

  Future<Map<int, FriendRecommendationResponse>> getShowFriends(
    Iterable<int> ids, {
    required bool Function() isCurrent,
    required void Function(Map<int, FriendRecommendationResponse>) onProgress,
  }) =>
      ShowService.getFriendRecommendations(ids,
          isCurrent: isCurrent, onProgress: onProgress);

  Future<List<WatchProvider>> getSavedProviders(String userId) =>
      UserService.getUserWatchProviders(userId);
  TvShow? cachedShow(int id) => ShowService.cachedSummary(id);
  Future<List<TvShow>> getShows(List<int> ids) =>
      ShowService.getShowsByIds(ids);
  Future<TvShow> getShow(int id) => ShowService.getShowById(id);
  Future<List<WatchProvider>> getShowProviders(int id, String region) =>
      ShowService.getShowWatchProviders(id, region);

  Future<WatchlistMovie> addToWatchlist(String userId, int movieId) =>
      UserService.addToWatchlist(userId, movieId);
  Future<WatchlistMovie> removeFromWatchlist(String userId, int movieId) =>
      UserService.removeFromWatchlist(userId, movieId);
  Future<WatchedMovie?> addToWatched(String userId, int movieId) =>
      UserService.addToWatched(userId, movieId);
  Future<FavoriteMovie> addToFavorites(String userId, int movieId) =>
      UserService.addToFavorites(userId, movieId);
  Future<MovieWatchEntry> logMovieWatch(
          String userId, LogMovieWatchRequest request) =>
      UserService.logMovieWatch(userId, request);
  Future<dynamic> removeShowFromWatchlist(String userId, int showId) =>
      ShowService.removeFromWatchlist(userId, showId);
}
