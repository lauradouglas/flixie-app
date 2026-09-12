import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/review.dart';

enum ReviewMediaType { movie, show }

/// Movie and show reviews share the backend media-review endpoint.
class MediaReviewService {
  static Future<List<Review>> getReviews(ReviewMediaType type, int id,
      {String? userId}) async {
    final data = await ApiClient.get(
        '/users/${type.name.toUpperCase()}/$id/reviews',
        queryParams: userId == null ? null : {'userId': userId});
    return (data as List<dynamic>)
        .map((item) => Review.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
