import '../models/movie.dart';
import '../models/movie_credits.dart';
import '../models/similar_movie.dart';
import '../models/movie_short.dart';
import '../utils/app_logger.dart';

/// Simple in-memory cache for movies, credits, recommendations, and trending movies viewed during the current day.
/// Cache is cleared when the day changes or when the app restarts.
class MovieCacheService {
  static final MovieCacheService _instance = MovieCacheService._internal();
  factory MovieCacheService() => _instance;
  MovieCacheService._internal();

  final Map<int, _CachedMovie> _movieCache = {};
  final Map<int, _CachedCredits> _creditsCache = {};
  final Map<int, _CachedRecommendations> _recommendationsCache = {};
  final Map<String, _CachedTrendingMovies> _trendingMoviesCache = {};

  // ---- Movie Caching ----

  /// Get a movie from cache if it exists and was cached today
  Movie? getMovie(int movieId) {
    final cached = _movieCache[movieId];
    if (cached == null) {
      return null;
    }

    // Check if cached data is from today
    final now = DateTime.now();
    final cacheDate = cached.timestamp;
    
    if (now.year == cacheDate.year &&
        now.month == cacheDate.month &&
        now.day == cacheDate.day) {
      return cached.movie;
    }

    // Cache is stale, remove it
    logger.d('Removing stale cache entry for movie $movieId (cached on ${cacheDate.month}/${cacheDate.day})');
    _movieCache.remove(movieId);
    return null;
  }

  /// Cache a movie with the current timestamp
  void cacheMovie(Movie movie) {
    final now = DateTime.now();
    _movieCache[movie.id] = _CachedMovie(
      movie: movie,
      timestamp: now,
    );
    logger.d('Cached movie ${movie.id} (${movie.title})');
  }

  // ---- Credits Caching ----

  /// Get credits from cache if they exist and were cached today
  MovieCredits? getCredits(int movieId) {
    final cached = _creditsCache[movieId];
    if (cached == null) {
      return null;
    }

    if (_isToday(cached.timestamp)) {
      return cached.credits;
    }

    logger.d('Removing stale credits cache for movie $movieId');
    _creditsCache.remove(movieId);
    return null;
  }

  /// Cache movie credits with the current timestamp
  void cacheCredits(int movieId, MovieCredits credits) {
    final now = DateTime.now();
    _creditsCache[movieId] = _CachedCredits(
      credits: credits,
      timestamp: now,
    );
    logger.d('Cached credits for movie $movieId');
  }

  // ---- Recommendations Caching ----

  /// Get recommendations from cache if they exist and were cached today
  List<SimilarMovie>? getRecommendations(int movieId) {
    final cached = _recommendationsCache[movieId];
    if (cached == null) {
      return null;
    }

    if (_isToday(cached.timestamp)) {
      return cached.recommendations;
    }

    logger.d('Removing stale recommendations cache for movie $movieId');
    _recommendationsCache.remove(movieId);
    return null;
  }

  /// Cache movie recommendations with the current timestamp
  void cacheRecommendations(int movieId, List<SimilarMovie> recommendations) {
    final now = DateTime.now();
    _recommendationsCache[movieId] = _CachedRecommendations(
      recommendations: recommendations,
      timestamp: now,
    );
    logger.d('Cached ${recommendations.length} recommendations for movie $movieId');
  }

  // ---- Trending Movies Caching ----

  /// Get trending movies from cache if they exist and were cached today
  List<MovieShort>? getTrendingMovies(String timeWindow) {
    final cached = _trendingMoviesCache[timeWindow];
    if (cached == null) {
      return null;
    }

    if (_isToday(cached.timestamp)) {
      return cached.movies;
    }

    logger.d('Removing stale trending movies cache ($timeWindow)');
    _trendingMoviesCache.remove(timeWindow);
    return null;
  }

  /// Cache trending movies with the current timestamp
  void cacheTrendingMovies(String timeWindow, List<MovieShort> movies) {
    final now = DateTime.now();
    _trendingMoviesCache[timeWindow] = _CachedTrendingMovies(
      movies: movies,
      timestamp: now,
    );
    logger.d('Cached ${movies.length} trending movies ($timeWindow)');
  }

  // ---- Cache Management ----

  /// Clear all cached data
  void clearCache() {
    final movieCount = _movieCache.length;
    final creditsCount = _creditsCache.length;
    final recommendationsCount = _recommendationsCache.length;
    final trendingCount = _trendingMoviesCache.length;
    
    _movieCache.clear();
    _creditsCache.clear();
    _recommendationsCache.clear();
    _trendingMoviesCache.clear();
    
    logger.d('Cleared all cache ($movieCount movies, $creditsCount credits, $recommendationsCount recommendations, $trendingCount trending)');
  }

  /// Clear only stale cache entries (older than today)
  void clearStaleCache() {
    final beforeMovies = _movieCache.length;
    final beforeCredits = _creditsCache.length;
    final beforeRecommendations = _recommendationsCache.length;
    final beforeTrending = _trendingMoviesCache.length;
    
    _movieCache.removeWhere((_, cached) => !_isToday(cached.timestamp));
    _creditsCache.removeWhere((_, cached) => !_isToday(cached.timestamp));
    _recommendationsCache.removeWhere((_, cached) => !_isToday(cached.timestamp));
    _trendingMoviesCache.removeWhere((_, cached) => !_isToday(cached.timestamp));
    
    final removedMovies = beforeMovies - _movieCache.length;
    final removedCredits = beforeCredits - _creditsCache.length;
    final removedRecommendations = beforeRecommendations - _recommendationsCache.length;
    final removedTrending = beforeTrending - _trendingMoviesCache.length;
    final totalRemoved = removedMovies + removedCredits + removedRecommendations + removedTrending;
    
    if (totalRemoved > 0) {
      logger.d('Removed $totalRemoved stale entries ($removedMovies movies, $removedCredits credits, $removedRecommendations recommendations, $removedTrending trending)');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final stats = {
      'movies': _movieCache.length,
      'credits': _creditsCache.length,
      'recommendations': _recommendationsCache.length,
      'trending': _trendingMoviesCache.length,
      'total': _movieCache.length + _creditsCache.length + _recommendationsCache.length + _trendingMoviesCache.length,
    };
    
    logger.d('Cache stats: ${stats['movies']} movies, ${stats['credits']} credits, ${stats['recommendations']} recommendations, ${stats['trending']} trending');
    return stats;
  }

  // ---- Helper Methods ----

  bool _isToday(DateTime timestamp) {
    final now = DateTime.now();
    return now.year == timestamp.year &&
        now.month == timestamp.month &&
        now.day == timestamp.day;
  }
}

class _CachedMovie {
  final Movie movie;
  final DateTime timestamp;

  _CachedMovie({
    required this.movie,
    required this.timestamp,
  });
}

class _CachedCredits {
  final MovieCredits credits;
  final DateTime timestamp;

  _CachedCredits({
    required this.credits,
    required this.timestamp,
  });
}

class _CachedRecommendations {
  final List<SimilarMovie> recommendations;
  final DateTime timestamp;

  _CachedRecommendations({
    required this.recommendations,
    required this.timestamp,
  });
}

class _CachedTrendingMovies {
  final List<MovieShort> movies;
  final DateTime timestamp;

  _CachedTrendingMovies({
    required this.movies,
    required this.timestamp,
  });
}
