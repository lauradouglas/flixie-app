import 'package:flutter/foundation.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/review.dart';

class ReviewReactionsController {
  const ReviewReactionsController();

  static const ReviewReactionsController instance = ReviewReactionsController();

  static final deletedReviews = ValueNotifier<Set<String>>({});
  static String keyFor(Review review) =>
      '${review.showId == null ? 'MOVIE' : 'SHOW'}:${review.id}';
  static bool isDeleted(Review review) =>
      deletedReviews.value.contains(keyFor(review));

  Future<void> deleteReview(Review review, String userId) async {
    await UserService.deleteReview(review, userId);
    deletedReviews.value = {...deletedReviews.value, keyFor(review)};
  }

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

  Future<Review> addReview(Review review) => review.showId != null
      ? UserService.addShowReview(review)
      : UserService.addMovieReview(review);
}
