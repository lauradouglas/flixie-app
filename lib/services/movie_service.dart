import '../models/movie.dart';
import '../models/movie_credits.dart';
import '../models/similar_movie.dart';
import '../models/watch_provider.dart';
import 'api_client.dart';
import 'movie_cache_service.dart';

class MovieService {
  static final _cache = MovieCacheService();

  static Future<Movie> getMovieById(int id, {String? userId}) async {
    // Check cache first
    final cachedMovie = _cache.getMovie(id);
    if (cachedMovie != null) {
      return cachedMovie;
    }

    // Fetch from API
    print('🌐 [MovieService] Fetching movie $id from API');
    final queryParams = userId != null ? {'userId': userId} : null;
    final data = await ApiClient.get('/movies/id/$id', queryParams: queryParams);
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

  static Future<void> addMovieRating(
      int movieId, Map<String, dynamic> body) async {
    await ApiClient.post('/movies/$movieId/ratings', body: body);
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
    print('🌐 [MovieService] Fetching recommendations for movie $movieId from API');
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
    print('🌐 [MovieService] Fetching credits for movie $movieId from API');
    final data = await ApiClient.get('/movies/$movieId/credits');
    final credits = MovieCredits.fromJson(data as Map<String, dynamic>);
    
    // Cache the credits
    _cache.cacheCredits(movieId, credits);
    
    return credits;
  }

  static Future<List<WatchProvider>> getMovieWatchProviders(int movieId, String region) async {
    print('🌐 [MovieService] Fetching watch providers for movie $movieId in region $region from API');
    final data = await ApiClient.get('/movies/$movieId/$region/watch/providers');
    return (data as List<dynamic>)
        .map((e) => WatchProvider.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- Cache management methods ----

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
