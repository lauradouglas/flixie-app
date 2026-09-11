import 'package:flixie_app/models/watch_request.dart';

// Extracted unchanged from Home so full and compact retrieval can be compared.
List<WatchRequest> watchPlansForHome(
  List<WatchRequest> requests, {
  required String userId,
  DateTime? at,
  required Set<String> closedPlanIds,
}) {
  final now = at ?? DateTime.now();
  final plans = requests.where((request) {
    final completedAt = request.completedAt ?? request.lastActivityAt;
    final recentCompletion = completedAt == null ||
        completedAt.isAfter(now.subtract(const Duration(days: 7)));
    return request.isWatchRequest &&
        !request.isCancelled &&
        !request.isExpired &&
        !request.isDeclined &&
        !(request.groupId != null &&
            request.participantFor(userId)?.response.toUpperCase() ==
                'DECLINED') &&
        !closedPlanIds.contains(request.id) &&
        (!request.isCompleted || recentCompletion);
  }).toList()
    ..sort(
      (left, right) {
        final leftRank = _homeWatchPlanRank(left, userId, now);
        final rightRank = _homeWatchPlanRank(right, userId, now);
        if (leftRank != rightRank) return leftRank.compareTo(rightRank);

        final leftTime = left.scheduledFor;
        final rightTime = right.scheduledFor;
        if (leftRank == 2) {
          // Put the most recently missed log prompt first.
          return (rightTime ?? now).compareTo(leftTime ?? now);
        }
        final leftFallback = DateTime.tryParse(left.createdAt ?? '') ?? now;
        final rightFallback = DateTime.tryParse(right.createdAt ?? '') ?? now;
        return (leftTime ?? leftFallback).compareTo(rightTime ?? rightFallback);
      },
    );
  return plans;
}

bool _watchPlanNeedsResponse(WatchRequest request, String userId) {
  if (request.isPending && request.requesterId != userId) return true;
  final proposal = request.latestPendingProposal;
  return request.normalizedScheduleStatus == 'PROPOSED' &&
      proposal != null &&
      proposal.proposerId != userId;
}

int _homeWatchPlanRank(WatchRequest request, String userId, DateTime now) {
  final scheduledFor = request.scheduledFor?.toLocal();
  if (scheduledFor != null && scheduledFor.isAfter(now)) {
    final isToday = scheduledFor.year == now.year &&
        scheduledFor.month == now.month &&
        scheduledFor.day == now.day;
    if (isToday) return 0;
  }
  if (_watchPlanNeedsResponse(request, userId)) return 1;
  if (scheduledFor != null && !scheduledFor.isAfter(now)) return 2;
  return 3;
}
