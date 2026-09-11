import 'package:flixie_app/models/friend_recommendation.dart';
import 'package:flixie_app/models/friend_summary.dart';
import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/models/movie_images.dart';
import 'package:flixie_app/models/movie_credits.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/similar_movie.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/top_rated_movie.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/activity_feed_ranking.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/storage/movie_cache_service.dart';

class MovieService {
  MovieService();

  final _cache = MovieCacheService();

  // A refresh must not join a request started before cache eviction.
  Future<dynamic> _get(String path, {Map<String, String>? queryParams}) =>
      ApiClient.get(path,
          queryParams: queryParams,
          requestScope: 'movie-metadata:${_cache.revision}');

  /// Update a movie in the cache with new data.
  void updateCachedMovie(Movie movie) {
    _cache.cacheMovie(movie);
  }

  Future<Movie> getMovieById(int id, {String? userId}) async {
    final revision = _cache.revision;
    final cachedMovie = _cache.getMovie(id);
    if (cachedMovie != null) return cachedMovie;

    apiLogger.d('Fetching movie $id.');
    // Shared cache contains metadata only; viewer data loads separately.
    final queryParams = {'includeReviews': 'false'};
    try {
      final data = await _get('/movies/id/$id', queryParams: queryParams);
      final movie = Movie.fromJson(data as Map<String, dynamic>);
      if (revision == _cache.revision) {
        _cache.cacheMovie(movie);
      }
      return movie;
    } on ApiException catch (e) {
      // On a DATABASE_ERROR serve any stale cached copy so the UI doesn't
      // crash with "Failed to load movie". The retry logic in ApiClient will
      // already have attempted the request up to _maxRetries times.
      if (e.statusCode == 500 && e.code == 'DATABASE_ERROR') {
        final stale = _cache.getStaleCachedMovie(id);
        if (stale != null) {
          apiLogger.w(
              'DATABASE_ERROR for movie $id - serving stale cache to avoid blank screen.');
          return stale;
        }
      }
      rethrow;
    }
  }

