import 'dart:convert';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/api/api_client.dart';

class RecommendationSourceMovie {
  final int? id;
  final String title;
  final double? rating;

  const RecommendationSourceMovie({
    required this.id,
    required this.title,
    required this.rating,
  });

  factory RecommendationSourceMovie.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    return RecommendationSourceMovie(
      id: idValue is int ? idValue : int.tryParse(idValue?.toString() ?? ''),
      title: (json['title'] ?? json['name'] ?? '') as String,
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}

class RecommendationFromHighlyRatedResponse {
  final RecommendationSourceMovie? sourceMovie;
  final List<MovieShort> recommendations;

  const RecommendationFromHighlyRatedResponse({
    required this.sourceMovie,
    required this.recommendations,
  });

  factory RecommendationFromHighlyRatedResponse.fromJson(
      Map<String, dynamic> json) {
    final source = json['sourceMovie'] as Map<String, dynamic>?;
    final recs = (json['recommendations'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(MovieShort.fromJson)
        .toList();

    return RecommendationFromHighlyRatedResponse(
      sourceMovie:
          source == null ? null : RecommendationSourceMovie.fromJson(source),
      recommendations: recs,
    );
  }
}

class RecommendationService {
  /// TTL for user recommendation caches. Recommendations change infrequently
  /// so a 30-minute window avoids hitting the DB on every home-screen visit.
  static const Duration _cacheTtl = Duration(minutes: 30);

  /// Per-user cache for /users/:id/recommendations.
  static final Map<String, _CachedUserRecs> _userRecsCache = {};

  /// Per-user cache for /recommendations/from-highly-rated.
  static final Map<String, _CachedHighlyRated> _highlyRatedCache = {};

  static final Map<String, Map<bool, Future<List<MovieShort>>>> _pending = {};
  static final Map<String, Future<List<MovieShort>>> _latest = {};
  static final Map<String, _SeedOrdering> _seedOrdering = {};
  static int _session = -1;
  static int _generation = 0;
  static final Set<String> _refreshRequired = {};

  static Future<Set<int>> _loadSeedOrdering(String userId) async {
    final generation = _generation;
    final revision = ApiClient.tokenRevision;
    final seeds = (await SetupTasteStore.load(userId))
        .where((seed) => !seed.isShow)
        .take(5)
        .toList();
    if (generation != _generation || revision != ApiClient.tokenRevision) {
      throw StateError('Recommendation viewer changed');
    }
    final signature = jsonEncode(seeds.map((seed) => seed.toJson()).toList());
    final cached = _seedOrdering[userId];
    if (cached != null &&
        cached.signature == signature &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.ids;
    }
    if (seeds.isEmpty) return {};
    final ids = const SetupService()
        .recommendations(seeds)
        .then((items) => items.map((item) => item.id).toSet());
    final entry = _SeedOrdering(signature, ids, DateTime.now());
    _seedOrdering[userId] = entry;
    try {
      final result = await ids;
      if (revision != ApiClient.tokenRevision &&
          identical(_seedOrdering[userId], entry)) {
        _seedOrdering.remove(userId);
      }
      return result;
    } catch (_) {
      if (identical(_seedOrdering[userId], entry)) _seedOrdering.remove(userId);
      rethrow;
    }
  }

  static Future<List<MovieShort>> getUserRecommendations(String userId,
      {bool refresh = false}) async {
    if (_session != ApiClient.tokenRevision) {
      invalidateCache();
      _session = ApiClient.tokenRevision;
    }
    refresh = refresh || _refreshRequired.contains(userId);
    final cached = _userRecsCache[userId];
    if (!refresh && cached != null && !cached.isExpired) return cached.movies;
    final requests = _pending.putIfAbsent(userId, () => {});
    final existing = requests[refresh];
    if (existing != null) return existing;
    final revision = ApiClient.tokenRevision;
    final request = _fetchUserRecommendations(userId, refresh);
    requests[refresh] = request;
    _latest[userId] = request;
    try {
      final movies = await request;
      if (revision != ApiClient.tokenRevision ||
          !identical(_pending[userId], requests)) {
        throw StateError('Recommendation viewer changed');
      }
      if (identical(_latest[userId], request)) {
        _refreshRequired.remove(userId);
        _userRecsCache[userId] =
            _CachedUserRecs(movies: movies, fetchedAt: DateTime.now());
      }
      return movies;
    } finally {
      if (identical(_latest[userId], request)) _latest.remove(userId);
      if (identical(requests[refresh], request)) requests.remove(refresh);
      if (identical(_pending[userId], requests) && requests.isEmpty) {
        _pending.remove(userId);
      }
    }
  }

  static Future<List<MovieShort>> _fetchUserRecommendations(
      String userId, bool refresh) async {
    // Start optional taste ordering alongside the feed, and handle its error
    // immediately so a failing feed cannot leave an unobserved future behind.
    final relatedFuture =
        _loadSeedOrdering(userId).catchError((Object _) => <int>{});
    final data = await ApiClient.get('/users/$userId/recommendations',
        requestScope: 'recommendations:$_generation',
        queryParams: refresh
            ? const {'refresh': 'true', 'refreshProfile': 'false'}
            : null);
    final movies = (data as List<dynamic>)
        .map((e) => MovieShort.fromJson(e as Map<String, dynamic>))
        .toList();
    final related = await relatedFuture;
    // Only reorder eligible server results; never resurrect an excluded title.
    return [
      ...movies.where((movie) => related.contains(movie.id)),
      ...movies.where((movie) => !related.contains(movie.id)),
    ];
  }

  static Future<RecommendationFromHighlyRatedResponse?>
      getRecommendationsFromHighlyRated({String? userId}) async {
    final cacheKey = userId ?? '_anonymous_';
    final cached = _highlyRatedCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      apiLogger.d(
          'getRecommendationsFromHighlyRated [$cacheKey] - serving from cache');
      return cached.response;
    }

    final isAuthDisabled = ApiClient.getToken() == null;
    final queryParams =
        (isAuthDisabled && userId != null) ? {'userId': userId} : null;
    apiLogger.d(
        'GET /recommendations/from-highly-rated${queryParams != null ? "?userId=$userId" : ""}');
    final data = await ApiClient.get('/recommendations/from-highly-rated',
        queryParams: queryParams);

    RecommendationFromHighlyRatedResponse? result;
    if (data == null) {
      result = null;
    } else if (data is Map<String, dynamic>) {
      result = RecommendationFromHighlyRatedResponse.fromJson(data);
    } else if (data is List<dynamic>) {
      result = RecommendationFromHighlyRatedResponse(
        sourceMovie: null,
        recommendations: data
            .whereType<Map<String, dynamic>>()
            .map(MovieShort.fromJson)
            .toList(),
      );
    }

    _highlyRatedCache[cacheKey] =
        _CachedHighlyRated(response: result, fetchedAt: DateTime.now());
    return result;
  }

  /// Clears all recommendation caches (e.g. after the user rates a movie).
  static void invalidateCache({String? userId}) {
    _generation++;
    if (userId != null) {
      _refreshRequired.add(userId);
      _pending.remove(userId);
      _latest.remove(userId);
      _seedOrdering.remove(userId);
      _userRecsCache.remove(userId);
      _highlyRatedCache.remove(userId);
    } else {
      _refreshRequired.clear();
      _pending.clear();
      _latest.clear();
      _seedOrdering.clear();
      _userRecsCache.clear();
      _highlyRatedCache.clear();
    }
  }

  static Future<void> markMovieNotInterested(
    String userId,
    int movieId,
  ) async {
    await ApiClient.post('/users/$userId/movies/$movieId/not-interested',
        body: const {});
    invalidateCache(userId: userId);
  }

  static Future<void> removeMovieNotInterested(
    String userId,
    int movieId,
  ) async {
    await ApiClient.delete('/users/$userId/movies/$movieId/not-interested');
    invalidateCache(userId: userId);
  }
}

class _CachedUserRecs {
  final List<MovieShort> movies;
  final DateTime fetchedAt;

  _CachedUserRecs({required this.movies, required this.fetchedAt});

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) > RecommendationService._cacheTtl;
}

class _CachedHighlyRated {
  final RecommendationFromHighlyRatedResponse? response;
  final DateTime fetchedAt;

  _CachedHighlyRated({required this.response, required this.fetchedAt});

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) > RecommendationService._cacheTtl;
}

class _SeedOrdering {
  final String signature;
  final Future<Set<int>> ids;
  final DateTime fetchedAt;
  _SeedOrdering(this.signature, this.ids, this.fetchedAt);
}
