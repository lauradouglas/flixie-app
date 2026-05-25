import '../models/movie_short.dart';
import '../utils/app_logger.dart';
import 'api_client.dart';

class RecommendationSourceMovie {
  final int? id;
  final String title;
  final int? rating;

  const RecommendationSourceMovie({
    required this.id,
    required this.title,
    required this.rating,
  });

  factory RecommendationSourceMovie.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    return RecommendationSourceMovie(
      id: idValue is int
          ? idValue
          : int.tryParse(idValue?.toString() ?? ''),
      title: (json['title'] ?? json['name'] ?? '') as String,
      rating: json['rating'] is int
          ? json['rating'] as int
          : (json['rating'] as num?)?.toInt(),
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
      sourceMovie: source == null
          ? null
          : RecommendationSourceMovie.fromJson(source),
      recommendations: recs,
    );
  }
}

class RecommendationService {
  static Future<List<MovieShort>> getUserRecommendations(String userId) async {
    apiLogger.d('GET /users/$userId/recommendations');
    final data = await ApiClient.get('/users/$userId/recommendations');
    return (data as List<dynamic>)
        .map((e) => MovieShort.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<RecommendationFromHighlyRatedResponse?>
      getRecommendationsFromHighlyRated() async {
    apiLogger.d('GET /recommendations/from-highly-rated');
    final data = await ApiClient.get('/recommendations/from-highly-rated');
    if (data == null) return null;

    if (data is Map<String, dynamic>) {
      return RecommendationFromHighlyRatedResponse.fromJson(data);
    }

    if (data is List<dynamic>) {
      return RecommendationFromHighlyRatedResponse(
        sourceMovie: null,
        recommendations: data
            .whereType<Map<String, dynamic>>()
            .map(MovieShort.fromJson)
            .toList(),
      );
    }

    return null;
  }
}
