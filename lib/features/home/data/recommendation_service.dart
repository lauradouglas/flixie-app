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

  static Future<List<MovieShort>> getUserRecommendations(String userId) async {
    final cached = _userRecsCache[userId];
    if (cached != null && !cached.isExpired) {
      apiLogger.d('getUserRecommendations [$userId] — serving from cache');
      return cached.movies;
    }

    apiLogger.d('GET /users/$userId/recommendations');
    final data = await ApiClient.get('/users/$userId/recommendations');
    final movies = (data as List<dynamic>)
        .map((e) => MovieShort.fromJson(e as Map<String, dynamic>))
        .toList();
    _userRecsCache[userId] =
        _CachedUserRecs(movies: movies, fetchedAt: DateTime.now());
    return movies;
  }

  static Future<RecommendationFromHighlyRatedResponse?>
      getRecommendationsFromHighlyRated({String? userId}) async {
    final cacheKey = userId ?? '_anonymous_';
    final cached = _highlyRatedCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      apiLogger.d(
          'getRecommendationsFromHighlyRated [$cacheKey] — serving from cache');
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
    if (userId != null) {
      _userRecsCache.remove(userId);
      _highlyRatedCache.remove(userId);
    } else {
      _userRecsCache.clear();
      _highlyRatedCache.clear();
    }
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
