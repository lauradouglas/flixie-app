import 'package:flixie_app/models/watch_request.dart';

enum WatchPlanFilter {
  active,
  needsResponse,
  planning,
  scheduled,
  completed,
  declined,
  cancelled,
  expired,
}

enum FriendPostWatchState {
  nobodyLogged,
  waitingForMe,
  waitingForOthers,
  recap,
}

/// Presentation-only lifecycle decisions for direct Watch Plans.
///
/// The server models remain authoritative. This class only gives cards, lists,
/// and detail pages one shared interpretation of that state.
class WatchPlanDisplayState {
  const WatchPlanDisplayState._();

  static bool isCompleted(WatchRequest request) =>
      request.isCompleted || request.normalizedWatchedStatus == 'WATCHED';

  static bool isPostWatchDue(WatchRequest request, {DateTime? now}) {
    final time = request.scheduledFor ?? request.proposedDate;
    return !isCompleted(request) &&
        !request.isCancelled &&
        !request.isExpired &&
        time != null &&
        !time.isAfter(now ?? DateTime.now());
  }

  static bool isActive(WatchRequest request) =>
      !isCompleted(request) &&
      !request.isDeclined &&
      !request.isCancelled &&
      !request.isExpired;

  static bool needsAttention(WatchRequest request, String currentUserId) {
    final isIncoming = request.requesterId != currentUserId &&
        (request.recipientId == currentUserId ||
            request.participantFor(currentUserId) != null);
    final proposal = request.latestPendingProposal;
    return (request.isPending && isIncoming) ||
        (proposal != null && proposal.proposerId != currentUserId);
  }

  static bool isUpcoming(WatchRequest request, {DateTime? now}) =>
      request.normalizedScheduleStatus == 'AGREED' &&
      request.scheduledFor != null &&
      request.scheduledFor!.isAfter(now ?? DateTime.now());

  static bool matchesFilter(
    WatchRequest request,
    WatchPlanFilter filter,
    String currentUserId, {
    DateTime? now,
  }) {
    switch (filter) {
      case WatchPlanFilter.active:
        return isActive(request);
      case WatchPlanFilter.needsResponse:
        return isActive(request) && needsAttention(request, currentUserId);
      case WatchPlanFilter.planning:
        return isActive(request) &&
            (request.isAccepted || request.isScheduled) &&
            request.normalizedScheduleStatus != 'AGREED' &&
            !isPostWatchDue(request, now: now);
      case WatchPlanFilter.scheduled:
        return isActive(request) && isUpcoming(request, now: now);
      case WatchPlanFilter.completed:
        return isCompleted(request) || isPostWatchDue(request, now: now);
      case WatchPlanFilter.declined:
        return request.isDeclined;
      case WatchPlanFilter.cancelled:
        return request.isCancelled;
      case WatchPlanFilter.expired:
        return request.isExpired;
    }
  }

  static FriendPostWatchState postWatchState(
    WatchRequest request,
    String currentUserId,
  ) {
    final mine = request.watchConfirmations
        .any((entry) => entry.userId == currentUserId);
    final theirs = request.watchConfirmations
        .any((entry) => entry.userId != currentUserId);
    if (request.isCompleted || (mine && theirs)) {
      return FriendPostWatchState.recap;
    }
    if (mine) return FriendPostWatchState.waitingForOthers;
    if (theirs) return FriendPostWatchState.waitingForMe;
    return FriendPostWatchState.nobodyLogged;
  }

  /// Ratings stay private until the current participant has logged a watch.
  static bool canRevealOtherRatings(
    WatchRequest request,
    String currentUserId,
  ) =>
      request.watchConfirmations.any(
        (entry) => entry.userId == currentUserId && entry.watched,
      );
}
