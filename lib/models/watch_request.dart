import 'package:flixie_app/models/profile_avatar.dart';

/// The product-facing stage of a [WatchRequest].
///
/// Requests remain the storage/API name for backwards compatibility, but the
/// UI treats them as a watch plan with one clear next step for each person.
enum WatchPlanStage {
  needsReply,
  waitingForReplies,
  planning,
  upcoming,
  past,
  cancelled,
  expired,
}

extension WatchPlanStageCopy on WatchPlanStage {
  String get label => switch (this) {
        WatchPlanStage.needsReply => 'Needs reply',
        WatchPlanStage.waitingForReplies => 'Waiting for replies',
        WatchPlanStage.planning => 'Planning',
        WatchPlanStage.upcoming => 'Upcoming',
        WatchPlanStage.past => 'Past',
        WatchPlanStage.cancelled => 'Cancelled',
        WatchPlanStage.expired => 'Expired',
      };

  String get primaryActionLabel => switch (this) {
        WatchPlanStage.needsReply => 'Reply',
        WatchPlanStage.waitingForReplies => 'View plan',
        WatchPlanStage.planning => 'Continue planning',
        WatchPlanStage.upcoming => 'View plan',
        WatchPlanStage.past => 'See ratings',
        WatchPlanStage.cancelled => 'View plan',
        WatchPlanStage.expired => 'View plan',
      };
}

class WatchRequestUser {
  final String id;
  final String username;
  final String? firstName;
  final String? lastName;
  final Map<String, dynamic>? iconColor;
  final ProfileAvatar? avatar;

  const WatchRequestUser({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    this.iconColor,
    this.avatar,
  });

  factory WatchRequestUser.fromJson(Map<String, dynamic> json) {
    return WatchRequestUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      iconColor: json['iconColor'] as Map<String, dynamic>?,
      avatar: json['avatar'] == null
          ? null
          : ProfileAvatar.fromJson(json['avatar'] as Map<String, dynamic>),
    );
  }

  String get displayName {
    final first = firstName?.trim() ?? '';
    return first.isNotEmpty ? first : username;
  }
}

class WatchRequestMovieDetails {
  final int id;
  final String title;
  final String? posterPath;
  final int? runtimeMinutes;

  const WatchRequestMovieDetails({
    required this.id,
    required this.title,
    this.posterPath,
    this.runtimeMinutes,
  });

  factory WatchRequestMovieDetails.fromJson(Map<String, dynamic> json) {
    return WatchRequestMovieDetails(
      id: _intValue(json['id']) ?? 0,
      title: json['title'] as String? ?? 'Unknown Movie',
      posterPath: json['posterPath'] as String?,
      runtimeMinutes: _intValue(json['runtime']),
    );
  }
}

class WatchRequestParticipant {
  final WatchRequestUser? user;
  final String response;
  final DateTime? respondedAt;
  final DateTime? watchedAt;
  final double? rating;
  final String? reviewText;

  const WatchRequestParticipant({
    this.user,
    this.response = 'pending',
    this.respondedAt,
    this.watchedAt,
    this.rating,
    this.reviewText,
  });

  factory WatchRequestParticipant.fromJson(Map<String, dynamic> json) {
    final nestedUser = json['user'];
    final userJson = nestedUser is Map<String, dynamic>
        ? nestedUser
        : <String, dynamic>{
            'id': json['responderId'] ??
                json['userId'] ??
                json['memberId'] ??
                json['id'],
            'username': json['username'],
            'firstName': json['firstName'],
            'lastName': json['lastName'],
            'iconColor': json['iconColor'],
            'avatar': json['avatar'],
          };
    final userId = userJson['id']?.toString() ?? '';
    final status = json['status']?.toString();
    final response = json['response']?.toString();
    final participantResponse = _isParticipantStatus(status)
        ? status!
        : (_isParticipantStatus(response) ? response! : 'pending');

    return WatchRequestParticipant(
      user: userId.isNotEmpty ? WatchRequestUser.fromJson(userJson) : null,
      response: participantResponse,
      respondedAt: _dateTimeValue(json['respondedAt']),
      watchedAt: _dateTimeValue(json['watchedAt']),
      rating: _doubleValue(json['rating']),
      reviewText: json['reviewText'] as String?,
    );
  }