  Future<MovieImages> getMovieImages(int id) async {
    final data = await _get('/movies/$id/images');
    return MovieImages.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Movie>> getMoviesByIds(List<int> ids) async {
    final data = await ApiClient.post('/movies/by-ids', body: {'ids': ids});
    return (data as List<dynamic>)
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> addMovieRating(
      int movieId, String userId, int rating, bool? recommended) async {
    final data = await ApiClient.post('/movies/$movieId/add/rating', body: {
      'userId': userId,
      'rating': rating,
      'recommended': recommended,
    });
    return data as Map<String, dynamic>;
  }

  Future<({int? rating, bool? recommended})> getUserMovieRating(
      int movieId, String userId) async {
    try {
      final data = await ApiClient.post('/movies/$movieId/user/rating',
          body: {'userId': userId});
      if (data != null && data is Map<String, dynamic>) {
        final r = data['rating'];
        return (
          rating: r == null ? null : (r as num).toInt(),
          recommended: data['recommended'] as bool?,
        );
      }
    } catch (_) {
      rethrow;
    }
    return (rating: null, recommended: null);
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
    final revision = _cache.revision;
    final cachedRecommendations = _cache.getRecommendations(movieId);
    if (cachedRecommendations != null) return cachedRecommendations;

    apiLogger.d('Fetching recommendations for movie $movieId.');
    final data = await _get('/movies/$movieId/recommendations');
    final recommendations = (data as List<dynamic>)
        .map((e) => SimilarMovie.fromJson(e as Map<String, dynamic>))
        .toList();
    if (revision == _cache.revision) {
      _cache.cacheRecommendations(movieId, recommendations);
    }
    return recommendations;
  }

  Future<MovieCredits> getMovieCredits(int movieId) async {
    final revision = _cache.revision;
    final cachedCredits = _cache.getCredits(movieId);
    if (cachedCredits != null) return cachedCredits;

    apiLogger.d('Fetching credits for movie $movieId.');
    final data = await _get('/movies/$movieId/credits');
    final credits = MovieCredits.fromJson(data as Map<String, dynamic>);
    if (revision == _cache.revision) {
      _cache.cacheCredits(movieId, credits);
    }
    return credits;
  }

  Future<List<WatchProvider>> getMovieWatchProviders(
      int movieId, String region) async {
    final revision = _cache.revision;
    final cached = _cache.getWatchProviders(movieId, region);
    if (cached != null) return cached;

    apiLogger
        .d('Fetching watch providers for movie $movieId in region $region.');

    List<WatchProvider> parseProviders(dynamic data) {
      Iterable<dynamic> typedList(String type, dynamic value) {
        if (value is! Iterable) return const [];
        return value.whereType<Map<String, dynamic>>().map(
              (provider) => {
                ...provider,
                'availabilityType': type,
              },
            );
      }

      final rawList = data is Map<String, dynamic>
          ? [
              ...typedList('stream', data['stream'] ?? data['flatrate']),
              ...typedList('buy', data['buy']),
              ...typedList('rent', data['rent']),
              ...typedList('stream', data['watchProviders']),
              ...typedList('stream', data['providers']),
              ...typedList('stream', data['results']),
            ]
          : (data as List<dynamic>? ?? const []);
      return rawList
          .map((e) => WatchProvider.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    try {
      final detailData = await _get('/movies/$movieId/$region/watch/providers');
      final providers = parseProviders(detailData);
      if (revision == _cache.revision) {
        _cache.cacheWatchProviders(movieId, region, providers);
      }
      return providers;
    } catch (detailError) {
      apiLogger.w(
        'Detail watch-provider endpoint failed for movie $movieId/$region: $detailError. Trying cache endpoint.',
      );
      final cacheData = await _get(
        '/movies/$movieId/watch-providers',
        queryParams: {'region': region},
      );
      final providers = parseProviders(cacheData);
      if (revision == _cache.revision) {
        _cache.cacheWatchProviders(movieId, region, providers);
      }
      return providers;
    }
  }

  Future<List<Review>> getMovieReviews(int movieId, {String? userId}) async {
    apiLogger.d('Fetching reviews for movie $movieId from API');
    final data = await _get('/users/MOVIE/$movieId/reviews',
        queryParams: userId != null ? {'userId': userId} : null);
    return (data as List<dynamic>)
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TopRatedMovie>> getTopRatedThisWeek({int limit = 10}) async {
    apiLogger.d('Fetching top rated movies this week');
    final data = await _get('/movies/top_rated/this_week',
        queryParams: {'limit': '$limit'});
    return (data as List<dynamic>)
        .map((e) => TopRatedMovie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MovieFriendActivity>> getFriendsMovieActivity(
      int movieId, String userId) async {
    apiLogger.d('Fetching friends activity for movie $movieId');
    final data = await _get('/movies/id/$movieId/friends-activity',
        queryParams: {'userId': userId});
    final activities = (data as List<dynamic>)
        .where(
            (entry) => entry is Map<String, dynamic> && entry['list'] == null)
        .map((e) => MovieFriendActivity.fromJson(e as Map<String, dynamic>))
        .toList();
    return rankMovieFriendActivities(activities);
  }

  Future<List<MovieShort>> getTopRatedMovies({String region = 'US'}) async {
    apiLogger.d('Fetching top rated movies for region $region');
    final data =
        await _get('/movies/top_rated', queryParams: {'region': region});
    return (data as List<dynamic>)
        .map((e) => MovieShort.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MovieShort>> getNowPlayingMovies({String region = 'US'}) async {
    apiLogger.d('Fetching now playing movies for region $region');
    final data =
        await _get('/movies/now_playing', queryParams: {'region': region});
    return (data as List<dynamic>)
        .map((e) => MovieShort.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FriendRecommendationResponse> getFriendRecommendation(
      int movieId) async {
    apiLogger.d('Fetching friend recommendation for movie $movieId');
    final data = await _get('/movies/$movieId/friend-recommendation');
    return FriendRecommendationResponse.fromJson(data as Map<String, dynamic>);
  }

  /// Bounded sequential batches; failed chunks do not discard successful ones.
  /// No cache: every call reads current friendships and recommendations.
  Future<Map<int, FriendRecommendationResponse>> getFriendRecommendations(
      Iterable<int> movieIds,
      {bool Function()? isCurrent}) async {
    final ids = movieIds.where((id) => id > 0).toSet().toList();
    final results = <int, FriendRecommendationResponse>{};
    for (var start = 0; start < ids.length; start += 25) {
      if (isCurrent != null && !isCurrent()) break;
      final chunk = ids.skip(start).take(25).toList();
      try {
        final data = await ApiClient.post('/movies/friend-recommendations',
            body: {'movieIds': chunk});
        for (final item in data['items'] as List) {
          try {
            final id = int.parse(item['movieId'].toString());
            if (chunk.contains(id)) {
              results[id] = FriendRecommendationResponse.fromJson(
                  Map<String, dynamic>.from(item as Map));
            }
          } catch (_) {
            // A malformed item must not hide other films in this batch.
          }
        }
      } catch (error) {
        if (error is ApiException &&
            (error.statusCode == 401 || error.statusCode == 403)) {
          rethrow;
        }
        apiLogger.w('Friend recommendation batch failed: $error');
      }
    }
    return results;
  }

  Future<FriendSummaryResponse> getFriendSummary(int movieId) async {
    apiLogger.d('Fetching friend summary for movie $movieId');
    final data = await _get('/movies/$movieId/friend-summary');
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
