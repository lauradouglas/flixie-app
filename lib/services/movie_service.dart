import '../models/movie.dart';
import '../models/movie_credits.dart';
import '../models/movie_friend_activity.dart';
import '../models/review.dart';
import '../models/similar_movie.dart';
import '../models/movie_short.dart';
import '../models/top_rated_movie.dart';
import '../models/watch_provider.dart';
import '../utils/app_logger.dart';
import 'api_client.dart';
import 'movie_cache_service.dart';

class MovieService {
  static final _cache = MovieCacheService();

  /// Update a movie in the cache with new data
  static void updateCachedMovie(Movie movie) {
    _cache.cacheMovie(movie);
  }

  static Future<Movie> getMovieById(int id, {String? userId}) async {
    // Check cache first
    final cachedMovie = _cache.getMovie(id);
    if (cachedMovie != null) {
      return cachedMovie;
    }

    // Fetch from API
    apiLogger.d('Fetching movie $id.');
    final queryParams = userId != null ? {'userId': userId} : null;
    final data =
        await ApiClient.get('/movies/id/$id', queryParams: queryParams);
    final movie = Movie.fromJson(data as Map<String, dynamic>);

    // Cache the movie
    _cache.cacheMovie(movie);

    return movie;
  }

  static Future<List<Movie>> getMoviesByIds(List<int> ids) async {
    final data = await ApiClient.post('/movies/by-ids', body: {'ids': ids});
    return (data as List<dynamic>)
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> addMovieRating(
      int movieId, String userId, int rating) async {
    final data = await ApiClient.post('/movies/$movieId/add/rating',
        body: {'userId': userId, 'rating': rating});
    return data as Map<String, dynamic>;
  }

  static Future<int?> getUserMovieRating(int movieId, String userId) async {
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

  static Future<void> addToWatchlist(String userId, int movieId) async {
    await ApiClient.post(
      '/movies/watchlist',
      body: {'userId': userId, 'movieId': movieId},
    );
  }

  static Future<void> removeFromWatchlist(String userId, int movieId) async {
    await ApiClient.delete(
      '/movies/watchlist',
      body: {'userId': userId, 'movieId': movieId},
    );
  }

  static Future<void> addToFavourites(String userId, int movieId) async {
    await ApiClient.post(
      '/movies/favourites',
      body: {'userId': userId, 'movieId': movieId},
    );
  }

  static Future<void> removeFromFavourites(String userId, int movieId) async {
    await ApiClient.delete(
      '/movies/favourites',
      body: {'userId': userId, 'movieId': movieId},
    );
  }

  static Future<List<SimilarMovie>> getMovieRecommendations(int movieId) async {
    // Check cache first
    final cachedRecommendations = _cache.getRecommendations(movieId);
    if (cachedRecommendations != null) {
      return cachedRecommendations;
    }

    // Fetch from API
    apiLogger.d('Fetching recommendations for movie $movieId.');
    final data = await ApiClient.get('/movies/$movieId/recommendations');
    final recommendations = (data as List<dynamic>)
        .map((e) => SimilarMovie.fromJson(e as Map<String, dynamic>))
        .toList();

    // Cache the recommendations
    _cache.cacheRecommendations(movieId, recommendations);

    return recommendations;
  }

  static Future<MovieCredits> getMovieCredits(int movieId) async {
    // Check cache first
    final cachedCredits = _cache.getCredits(movieId);
    if (cachedCredits != null) {
      return cachedCredits;
    }

    // Fetch from API
    apiLogger.d('Fetching credits for movie $movieId.');
    final data = await ApiClient.get('/movies/$movieId/credits');
    final credits = MovieCredits.fromJson(data as Map<String, dynamic>);

    // Cache the credits
    _cache.cacheCredits(movieId, credits);

    return credits;
  }

  static Future<List<WatchProvider>> getMovieWatchProviders(
      int movieId, String region) async {
    apiLogger
        .d('Fetching watch providers for movie $movieId in region $region.');
    final data =
        await ApiClient.get('/movies/$movieId/$region/watch/providers');
    final allProviders = (data as List<dynamic>)
        .map((e) => WatchProvider.fromJson(e as Map<String, dynamic>))
        .toList();

    // Filter to only show providers with displayPriority <= 50
    final filteredProviders = allProviders
        .where((provider) => provider.displayPriority <= 50)
        .toList();

    return filteredProviders;
  }

  static Future<List<Review>> getMovieReviews(int movieId,
      {String? userId}) async {
    apiLogger.d('Fetching reviews for movie $movieId from API');
    final data = await ApiClient.get('/users/MOVIE/$movieId/reviews',
        queryParams: userId != null ? {'userId': userId} : null);
    return (data as List<dynamic>)
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<TopRatedMovie>> getTopRatedThisWeek(
      {int limit = 10}) async {
    apiLogger.d('Fetching top rated movies this week');
    final data = await ApiClient.get('/movies/top_rated/this_week',
        queryParams: {'limit': '$limit'});
    return (data as List<dynamic>)
        .map((e) => TopRatedMovie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<MovieFriendActivity>> getFriendsMovieActivity(
      int movieId, String userId) async {
    apiLogger.d('Fetching friends activity for movie $movieId');
    final data = await ApiClient.get('/movies/id/$movieId/friends-activity',
        queryParams: {'userId': userId});
    return (data as List<dynamic>)
        .map((e) => MovieFriendActivity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<MovieShort>> getTopRatedMovies(
      {String region = 'US'}) async {
    apiLogger.d('Fetching top rated movies for region $region');
    final data = await ApiClient.get('/movies/top_rated',
        queryParams: {'region': region});
    return (data as List<dynamic>)
        .map((e) => MovieShort.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<MovieShort>> getNowPlayingMovies(
      {String region = 'US'}) async {
    apiLogger.d('Fetching now playing movies for region $region');
    final data = await ApiClient.get('/movies/now_playing',
        queryParams: {'region': region});
    final movies = (data as List<dynamic>)
        .map((e) => MovieShort.fromJson(e as Map<String, dynamic>))
        .toList();
    return movies;
  }
  // ---- Cache management methods ----

  /// Evict a single movie from cache so the next fetch hits the API.
  static void evictMovie(int movieId) {
    _cache.evictMovie(movieId);
  }

  /// Clear all cached movies
  static void clearCache() {
    _cache.clearCache();
  }

  /// Clear only stale cache entries (older than today)
  static void clearStaleCache() {
    _cache.clearStaleCache();
  }

  /// Get cache statistics for debugging
  static Map<String, dynamic> getCacheStats() {
    return _cache.getCacheStats();
  }
}
