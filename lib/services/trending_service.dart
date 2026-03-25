import '../models/show.dart';
import '../models/trending_movie.dart';
import 'api_client.dart';
import 'movie_cache_service.dart';

class TrendingService {
  static final _cache = MovieCacheService();

  static Future<List<TrendingMovie>> getTrendingMovies(
      {String timeWindow = 'week'}) async {
    // Check cache first
    final cachedTrending = _cache.getTrendingMovies(timeWindow);
    if (cachedTrending != null) {
      return cachedTrending;
    }

    // Fetch from API
    print('🌐 [TrendingService] Fetching trending movies ($timeWindow) from API');
    final data = await ApiClient.get('/trending/movie/week',
        queryParams: {'timeWindow': timeWindow});
    final trendingMovies = (data as List<dynamic>)
        .map((e) => TrendingMovie.fromJson(e as Map<String, dynamic>))
        .toList();
    
    // Cache the trending movies
    _cache.cacheTrendingMovies(timeWindow, trendingMovies);
    
    return trendingMovies;
  }

  static Future<List<TvShow>> getTrendingShows(
      {String timeWindow = 'week'}) async {
    final data = await ApiClient.get('/trending/shows',
        queryParams: {'timeWindow': timeWindow});
    return (data as List<dynamic>)
        .map((e) => TvShow.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