  bool get hasCompleted => watchedAt != null || rating != null;
}

class WatchScheduleProposal {
  final String id;
  final String proposerId;
  final DateTime? proposedFor;
  final String? message;
  final String? location;
  final String status;
  final String? createdAt;
  final String? updatedAt;
  final List<WatchScheduleProposalResponse> responses;

  const WatchScheduleProposal({
    required this.id,
    required this.proposerId,
    this.proposedFor,
    this.message,
    this.location,
    this.status = 'PENDING',
    this.createdAt,
    this.updatedAt,
    this.responses = const [],
  });

  factory WatchScheduleProposal.fromJson(Map<String, dynamic> json) {
    return WatchScheduleProposal(
      id: json['id']?.toString() ?? '',
      proposerId: (json['proposerId'] ?? json['userId'])?.toString() ?? '',
      proposedFor: _dateTimeValue(json['proposedFor']),
      message: json['message'] as String?,
      location: json['location'] as String?,
      status: json['status']?.toString() ?? 'PENDING',
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      responses: (json['responses'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WatchScheduleProposalResponse.fromJson)
          .toList(),
    );
  }

  String get normalizedStatus => status.toUpperCase();
  bool get isPending => normalizedStatus == 'PENDING';

  WatchScheduleProposalResponse? responseFor(String userId) =>
      responses.where((response) => response.userId == userId).firstOrNull;
}

class WatchScheduleProposalResponse {
  const WatchScheduleProposalResponse({
    required this.userId,
    required this.status,
  });

  final String userId;
  final String status;

  factory WatchScheduleProposalResponse.fromJson(Map<String, dynamic> json) =>
      WatchScheduleProposalResponse(
        userId: json['userId']?.toString() ?? '',
        status: json['status']?.toString() ?? 'PENDING',
      );

  bool get isAccepted => status.toUpperCase() == 'ACCEPTED';
}

class WatchConfirmation {
  final String id;
  final String userId;
  final bool watched;
  final int? rating;
  final bool? recommended;
  final String? reviewText;
  final String? createdAt;

  const WatchConfirmation({
    required this.id,
    required this.userId,
    required this.watched,
    this.rating,
    this.recommended,
    this.reviewText,
    this.createdAt,
  });

