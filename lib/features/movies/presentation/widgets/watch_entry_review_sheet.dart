import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/review.dart';
import 'write_review_sheet.dart';

/// Continues a saved watch into the full editor without publishing a review yet.
Future<void> showWatchEntryReviewSheet(
  BuildContext context, {
  required String userId,
  required int movieId,
  String? mediaTitle,
  String? watchedAt,
  String? watchEntryId,
  double? rating,
  bool? recommended,
  String? initialTitle,
  String? initialBody,
  bool initialContainsSpoilers = false,
}) async {
  if (!context.mounted) return;
  final auth = context.read<AuthProvider>();
  if (auth.dbUser?.id != userId) return;
  // Compact plan responses can omit the title. Read the complete saved watch
  // before editing so submitting cannot replace an existing title with a blank.
  if (watchEntryId != null &&
      initialBody?.isNotEmpty == true &&
      initialTitle == null) {
    try {
      final watches = await UserService.getMovieWatchHistory(userId, movieId);
      final existing =
          watches.where((watch) => watch.id == watchEntryId).firstOrNull;
      initialTitle = existing?.reviewTitle;
      if (initialTitle == null) throw StateError('Review title unavailable');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.error,
            content: const Text(
                'Watch saved. Couldn’t load your review. Reopen the watch entry to try again.')));
      }
      return;
    }
    if (!context.mounted || auth.dbUser?.id != userId) return;
  }
  await showModalBottomSheet<Review>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => WriteReviewSheet(
      userId: userId,
      movieId: movieId,
      mediaTitle: mediaTitle,
      initialWatchedAt: watchedAt,
      watchEntryId: watchEntryId,
      initialRating: rating,
      initialRecommended: recommended,
      initialTitle: initialTitle ?? '',
      initialBody: initialBody ?? '',
      initialContainsSpoilers: initialContainsSpoilers,
      onSubmitted: (_) {
        if (auth.dbUser?.id != userId) return;
        auth.invalidateCachedReviews();
        auth.markActivityChanged();
      },
    ),
  );
}
