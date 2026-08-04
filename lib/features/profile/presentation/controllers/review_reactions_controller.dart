import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/review.dart';

class ReviewReactionsController {
  const ReviewReactionsController();

  static const ReviewReactionsController instance = ReviewReactionsController();

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

  Future<Review> addMovieReview(Review review) =>
      UserService.addMovieReview(review);
}
