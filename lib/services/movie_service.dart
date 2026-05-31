import '../models/friend_recommendation.dart';
import '../models/friend_summary.dart';
import '../models/movie.dart';
import '../models/movie_credits.dart';
import '../models/movie_friend_activity.dart';
import '../models/review.dart';
import '../models/similar_movie.dart';
import '../models/movie_short.dart';
import '../models/top_rated_movie.dart';
import '../models/watch_provider.dart';
import '../utils/app_logger.dart';
import '../utils/activity_feed_ranking.dart';
import 'api_client.dart';
import 'movie_cache_service.dart';

class MovieService {
  MovieService();

  final _cache = MovieCacheService();

  /// Update a movie in the cache with new data.
  void updateCachedMovie(Movie movie) {
    _cache.cacheMovie(movie);
  }

  Future<Movie> getMovieById(int id, {String? userId}) async {
    final cachedMovie = _cache.getMovie(id);
    if (cachedMovie != null) return cachedMovie;

    apiLogger.d('Fetching movie $id.');
    final queryParams = userId != null ? {'userId': userId} : null;
    final data =
        await ApiClient.get('/movies/id/$id', queryParams: queryParams);
    final movie = Movie.fromJson(data as Map<String, dynamic>);
    _cache.cacheMovie(movie);
    return movie;
  }

  Future<List<Movie>> getMoviesByIds(List<int> ids) async {
    final data = await ApiClient.post('/movies/by-ids', body: {'ids': ids});
    return (data as List<dynamic>)
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> addMovieRating(
      int movieId, String userId, int rating) async {
    final data = await ApiClient.post('/movies/$movieId/add/rating',
        body: {'userId': userId, 'rating': rating});
    return data as Map<String, dynamic>;
  }

  Future<int?> getUserMovieRating(int movieId, String userId) async {
    try {
      final data = await ApiClient.post('/movies/$movieId/user/rating',
          body: {'userId': userId});
      if (data != null && data is Map<String, dynamic>) {
        final r = data['rating'];
        if (r != null) return (r as num).toInt();
      }
    } catch (_) {}
    return null;
  }

  Future<void> addToWatchlist(String userId, int movieId) async {
    await ApiClient.post(
      '/movies/watchlist',
      body: {'userId': userId, 'movieId': movieId},
    );
  }

  Future<void> removeFromWatchlist(String userId, int movieId) async {
    await ApiClient.delete(
      '/movies/watchlist',
      body: {'userId': userId, 'movieId': movieId},
    );
  }

  Future<void> addToFavourites(String userId, int movieId) async {
    await ApiClient.post(
      '/movies/favourites',
      body: {'userId': userId, 'movieId': movieId},
    );
  }

  Future<void> removeFromFavourites(String userId, int movieId) async {
    await ApiClient.delete(
      '/movies/favourites',
      body: {'userId': userId, 'movieId': movieId},
    );
  }

  Future<List<SimilarMovie>> getMovieRecommendations(int movieId) async {
    final cachedRecommendations = _cache.getRecommendations(movieId);
    if (cachedRecommendations != null) return cachedRecommendations;

    apiLogger.d('Fetching recommendations for movie $movieId.');
    final data = await ApiClient.get('/movies/$movieId/recommendations');
    final recommendations = (data as List<dynamic>)
        .map((e) => SimilarMovie.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache.cacheRecommendations(movieId, recommendations);
    return recommendations;
  }

  Future<MovieCredits> getMovieCredits(int movieId) async {
    final cachedCredits = _cache.getCredits(movieId);
    if (cachedCredits != null) return cachedCredits;

    apiLogger.d('Fetching credits for movie $movieId.');
    final data = await ApiClient.get('/movies/$movieId/credits');
    final credits = MovieCredits.fromJson(data as Map<String, dynamic>);
    _cache.cacheCredits(movieId, credits);
    return credits;
  }

  Future<List<WatchProvider>> getMovieWatchProviders(
      int movieId, String region) async {
    apiLogger
        .d('Fetching watch providers for movie $movieId in region $region.');
    final data =
        await ApiClient.get('/movies/$movieId/$region/watch/providers');
    return (data as List<dynamic>)
        .map((e) => WatchProvider.fromJson(e as Map<String, dynamic>))
        .where((p) => p.displayPriority <= 50)
        .toList();
  }

  Future<List<Review>> getMovieReviews(int movieId, {String? userId}) async {
    apiLogger.d('Fetching reviews for movie $movieId from API');
    final data = await ApiClient.get('/users/MOVIE/$movieId/reviews',
        queryParams: userId != null ? {'userId': userId} : null);
    return (data as List<dynamic>)
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TopRatedMovie>> getTopRatedThisWeek({int limit = 10}) async {
    apiLogger.d('Fetching top rated movies this week');
    final data = await ApiClient.get('/movies/top_rated/this_week',
        queryParams: {'limit': '$limit'});
    return (data as List<dynamic>)
        .map((e) => TopRatedMovie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MovieFriendActivity>> getFriendsMovieActivity(
      int movieId, String userId) async {
    apiLogger.d('Fetching friends activity for movie $movieId');
    final data = await ApiClient.get('/movies/id/$movieId/friends-activity',
        queryParams: {'userId': userId});
    final activities = (data as List<dynamic>)
        .map((e) => MovieFriendActivity.fromJson(e as Map<String, dynamic>))
        .toList();
    return rankMovieFriendActivities(activities);
  }

  Future<List<MovieShort>> getTopRatedMovies({String region = 'US'}) async {
    apiLogger.d('Fetching top rated movies for region $region');
    final data = await ApiClient.get('/movies/top_rated',
        queryParams: {'region': region});
    return (data as List<dynamic>)
        .map((e) => MovieShort.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MovieShort>> getNowPlayingMovies({String region = 'US'}) async {
    apiLogger.d('Fetching now playing movies for region $region');
    final data = await ApiClient.get('/movies/now_playing',
        queryParams: {'region': region});
    return (data as List<dynamic>)
        .map((e) => MovieShort.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FriendRecommendationResponse> getFriendRecommendation(
      int movieId) async {
    apiLogger.d('Fetching friend recommendation for movie $movieId');
    final data = await ApiClient.get('/movies/$movieId/friend-recommendation');
    return FriendRecommendationResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<FriendSummaryResponse> getFriendSummary(int movieId) async {
    apiLogger.d('Fetching friend summary for movie $movieId');
    final data = await ApiClient.get('/movies/$movieId/friend-summary');
    return FriendSummaryResponse.fromJson(data as Map<String, dynamic>);
  }

  // ---- Cache management ----

  /// Evict a single movie from cache so the next fetch hits the API.
  void evictMovie(int movieId) => _cache.evictMovie(movieId);

  /// Clear all cached movies.
  void clearCache() => _cache.clearCache();

  /// Clear only stale cache entries (older than today).
  void clearStaleCache() => _cache.clearStaleCache();

  /// Cache statistics for debugging.
  Map<String, dynamic> getCacheStats() => _cache.getCacheStats();
}
