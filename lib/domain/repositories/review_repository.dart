import '../../models/review.dart';

abstract class ReviewRepository {
  Future<({Map<String, int> reactions, String? myReaction})> reactToReview({
    required String mediaType,
    required String mediaId,
    required String reviewId,
    required String userId,
    required String? reactionType,
  });

  Future<Review> addMovieReview(Review review);
}
