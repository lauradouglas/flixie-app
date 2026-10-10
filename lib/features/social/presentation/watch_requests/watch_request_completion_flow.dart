import '../widgets/social_account_sheet.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/reviews/app_review_service.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/share_card_sheet.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_watch_plan_types.dart';

import 'watch_request_action_context.dart';

class WatchRequestCompletionFlow extends WatchRequestActionContext {
  WatchRequestCompletionFlow(
      {required super.context, required super.controller});
  Future<void> confirmWatched(WatchRequest request) async {
    if (!context.mounted || !controller.owns) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    final analytics = context.read<AnalyticsController>();
    final movieService = context.read<MovieService>();
    if (userId == null || userId.isEmpty) return;
    final hasCompletedSetup =
        context.read<AuthProvider>().dbUser?.completedSetup == true;
    final existing = request.watchConfirmations
        .where((c) => c.userId == userId && c.watched)
        .firstOrNull;
    var saved = false;
    int? savedRating;
    bool? savedRecommended;
    String? savedNote;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      backgroundColor: Colors.transparent,
      builder: (_) => SocialAccountSheet(
          viewer: controller.viewer,
          child: RewatchLogSheet(
            isPlanReview: true,
            initial: existing == null
                ? null
                : MovieWatchEntry(
                    id: existing.id,
                    userId: userId,
                    movieId: request.movieId ?? 0,
                    rating: existing.rating?.toDouble(),
                    recommended: existing.recommended,
                    notes: existing.reviewText,
                    removed: false,
                  ),
            showReviewOption: false,
            onSubmit: ({
              required watchedAt,
              required rating,
              required recommended,
              required notes,
            }) async {
              savedRating = rating?.round();
              savedRecommended = recommended;
              savedNote = notes;
              await runAction(request, FriendWatchPlanAction.completing,
                  () async {
                final state = await RequestService.confirmWatchRequest(
                  watchRequestId: request.id,
                  userId: userId,
                  watched: true,
                  rating: rating?.round(),
                  reviewText: notes,
                  watchedAt: watchedAt,
                  recommended: recommended,
                );
                if (!context.mounted || !controller.owns) return;
                // The watch-plan endpoint also performs this sync, but verify it
                // through the movie endpoint as a compatibility safeguard for
                // local/older API deployments. A plan rating should always become
                // the user's overall rating for that movie.
                final movieId = state.request.movieId;
                if (savedRating != null && movieId != null) {
                  try {
                    final overallRating =
                        await movieService.getUserMovieRating(movieId, userId);
                    if (!context.mounted || !controller.owns) return;
                    if (overallRating.rating != savedRating ||
                        overallRating.recommended != savedRecommended) {
                      await movieService.addMovieRating(
                        movieId,
                        userId,
                        savedRating!,
                        savedRecommended,
                      );
                    }
                  } catch (error, stackTrace) {
                    logger.w(
                      'Watch plan was saved, but its movie rating could not be reconciled.',
                      error: error,
                      stackTrace: stackTrace,
                    );
                  }
                }
                if (!context.mounted || !controller.owns) return;
                replaceRequest(state.request);
                await PushNotificationService.cancelWatchPlanReminders(
                  state.request.id,
                );
                final contentId = state.request.analyticsContentId;
                if (contentId != null) {
                  await analytics.watchLogged(
                    contentType: state.request.analyticsContentType,
                    contentId: contentId,
                    source: 'watch_plan',
                    watchPlanId: state.request.id,
                    planType: state.request.analyticsPlanType,
                    participantCount: state.request.analyticsParticipantCount,
                  );
                }
                if (!context.mounted || !controller.owns) return;
                context.read<AuthProvider>().markActivityChanged();
                if (!request.isCompleted && state.request.isCompleted) {
                  await analytics.watchPlanCompleted(
                    watchPlanId: state.request.id,
                    contentId: state.request.analyticsContentId,
                    contentType: state.request.analyticsContentType,
                    planType: state.request.analyticsPlanType,
                    participantCount: state.request.analyticsParticipantCount,
                    source: 'watch_plan',
                  );
                  await AppReviewService.recordCompletedWatchPlan(
                    userId,
                    hasCompletedSetup: hasCompletedSetup,
                  );
                }
                saved = true;
              });
            },
          )),
    );
    if (!context.mounted || !controller.owns || !saved) return;
    ScaffoldMessenger.of(context).showFlixieToast(
      FlixieToast(
        type: FlixieToastType.success,
        content: const Text('Watch entry saved to your plan'),
        backgroundColor: context.colors.surfaceElevated,
      ),
    );
    final user = context.read<AuthProvider>().dbUser;
    final movie = request.movie;
    if (savedRating != null && user != null && movie != null) {
      promptShareCard(
        context,
        ShareCardData.rating(
          mediaType: ShareCardMediaType.movie,
          mediaId: movie.id,
          title: movie.title,
          posterPath: movie.posterPath,
          user: user,
          rating: savedRating!,
          recommended: savedRecommended,
          note: savedNote,
        ),
      );
    }
  }
}
