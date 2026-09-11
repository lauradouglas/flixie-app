import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/models/watch_request.dart';

// Keep this adapter identical for full detail and compact Home payloads.
WatchRequest asHomeGroupWatchPlan(Group group, GroupWatchRequest request) {
  final requester = WatchRequestUser(
    id: request.userId,
    username: request.requesterUsername ?? 'Group member',
    avatar: request.requesterAvatar,
  );
  final participants = request.memberStatuses
      .map((member) => WatchRequestParticipant(
            user: WatchRequestUser(
              id: member.memberId,
              username: member.username ?? 'Group member',
              avatar: member.avatar,
            ),
            response: member.status,
          ))
      .toList(growable: false);
  return WatchRequest(
    // Use the canonical Postgres ID everywhere reminders are scheduled.
    // The chat mirror ID may differ and previously created a duplicate set
    // when Home and the group plan screen both refreshed the same plan.
    id: request.databaseRequestId ?? request.id,
    requesterId: request.userId,
    recipientId: '',
    status: request.status.apiValue,
    type: request.mediaType?.toLowerCase() == 'show'
        ? 'SHOW_WATCH_REQUEST'
        : 'MOVIE_WATCH_REQUEST',
    movieId:
        request.mediaType?.toLowerCase() == 'show' ? null : request.mediaId,
    showId: request.mediaType?.toLowerCase() == 'show' ? request.mediaId : null,
    createdAt: request.createdAt,
    updatedAt: request.updatedAt,
    scheduledFor: DateTime.tryParse(request.scheduledFor ?? ''),
    location: request.location,
    scheduleStatus: request.scheduledFor == null ? 'NONE' : 'AGREED',
    groupId: group.id,
    groupName: group.name,
    // A private marker lets the shared card open the group plan, not the
    // direct-plan detail route.
    conversationId: '__group_home__',
    selectedCandidateId: request.selectedCandidateId,
    proposedDate: DateTime.tryParse(request.proposedDate ?? ''),
    scheduleProposals: request.scheduleProposals
        .map((proposal) => WatchScheduleProposal(
              id: proposal.id,
              proposerId: proposal.proposerId,
              proposedFor: DateTime.tryParse(proposal.proposedFor ?? ''),
              location: proposal.location,
              status: proposal.status,
              responses: proposal.responses
                  .map((response) => WatchScheduleProposalResponse(
                        userId: response.userId,
                        status: response.status,
                      ))
                  .toList(growable: false),
            ))
        .toList(growable: false),
    candidates: request.candidates
        .map((candidate) => WatchPlanCandidate(
              id: candidate.id,
              movieId: candidate.movieId,
              showId: candidate.showId,
              mediaType: candidate.showId != null ? 'show' : 'movie',
              addedByUserId: candidate.addedByUserId,
              addedByUsername: candidate.addedByUsername,
              addedByAvatar: candidate.addedByAvatar,
              title: candidate.title,
              posterPath: candidate.posterPath,
              selectedByUserIds: candidate.selectedByUserIds,
            ))
        .toList(growable: false),
    hasCurrentUserAccepted: request.hasCurrentUserAccepted,
    hasCurrentUserCompleted: request.hasCurrentUserCompleted,
    canSchedule: request.canSchedule,
    canComplete: request.canComplete,
    requester: requester,
    createdBy: requester,
    participants: participants,
    watchConfirmations: request.memberStatuses
        .where((member) => member.watchedAt != null || member.missedAt != null)
        .map((member) => WatchConfirmation(
              id: 'group-${request.id}-${member.memberId}',
              userId: member.memberId,
              watched: member.watchedAt != null,
            ))
        .toList(growable: false),
    movie: WatchRequestMovieDetails(
      id: request.mediaId ?? 0,
      title: request.movieTitle ?? 'Watch plan',
      posterPath: request.moviePosterPath,
    ),
  );
}