  factory WatchConfirmation.fromJson(Map<String, dynamic> json) {
    return WatchConfirmation(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      watched: _boolValue(json['watched']) ?? false,
      rating: _intValue(json['rating']),
      recommended: _boolValue(json['recommended']),
      reviewText: json['reviewText'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class WatchPlanCandidate {
  final String id;
  final int? movieId;
  final int? showId;
  final String mediaType;
  final String addedByUserId;
  final String? addedByUsername;
  final ProfileAvatar? addedByAvatar;
  final String? title;
  final String? posterPath;
  final String? releaseDate;
  final List<String> selectedByUserIds;

  const WatchPlanCandidate({
    required this.id,
    this.movieId,
    this.showId,
    required this.mediaType,
    required this.addedByUserId,
    this.addedByUsername,
    this.addedByAvatar,
    this.title,
    this.posterPath,
    this.releaseDate,
    this.selectedByUserIds = const [],
  });

  factory WatchPlanCandidate.fromJson(Map<String, dynamic> json) {
    final movie = json['movie'] as Map<String, dynamic>?;
    final show = json['show'] as Map<String, dynamic>?;
    final addedBy = json['addedBy'] as Map<String, dynamic>?;
    final choices = json['choices'] as List<dynamic>? ?? const [];
    return WatchPlanCandidate(
      id: json['id']?.toString() ?? '',
      movieId: _intValue(json['movieId'] ?? movie?['id']),
      showId: _intValue(json['showId'] ?? show?['id']),
      mediaType:
          json['mediaType']?.toString() ?? (movie != null ? 'movie' : 'show'),
      addedByUserId: json['addedByUserId']?.toString() ?? '',
      addedByUsername:
          (addedBy?['username'] ?? addedBy?['firstName'])?.toString(),
      addedByAvatar: addedBy?['avatar'] is Map<String, dynamic>
          ? ProfileAvatar.fromJson(addedBy!['avatar'] as Map<String, dynamic>)
          : null,
      title: (movie?['title'] ?? show?['title'])?.toString(),
      posterPath: (movie?['posterPath'] ?? show?['posterPath'])?.toString(),
      releaseDate: (movie?['releaseDate'] ?? show?['firstAirDate'])?.toString(),
      selectedByUserIds: choices
          .whereType<Map<String, dynamic>>()
          .map((choice) => choice['userId']?.toString())
          .whereType<String>()
          .toList(growable: false),
    );
  }

  bool selectedBy(String userId) => selectedByUserIds.contains(userId);
}

class WatchRequestState {
  final WatchRequest request;
  final bool needsWatchConfirmation;
  final bool hasCurrentUserLoggedWatch;

  const WatchRequestState({
    required this.request,
    required this.needsWatchConfirmation,
    required this.hasCurrentUserLoggedWatch,
  });

  factory WatchRequestState.fromJson(Map<String, dynamic> json) {
    final requestJson = Map<String, dynamic>.from(
      json['request'] as Map<String, dynamic>,
    );
    requestJson['needsWatchConfirmation'] = json['needsWatchConfirmation'];
    requestJson['hasCurrentUserLoggedWatch'] =
        json['hasCurrentUserLoggedWatch'];
    return WatchRequestState(
      request: WatchRequest.fromJson(requestJson),
      needsWatchConfirmation:
          _boolValue(json['needsWatchConfirmation']) ?? false,
      hasCurrentUserLoggedWatch:
          _boolValue(json['hasCurrentUserLoggedWatch']) ?? false,
    );
  }
}

class WatchRequest {
  final String id;
  final String requesterId;
  final String recipientId;
  final String? message;
  final String status;
  final String? response;
  final int? movieId;
  final int? showId;
  final String type;
  final String? createdAt;
  final String? updatedAt;
  final DateTime? proposedDate;
  final DateTime? scheduledFor;
  final String? location;
  final String scheduleStatus;
  final String? scheduledById;
  final String watchedStatus;
  final String? groupId;
  final String? groupName;
  final String? conversationId;
  final List<WatchScheduleProposal> scheduleProposals;
  final List<WatchConfirmation> watchConfirmations;
  final List<WatchPlanCandidate> candidates;
  final String? selectedCandidateId;
  final String? proposedCandidateId;
  final String? movieProposedById;
  final bool? needsWatchConfirmation;
  final bool? hasCurrentUserLoggedWatch;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? expiresAt;
  final DateTime? lastActivityAt;
  final List<WatchRequestParticipant> participants;
  final bool? hasCurrentUserAccepted;
  final bool? hasCurrentUserCompleted;
  final bool? canSchedule;
  final bool? canComplete;
  final bool? canCancel;
  final WatchRequestUser? requester;
  final WatchRequestUser? recipient;
  final WatchRequestUser? createdBy;
  final WatchRequestMovieDetails? movie;

  const WatchRequest({
    required this.id,
    required this.requesterId,
    required this.recipientId,
    this.message,
    required this.status,
    this.response,
    this.movieId,
    this.showId,
    required this.type,
    this.createdAt,
    this.updatedAt,
    this.proposedDate,
    this.scheduledFor,
    this.location,
    this.scheduleStatus = 'NONE',
    this.scheduledById,
    this.watchedStatus = 'NOT_DUE',
    this.groupId,
    this.groupName,
    this.conversationId,
    this.scheduleProposals = const [],
    this.watchConfirmations = const [],
    this.candidates = const [],
    this.selectedCandidateId,
    this.proposedCandidateId,
    this.movieProposedById,
    this.needsWatchConfirmation,
    this.hasCurrentUserLoggedWatch,
    this.acceptedAt,
    this.completedAt,
    this.cancelledAt,
    this.expiresAt,
    this.lastActivityAt,
    this.participants = const [],
    this.hasCurrentUserAccepted,
    this.hasCurrentUserCompleted,
    this.canSchedule,
    this.canComplete,
    this.canCancel,
    this.requester,
    this.recipient,
    this.createdBy,
    this.movie,
  });

  factory WatchRequest.fromJson(Map<String, dynamic> json) {
    final movie = json['movie'] as Map<String, dynamic>?;
    final show = json['show'] as Map<String, dynamic>?;
    final createdBy = json['createdBy'] as Map<String, dynamic>?;
    final participantsRaw = json['participants'] as List<dynamic>? ?? [];
    final proposalsRaw = json['scheduleProposals'] as List<dynamic>? ?? [];
    final confirmationsRaw = json['watchConfirmations'] as List<dynamic>? ?? [];
    final candidatesRaw = json['candidates'] as List<dynamic>? ?? [];
    final requester = json['requester'] as Map<String, dynamic>?;
    final recipient = json['recipient'] as Map<String, dynamic>?;
    final group = json['group'] as Map<String, dynamic>?;
    final candidates = candidatesRaw
        .whereType<Map<String, dynamic>>()
        .map(WatchPlanCandidate.fromJson)
        .toList();
    final selectedCandidateId = json['selectedCandidateId']?.toString();
    final hasUnresolvedMovieChoices =
        candidates.length > 1 && selectedCandidateId == null;

    return WatchRequest(
      id: json['id']?.toString() ?? '',
      requesterId:
          (json['requesterId'] ?? json['createdById'] ?? createdBy?['id'])
                  ?.toString() ??
              '',
      recipientId: json['recipientId']?.toString() ?? '',
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'open',
      response: json['response'] as String?,
      movieId: hasUnresolvedMovieChoices
          ? null
          : _intValue(json['movieId'] ?? movie?['id']),
      showId: _intValue(json['showId'] ?? show?['id']),
      type: json['type'] as String? ?? 'MOVIE_WATCH_REQUEST',
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      proposedDate: _dateTimeValue(json['proposedDate']),
      scheduledFor: _dateTimeValue(json['scheduledFor']),
      location: (json['location'] ?? json['locationLabel'])?.toString(),
      scheduleStatus: json['scheduleStatus']?.toString() ?? 'NONE',
      scheduledById: json['scheduledById']?.toString(),
      watchedStatus: json['watchedStatus']?.toString() ?? 'NOT_DUE',
      groupId: (json['groupId'] ?? group?['id'])?.toString(),
      groupName: (json['groupName'] ?? group?['name'])?.toString(),
      conversationId: json['conversationId']?.toString(),
      scheduleProposals: proposalsRaw
          .whereType<Map<String, dynamic>>()
          .map(WatchScheduleProposal.fromJson)
          .toList(),
      watchConfirmations: confirmationsRaw
          .whereType<Map<String, dynamic>>()
          .map(WatchConfirmation.fromJson)
          .toList(),
      candidates: candidates,
      selectedCandidateId: selectedCandidateId,
      proposedCandidateId: json['proposedCandidateId']?.toString(),
      movieProposedById: json['movieProposedById']?.toString(),
      needsWatchConfirmation: _boolValue(json['needsWatchConfirmation']),
      hasCurrentUserLoggedWatch: _boolValue(json['hasCurrentUserLoggedWatch']),
      acceptedAt: _dateTimeValue(json['acceptedAt']),
      completedAt: _dateTimeValue(json['completedAt']),
      cancelledAt: _dateTimeValue(json['cancelledAt']),
      expiresAt: _dateTimeValue(json['expiresAt']),
      lastActivityAt: _dateTimeValue(json['lastActivityAt']),
      participants: participantsRaw
          .whereType<Map<String, dynamic>>()
          .map(WatchRequestParticipant.fromJson)
          .toList(),
      hasCurrentUserAccepted: _boolValue(json['hasCurrentUserAccepted']),
      hasCurrentUserCompleted: _boolValue(json['hasCurrentUserCompleted']),
      canSchedule: _boolValue(json['canSchedule']),
      canComplete: _boolValue(json['canComplete']),
      canCancel: _boolValue(json['canCancel']),
      requester:
          requester != null ? WatchRequestUser.fromJson(requester) : null,
      recipient:
          recipient != null ? WatchRequestUser.fromJson(recipient) : null,
      createdBy:
          createdBy != null ? WatchRequestUser.fromJson(createdBy) : null,
      movie: movie != null && !hasUnresolvedMovieChoices
          ? WatchRequestMovieDetails.fromJson(movie)
          : null,
    );
  }

  /// Returns the other user (not the current user) in this request.
  WatchRequestUser? otherUser(String myUserId) {
    if (participants.isNotEmpty) {
      for (final participant in participants) {
        final user = participant.user;
        if (user != null && user.id != myUserId) return user;
      }
    }
    if (requesterId == myUserId) return recipient;
    return requester ?? createdBy;
  }

  WatchRequestParticipant? participantFor(String userId) {
    for (final participant in participants) {
      if (participant.user?.id == userId) return participant;
    }
    return null;
  }

  String get normalizedStatus => status.toLowerCase();
  String get normalizedType => type.toUpperCase();
  String get normalizedScheduleStatus => scheduleStatus.toUpperCase();
  String get normalizedWatchedStatus => watchedStatus.toUpperCase();

  bool get isWatchRequest =>
      normalizedType == 'MOVIE_WATCH_REQUEST' ||
      normalizedType == 'SHOW_WATCH_REQUEST';
  String get analyticsContentType =>
      normalizedType == 'SHOW_WATCH_REQUEST' ? 'show' : 'movie';
  int? get analyticsContentId =>
      analyticsContentType == 'show' ? showId : movieId;
  String get analyticsPlanType => groupId == null ? 'friend' : 'group';

  /// The locked-in title for user-facing reminders and calendar entries.
  /// Some API views omit the top-level movie for the plan creator while
  /// still returning the selected candidate, so do not rely on [movie] alone.
  String get watchPlanTitle {
    final movieTitle = movie?.title.trim();
    if (movieTitle?.isNotEmpty == true) return movieTitle!;
    if (selectedCandidateId != null) {
      for (final candidate in candidates) {
        if (candidate.id == selectedCandidateId) {
          final title = candidate.title?.trim();
          if (title?.isNotEmpty == true) return title!;
        }
      }
    }
    if (candidates.length == 1) {
      final title = candidates.single.title?.trim();
      if (title?.isNotEmpty == true) return title!;
    }
    return 'Watch together';
  }

  /// Total intended participants, including the creator. Direct requests are
  /// always one creator plus one friend. Group responses represent invitees.
  int get analyticsParticipantCount {
    if (groupId == null) return 2;
    final inviteeIds = participants
        .map((participant) => participant.user?.id)
        .whereType<String>()
        .where((id) => id.isNotEmpty && id != requesterId)
        .toSet();
    return 1 + inviteeIds.length;
  }

  bool get isPending =>
      normalizedStatus == 'pending' || normalizedStatus == 'open';
  bool get isAccepted => normalizedStatus == 'accepted';
  bool get isScheduled => normalizedStatus == 'scheduled';
  bool get isCompleted =>
      normalizedStatus == 'completed' || normalizedStatus == 'finalised';
  bool get isCancelled =>
      normalizedStatus == 'cancelled' || normalizedStatus == 'canceled';
  bool get isExpired => normalizedStatus == 'expired';
  bool get isDeclined => normalizedStatus == 'declined';
  bool get isTerminal => isCompleted || isCancelled || isExpired || isDeclined;
  bool get isAwaitingScheduleApproval =>
      normalizedScheduleStatus != 'AGREED' &&
      (isAccepted || proposedDate != null || latestPendingProposal != null);

  String get displayStatusLabel {
    if (normalizedWatchedStatus == 'WATCHED') return 'Watched';
    if (normalizedWatchedStatus == 'NOT_WATCHED') return 'Not watched';
    if (normalizedWatchedStatus == 'PARTIAL') return 'Confirming';
    if (isAwaitingScheduleApproval) {
      return isAccepted
          ? 'Accepted · scheduling in progress'
          : 'Scheduling in progress';
    }
    if (normalizedScheduleStatus == 'AGREED') return 'Scheduled';
    if (normalizedScheduleStatus == 'PROPOSED') return 'Proposed';
    if (isAccepted) return 'Accepted';
    if (isDeclined) return 'Declined';
    if (normalizedStatus == 'maybe') return 'Maybe';
    return 'Pending';
  }

  bool canScheduleFor(String userId) =>
      canSchedule ?? ((isAccepted || isScheduled) && !isTerminal);

  bool canCompleteFor(String userId) =>
      canComplete ??
      ((isAccepted || isScheduled) &&
          hasCurrentUserAccepted != false &&
          hasCurrentUserCompleted != true);

  bool canCancelFor(String userId) =>
      canCancel ?? (!isTerminal && requesterId == userId);

  WatchScheduleProposal? get latestPendingProposal {
    final pending = scheduleProposals.where((p) {
      if (!p.isPending) return false;
      final groupPlan = groupId != null || groupName?.trim().isNotEmpty == true;
      final matchesConfirmedSlot = groupPlan &&
          scheduledFor != null &&
          p.proposedFor != null &&
          scheduledFor!.isAtSameMomentAs(p.proposedFor!) &&
          (p.location ?? location ?? '').trim() == (location ?? '').trim();
      return !matchesConfirmedSlot;
    }).toList()
      ..sort((a, b) => _dateTimeValue(b.createdAt)
          .compareNullable(_dateTimeValue(a.createdAt)));
    return pending.isEmpty ? null : pending.first;
  }

  bool hasCurrentUserConfirmed(String userId) =>
      watchConfirmations.any((c) => c.userId == userId);

  bool get canProposeSchedule => isWatchRequest && (isAccepted || isScheduled);

  bool canRespondToProposal(String userId) {
    if (candidates.length > 1 && selectedCandidateId == null) return false;
    final proposal = latestPendingProposal;
    return proposal != null && proposal.proposerId != userId;
  }

  bool canConfirmWatchedFor(String userId) =>
      needsWatchConfirmation == true && !hasCurrentUserConfirmed(userId);

  /// Maps the persisted request and per-person response state to the single
  /// product state shown in Watch Plans. This deliberately does not mutate
  /// backend statuses: a pending invite, schedule proposal and due watch all
  /// need different next actions for different participants.
  WatchPlanStage planStageFor(String userId, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    if (isCancelled) return WatchPlanStage.cancelled;
    if (isExpired) return WatchPlanStage.expired;
    if (isCompleted || normalizedWatchedStatus == 'WATCHED') {
      return WatchPlanStage.past;
    }

    final isIncoming = requesterId != userId &&
        (recipientId == userId || participantFor(userId) != null);
    if (isAccepted &&
        selectedCandidateId == null &&
        proposedCandidateId != null) {
      return movieProposedById == userId
          ? WatchPlanStage.waitingForReplies
          : WatchPlanStage.needsReply;
    }
    final proposal = latestPendingProposal;
    if ((isPending && isIncoming) ||
        (proposal != null && proposal.proposerId != userId)) {
      return WatchPlanStage.needsReply;
    }
    if (isPending || proposal != null) return WatchPlanStage.waitingForReplies;

    if ((normalizedScheduleStatus == 'AGREED' || isScheduled) &&
        scheduledFor != null) {
      return scheduledFor!.isAfter(currentTime)
          ? WatchPlanStage.upcoming
          : WatchPlanStage.past;
    }
    return WatchPlanStage.planning;
  }
}

extension on DateTime? {
  int compareNullable(DateTime? other) {
    final left = this ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = other ?? DateTime.fromMillisecondsSinceEpoch(0);
    return left.compareTo(right);
  }
}

DateTime? _dateTimeValue(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

int? _intValue(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _doubleValue(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool? _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is String) return bool.tryParse(value);
  return null;
}

bool _isParticipantStatus(String? value) {
  switch (value?.toUpperCase()) {
    case 'PENDING':
    case 'ACCEPTED':
    case 'DECLINED':
    case 'MAYBE':
      return true;
    default:
      return false;
  }
}
