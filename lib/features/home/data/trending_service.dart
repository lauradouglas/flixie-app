import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/storage/movie_cache_service.dart';

class TrendingService {
  static final _cache = MovieCacheService();
  static final _movieRequests = <String, Future<List<MovieShort>>>{};

  /// Per-timeWindow cache for trending shows (same day-level TTL as movies).
  static final Map<String, _CachedTrendingShows> _showsCache = {};

  static Future<List<MovieShort>> getTrendingMovies(
      {String timeWindow = 'day', bool refresh = false}) async {
    // Check cache first
    final cachedTrending =
        refresh ? null : _cache.getTrendingMovies(timeWindow);
    if (cachedTrending != null) {
      return cachedTrending;
    }

    final pending = _movieRequests[timeWindow];
    if (pending != null) return pending;
    final request = _fetchMovies(timeWindow);
    _movieRequests[timeWindow] = request;
    try {
      return await request;
    } finally {
      if (identical(_movieRequests[timeWindow], request)) {
        _movieRequests.remove(timeWindow);
      }
    }
  }

  static Future<List<MovieShort>> _fetchMovies(String timeWindow) async {
    final data = await ApiClient.get('/trending/movie/$timeWindow');
    final movies = (data as List<dynamic>)
        .map((e) => MovieShort.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache.cacheTrendingMovies(timeWindow, movies);
    return movies;
  }

  static Future<List<TvShow>> getTrendingShows(
      {String timeWindow = 'week'}) async {
    final cached = _showsCache[timeWindow];
    if (cached != null && cached.isValidToday) {
      return cached.shows;
    }

    final data = await ApiClient.get('/trending/show/$timeWindow');
    final shows = (data as List<dynamic>)
        .map((e) => TvShow.fromJson(e as Map<String, dynamic>))
        .toList();

    _showsCache[timeWindow] =
        _CachedTrendingShows(shows: shows, timestamp: DateTime.now());

    return shows;
  }
}

class _CachedTrendingShows {
  final List<TvShow> shows;
  final DateTime timestamp;

  _CachedTrendingShows({required this.shows, required this.timestamp});

  bool get isValidToday {
    final now = DateTime.now();
    return now.year == timestamp.year &&
        now.month == timestamp.month &&
        now.day == timestamp.day;
  }
}
