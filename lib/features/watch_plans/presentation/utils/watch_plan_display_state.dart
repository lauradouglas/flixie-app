import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/watch_request.dart';

/// Semantic colours shared by Watch Plan presentation surfaces.
///
/// These describe meaning, not backend lifecycle values: an accepted plan can
/// still be [action] for one participant and [waiting] for another.
enum WatchPlanColorRole { neutral, action, waiting, complete, failed }

extension WatchPlanColorRoleStyle on WatchPlanColorRole {
  Color get color => switch (this) {
        WatchPlanColorRole.neutral => FlixieColors.primary,
        WatchPlanColorRole.action => FlixieColors.warning,
        WatchPlanColorRole.waiting => FlixieColors.secondary,
        WatchPlanColorRole.complete => FlixieColors.success,
        WatchPlanColorRole.failed => FlixieColors.danger,
      };

  Color get foreground => this == WatchPlanColorRole.neutral
      ? Colors.white
      : FlixieColors.background;
}

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
    if (!isActive(request)) return false;
    final isCreator = request.requesterId == currentUserId;
    final isIncoming = request.requesterId != currentUserId &&
        (request.recipientId == currentUserId ||
            request.participantFor(currentUserId) != null);
    final proposal = request.latestPendingProposal;
    final accepted = request.hasCurrentUserAccepted == true ||
        request.participantFor(currentUserId)?.response.toUpperCase() ==
            'ACCEPTED' ||
        isCreator;
    final unresolvedChoices = accepted &&
        request.candidates.length > 1 &&
        request.selectedCandidateId == null;
    final hasChosen = request.candidates
        .any((candidate) => candidate.selectedBy(currentUserId));
    final everyoneChose = request.candidates
            .expand((candidate) => candidate.selectedByUserIds)
            .toSet()
            .length >=
        request.analyticsParticipantCount;
    return (request.isPending && isIncoming) ||
        (proposal != null && proposal.proposerId != currentUserId) ||
        (unresolvedChoices && !isCreator && !hasChosen) ||
        (unresolvedChoices && isCreator && everyoneChose) ||
        (request.selectedCandidateId != null &&
            request.scheduledFor == null &&
            (request.canSchedule == true || isCreator));
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
