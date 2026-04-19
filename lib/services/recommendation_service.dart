import '../models/movie_short.dart';
import '../utils/app_logger.dart';
import 'api_client.dart';

class RecommendationService {
  static Future<List<MovieShort>> getUserRecommendations(String userId) async {
    apiLogger.d('GET /users/$userId/recommendations');
    final data = await ApiClient.get('/users/$userId/recommendations');
    return (data as List<dynamic>)
        .map((e) => MovieShort.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
