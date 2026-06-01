import '../../models/review.dart';
import '../repositories/review_repository.dart';

class ReviewReactionsUseCase {
  ReviewReactionsUseCase(this._reviewRepository);

  final ReviewRepository _reviewRepository;

  Future<({Map<String, int> reactions, String? myReaction})> reactToReview({
    required String mediaType,
    required String mediaId,
    required String reviewId,
    required String userId,
    required String? reactionType,
  }) {
    return _reviewRepository.reactToReview(
      mediaType: mediaType,
      mediaId: mediaId,
      reviewId: reviewId,
      userId: userId,
      reactionType: reactionType,
    );
  }

  Future<Review> addMovieReview(Review review) => _reviewRepository.addMovieReview(review);
}
