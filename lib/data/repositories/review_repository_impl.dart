import '../../domain/repositories/review_repository.dart';
import '../../models/review.dart';
import '../../services/user_service.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  @override
  Future<({Map<String, int> reactions, String? myReaction})> reactToReview({
    required String mediaType,
    required String mediaId,
    required String reviewId,
    required String userId,
    required String? reactionType,
  }) {
    return UserService.reactToReview(
      mediaType: mediaType,
      mediaId: mediaId,
      reviewId: reviewId,
      userId: userId,
      reactionType: reactionType,
    );
  }

  @override
  Future<Review> addMovieReview(Review review) => UserService.addMovieReview(review);
}
