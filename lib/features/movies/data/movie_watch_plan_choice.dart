import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';

class MovieWatchPlanChoice {
  const MovieWatchPlanChoice(
      {required this.id, required this.label, required this.save});
  final String id;
  final String label;
  final Future<void> Function(
      {String? watchedAt,
      double? rating,
      bool? recommended,
      String? notes}) save;

  /// An agreed plan can be logged early; notification due-state is not eligibility.
  static bool canLinkDirect(WatchRequest plan, String userId, int movieId) =>
      plan.isWatchRequest &&
      plan.movieId == movieId &&
      plan.showId == null &&
      !plan.isCancelled &&
      !plan.isExpired &&
      !plan.isDeclined &&
      (plan.requesterId == userId ||
          plan.recipientId == userId ||
          plan.participantFor(userId)?.response.toUpperCase() == 'ACCEPTED') &&
      plan.hasCurrentUserLoggedWatch != true &&
      !plan.hasCurrentUserConfirmed(userId) &&
      ((plan.normalizedScheduleStatus == 'AGREED' &&
              plan.scheduledFor != null) ||
          plan.canConfirmWatchedFor(userId));

  static Future<List<MovieWatchPlanChoice>> load(
      String userId, int movieId) async {
    final directFuture =
        RequestService.getWatchRequests(userId, includeHomeState: true);
    final groupsFuture = GroupService.getHomeGroupWatchPlans();
    await Future.wait<dynamic>([directFuture, groupsFuture]);
    final direct = await directFuture;
    final groups = await groupsFuture;
    return [
      for (final plan in direct)
        if (canLinkDirect(plan, userId, movieId))
          MovieWatchPlanChoice(
              id: 'direct:${plan.id}',
              label:
                  'With ${plan.otherUser(userId)?.displayName ?? 'your friends'}',
              save: ({watchedAt, rating, recommended, notes}) async {
                await RequestService.confirmWatchRequest(
                    watchRequestId: plan.id,
                    userId: userId,
                    watched: true,
                    watchedAt: watchedAt,
                    rating: rating?.round(),
                    recommended: recommended,
                    reviewText: notes);
              }),
      for (final item in groups)
        if (item.request.mediaType == 'movie' &&
            item.request.mediaId == movieId &&
            item.request.canCompleteFor(userId))
          MovieWatchPlanChoice(
              id: 'group:${item.request.id}',
              label: 'With ${item.group.name}',
              save: ({watchedAt, rating, recommended, notes}) async {
                await GroupService.logGroupWatchPlan(item.request, userId,
                    watchedAt: watchedAt,
                    rating: rating?.round(),
                    recommended: recommended,
                    reviewText: notes);
              }),
    ];
  }
}
