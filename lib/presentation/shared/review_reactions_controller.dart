import '../../data/repositories/review_repository_impl.dart';
import '../../domain/usecases/review_reactions_usecase.dart';
import '../../models/review.dart';

class ReviewReactionsController {
  ReviewReactionsController({ReviewReactionsUseCase? useCase})
      : _useCase = useCase ?? ReviewReactionsUseCase(ReviewRepositoryImpl());

  static final ReviewReactionsController instance = ReviewReactionsController();

  final ReviewReactionsUseCase _useCase;

  Future<({Map<String, int> reactions, String? myReaction})> reactToReview({
    required String mediaType,
    required String mediaId,
    required String reviewId,
    required String userId,
    required String? reactionType,
  }) {
    return _useCase.reactToReview(
      mediaType: mediaType,
      mediaId: mediaId,
      reviewId: reviewId,
      userId: userId,
      reactionType: reactionType,
    );
  }

  Future<Review> addMovieReview(Review review) => _useCase.addMovieReview(review);
}
