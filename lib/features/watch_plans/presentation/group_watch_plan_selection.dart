import 'package:flixie_app/core/utils/watch_plan_schedule.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';

enum GroupPlanStage {
  declined,
  invite,
  picking,
  finalMovie,
  waitingMovie,
  chooseTime,
  proposal,
  scheduled,
  postWatch,
  recap,
  closed,
}

/// Immutable per-plan projection; keeps group membership and viewer identity together.
class GroupPlanViewData {
  const GroupPlanViewData({
    required this.request,
    required this.userId,
    required this.members,
    required this.groupName,
  });
  final GroupWatchRequest request;
  final String userId;
  final List<GroupMember> members;
  final String groupName;
  bool get declined =>
      request.userId != userId &&
      (request.currentUserResponse == WatchResponseDecision.declined ||
          request.memberStatuses.any(
            (item) => item.memberId == userId && item.status == 'DECLINED',
          ));

  bool get accepted =>
      request.userId == userId ||
      request.hasCurrentUserAccepted == true ||
      request.currentUserResponse == WatchResponseDecision.accepted ||
      request.memberStatuses.any(
        (item) => item.memberId == userId && item.status == 'ACCEPTED',
      );

  bool get everyonePicked {
    final active = activeMembers.map((item) => item.memberId).toSet();
    final voters = request.candidates
        .expand((candidate) => candidate.selectedByUserIds)
        .toSet();
    return active.isNotEmpty && voters.containsAll(active);
  }

  List<GroupMember> get activeMembers {
    final declined = request.memberStatuses
        .where((item) => item.status == 'DECLINED')
        .map((item) => item.memberId)
        .toSet();
    return members
        .where((member) => !declined.contains(member.memberId))
        .toList(growable: false);
  }

  GroupWatchPlanCandidate? get selectedCandidate => request.candidates
      .where((item) => item.id == request.selectedCandidateId)
      .firstOrNull;

  GroupPlanStage get stage {
    if (declined) {
      return GroupPlanStage.declined;
    }
    if (request.isArchived) {
      return request.status == WatchRequestStatus.completed
          ? GroupPlanStage.recap
          : GroupPlanStage.closed;
    }
    if (accepted &&
        request.selectedCandidateId == null &&
        request.candidates.isNotEmpty) {
      if (request.userId == userId && everyonePicked) {
        return GroupPlanStage.finalMovie;
      }
      return GroupPlanStage.picking;
    }
    if (request.selectedCandidateId != null &&
        request.activeScheduleProposal != null) {
      return GroupPlanStage.proposal;
    }
    final scheduled = DateTime.tryParse(request.scheduledFor ?? '')?.toLocal();
    if (scheduled != null) {
      return !watchPlanScheduleHasPassed(
        scheduled,
        dateOnly: request.scheduledDateOnly,
      )
          ? GroupPlanStage.scheduled
          : GroupPlanStage.postWatch;
    }
    if (!accepted && request.userId != userId) {
      return GroupPlanStage.invite;
    }
    if (request.selectedCandidateId != null &&
        request.proposedDate?.isNotEmpty == true) {
      return GroupPlanStage.proposal;
    }
    if (request.selectedCandidateId != null && request.userId == userId) {
      return GroupPlanStage.chooseTime;
    }
    return GroupPlanStage.waitingMovie;
  }
}

DateTime groupPlanDate(GroupWatchRequest request) =>
    DateTime.tryParse(
      request.scheduledFor ??
          request.proposedDate ??
          request.updatedAt ??
          request.createdAt ??
          '',
    ) ??
    DateTime.fromMillisecondsSinceEpoch(0);
