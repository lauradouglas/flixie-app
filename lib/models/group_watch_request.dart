import 'package:flixie_app/models/profile_avatar.dart';

/// Status of a watch request in a group or friend conversation.
enum WatchRequestStatus {
  open,
  accepted,
  scheduled,
  completed,
  expired,
  cancelled;

  /// Parse a raw API string to a [WatchRequestStatus], defaulting to [open].
  static WatchRequestStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'pending':
      case 'open':
        return WatchRequestStatus.open;
      case 'accepted':
        return WatchRequestStatus.accepted;
      case 'scheduled':
        return WatchRequestStatus.scheduled;
      case 'finalised':
      case 'completed':
        return WatchRequestStatus.completed;
      case 'expired':
        return WatchRequestStatus.expired;
      case 'cancelled':
      case 'canceled':
        return WatchRequestStatus.cancelled;
      default:
        return WatchRequestStatus.open;
    }
  }

  String get apiValue {
    switch (this) {
      case WatchRequestStatus.open:
        return 'open';
      case WatchRequestStatus.accepted:
        return 'accepted';
      case WatchRequestStatus.scheduled:
        return 'scheduled';
      case WatchRequestStatus.completed:
        return 'completed';
      case WatchRequestStatus.expired:
        return 'expired';
      case WatchRequestStatus.cancelled:
        return 'cancelled';
    }
  }

  /// A user-facing label for the status.
  String get statusLabel {
    switch (this) {
      case WatchRequestStatus.open:
        return 'Open';
      case WatchRequestStatus.accepted:
        return 'Accepted';
      case WatchRequestStatus.scheduled:
        return 'Scheduled';
      case WatchRequestStatus.completed:
        return 'Watched';
      case WatchRequestStatus.expired:
        return 'Expired';
      case WatchRequestStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Filter options for the Requests tab.
enum WatchRequestFilter {
  all,
  needsResponse,
  active,
  completed,
  byMe;

  String get apiValue {
    switch (this) {
      case WatchRequestFilter.all:
        return 'all';
      case WatchRequestFilter.needsResponse:
        return 'needs_response';
      case WatchRequestFilter.active:
        return 'active';
      case WatchRequestFilter.completed:
        return 'completed';
      case WatchRequestFilter.byMe:
        return 'by_me';
    }
  }

  String get label {
    switch (this) {
      case WatchRequestFilter.all:
        return 'All';
      case WatchRequestFilter.needsResponse:
        return 'Needs Response';
      case WatchRequestFilter.active:
        return 'Active';
      case WatchRequestFilter.completed:
        return 'Completed';
      case WatchRequestFilter.byMe:
        return 'By Me';
    }
  }

  String get emptyMessage {
    switch (this) {
      case WatchRequestFilter.all:
        return 'No Watch Plans yet.';
      case WatchRequestFilter.needsResponse:
        return 'No Watch Plans need your response';
      case WatchRequestFilter.active:
        return 'No active Watch Plans';
      case WatchRequestFilter.completed:
        return 'No completed watches yet';
      case WatchRequestFilter.byMe:
        return "You haven't created any Watch Plans yet";
    }
  }
}

/// A member's response decision.
enum WatchResponseDecision {
  accepted,
  declined,
  maybe;

  static WatchResponseDecision fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'accepted':
      case 'accept':
        return WatchResponseDecision.accepted;
      case 'declined':
      case 'decline':
        return WatchResponseDecision.declined;
      case 'maybe':
      default:
        return WatchResponseDecision.maybe;
    }
  }

  String get apiValue {
    switch (this) {
      case WatchResponseDecision.accepted:
        return 'ACCEPTED';
      case WatchResponseDecision.declined:
        return 'DECLINED';
      case WatchResponseDecision.maybe:
        return 'MAYBE';
    }
  }

  String get label {
    switch (this) {
      case WatchResponseDecision.accepted:
        return 'You accepted';
      case WatchResponseDecision.declined:
        return 'You declined';
      case WatchResponseDecision.maybe:
        return 'You said maybe';
    }
  }
}

class GroupRequestMessage {
  final String id;
  final String userId;
  final String message;
  final int upVotes;
  final int downVotes;
  final String? createdAt;
  final String? username;
  final ProfileAvatar? avatar;
  final List<String> profileBadges;

  const GroupRequestMessage({
    required this.id,
    required this.userId,
    required this.message,
    this.upVotes = 0,
    this.downVotes = 0,
    this.createdAt,
    this.username,
    this.avatar,
    this.profileBadges = const [],
  });

  factory GroupRequestMessage.fromJson(Map<String, dynamic> json) {
    return GroupRequestMessage(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      message: json['message'] as String? ?? '',
      upVotes: json['upVotes'] as int? ?? 0,
      downVotes: json['downVotes'] as int? ?? 0,
      createdAt: json['createdAt'] as String?,
      username: json['username'] as String?,
    );
  }
}

class GroupRequestMemberStatus {
  final String memberId;
  final String status;
  final String? response;
  final String? watchedAt;
  final int? rating;
  final String? reviewText;
  final String? username;
  final ProfileAvatar? avatar;
  final List<String> profileBadges;

  const GroupRequestMemberStatus({
    required this.memberId,
    required this.status,
    this.response,
    this.watchedAt,
    this.rating,
    this.reviewText,
    this.username,
    this.avatar,
    this.profileBadges = const [],
  });

  factory GroupRequestMemberStatus.fromJson(Map<String, dynamic> json) {
    final responder = json['responder'] as Map<String, dynamic>?;
    return GroupRequestMemberStatus(
      memberId: (json['responderId'] ?? json['memberId'])?.toString() ?? '',
      status: _normalizedResponseStatus(
        json['status'] ?? json['decision'] ?? json['response'],
      ),
      response: json['response']?.toString(),
      watchedAt: json['watchedAt']?.toString(),
      rating: _intValue(json['rating']),
      reviewText: json['reviewText']?.toString(),
      username: (responder?['username'] ?? json['username']) as String?,
      avatar: (responder?['avatar'] ?? json['avatar']) == null
          ? null
          : ProfileAvatar.fromJson(
              (responder?['avatar'] ?? json['avatar']) as Map<String, dynamic>,
            ),
      profileBadges: ((responder?['profileBadges'] ?? json['profileBadges'])
                  as List<dynamic>? ??
              const [])
          .map((badge) => badge is Map ? badge['badge'] : badge)
          .whereType<String>()
          .toList(),
    );
  }
}

class GroupWatchPlanCandidate {
  final String id;
  final String addedByUserId;
  final int? movieId;
  final int? showId;
  final String? title;
  final String? posterPath;
  final String? addedByUsername;
  final ProfileAvatar? addedByAvatar;
  final List<String> selectedByUserIds;

  const GroupWatchPlanCandidate({
    required this.id,
    required this.addedByUserId,
    this.movieId,
    this.showId,
    this.title,
    this.posterPath,
    this.addedByUsername,
    this.addedByAvatar,
    this.selectedByUserIds = const [],
  });

  factory GroupWatchPlanCandidate.fromJson(Map<String, dynamic> json) {
    final movie = json['movie'] as Map<String, dynamic>?;
    final show = json['show'] as Map<String, dynamic>?;
    final addedBy = json['addedBy'] as Map<String, dynamic>?;
    final choices = json['choices'] as List<dynamic>? ?? const [];
    return GroupWatchPlanCandidate(
      id: json['id']?.toString() ?? '',
      addedByUserId:
          json['addedByUserId']?.toString() ?? addedBy?['id']?.toString() ?? '',
      movieId: _intValue(json['movieId'] ?? movie?['id']),
      showId: _intValue(json['showId'] ?? show?['id']),
      title: (movie?['title'] ?? show?['title'])?.toString(),
      posterPath: (movie?['posterPath'] ?? show?['posterPath'])?.toString(),
      addedByUsername:
          (addedBy?['username'] ?? addedBy?['firstName'])?.toString(),
      addedByAvatar: addedBy?['avatar'] is Map<String, dynamic>
          ? ProfileAvatar.fromJson(addedBy!['avatar'] as Map<String, dynamic>)
          : null,
      selectedByUserIds: choices
          .whereType<Map<String, dynamic>>()
          .map((choice) => choice['userId']?.toString())
          .whereType<String>()
          .toList(),
    );
  }
}

class GroupWatchRequest {
  final String id;

  /// Postgres group-request ID when [id] is the mirrored conversation ID.
  final String? databaseRequestId;
  final String groupId;
  final String userId;
  final String? message;
  final String? mediaType;
  final int? mediaId;
  final String? createdAt;
  final String? updatedAt;
  final String? movieTitle;
  final String? moviePosterPath;
  final String? requesterUsername;
  final ProfileAvatar? requesterAvatar;
  final List<String> requesterProfileBadges;
  final List<GroupRequestMemberStatus> memberStatuses;
  final List<GroupRequestMessage> messages;
  final List<GroupWatchPlanCandidate> candidates;
  final String? selectedCandidateId;

  // Lifecycle fields
  final WatchRequestStatus status;
  final String? proposedDate;
  final String? scheduledFor;
  final String? location;
  final String? expiresAt;
  final String? completedAt;
  final String? cancelledAt;
  final int acceptedCount;
  final int declinedCount;
  final int maybeCount;
  final int responseCount;
  final String? lastActivityAt;
  final WatchResponseDecision? currentUserResponse;
  final bool? hasCurrentUserAccepted;
  final bool? hasCurrentUserCompleted;
  final bool? canSchedule;
  final bool? canComplete;
  final bool? canCancel;

  const GroupWatchRequest({
    required this.id,
    this.databaseRequestId,
    required this.groupId,
    required this.userId,
    this.message,
    this.mediaType,
    this.mediaId,
    this.createdAt,
    this.updatedAt,
    this.movieTitle,
    this.moviePosterPath,
    this.requesterUsername,
    this.requesterAvatar,
    this.requesterProfileBadges = const [],
    this.memberStatuses = const [],
    this.messages = const [],
    this.candidates = const [],
    this.selectedCandidateId,
    this.status = WatchRequestStatus.open,
    this.proposedDate,
    this.scheduledFor,
    this.location,
    this.expiresAt,
    this.completedAt,
    this.cancelledAt,
    this.acceptedCount = 0,
    this.declinedCount = 0,
    this.maybeCount = 0,
    this.responseCount = 0,
    this.lastActivityAt,
    this.currentUserResponse,
    this.hasCurrentUserAccepted,
    this.hasCurrentUserCompleted,
    this.canSchedule,
    this.canComplete,
    this.canCancel,
  });

  factory GroupWatchRequest.fromJson(Map<String, dynamic> json) {
    // API returns nested `responses` and `messages` arrays
    final statusesRaw = json['responses'] as List<dynamic>? ??
        json['memberStatuses'] as List<dynamic>? ??
        [];
    final messagesRaw = json['messages'] as List<dynamic>? ?? [];
    final candidatesRaw = json['candidates'] as List<dynamic>? ?? [];
    final candidates = candidatesRaw
        .whereType<Map<String, dynamic>>()
        .map(GroupWatchPlanCandidate.fromJson)
        .toList();
    final selectedCandidateId = json['selectedCandidateId']?.toString();
    final hasUnresolvedMovieChoices =
        candidates.length > 1 && selectedCandidateId == null;

    // Movie and requester are nested objects in the API response
    final movie = json['movie'] as Map<String, dynamic>?;
    final requester = json['requester'] as Map<String, dynamic>?;

    // Parse response counts from API or derive from memberStatuses
    final statusList = statusesRaw
        .map(
            (e) => GroupRequestMemberStatus.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawAccepted = json['acceptedCount'] as int? ??
        statusList.where((s) => s.status == 'ACCEPTED').length;
    final rawDeclined = json['declinedCount'] as int? ??
        statusList.where((s) => s.status == 'DECLINED').length;
    final rawMaybe = json['maybeCount'] as int? ??
        statusList.where((s) => s.status == 'MAYBE').length;
    final rawResponse = json['responseCount'] as int? ?? statusList.length;

    // Parse current user response - new API returns `userResponse: { decision: "accepted" }`
    final currentUserResponseRaw = json['currentUserResponse'] as String? ??
        (json['userResponse'] as Map<String, dynamic>?)?['decision'] as String?;
    final currentUserResponseDecision = currentUserResponseRaw != null
        ? WatchResponseDecision.fromString(currentUserResponseRaw)
        : null;

    return GroupWatchRequest(
      id: json['id']?.toString() ?? '',
      databaseRequestId: json['pgGroupRequestId']?.toString(),
      groupId: (json['conversationId'] ?? json['groupId'])?.toString() ?? '',
      userId: (json['createdById'] ?? json['requesterId'] ?? json['userId'])
              ?.toString() ??
          '',
      message: json['message'] as String?,
      mediaType: json['mediaType'] as String? ??
          (json['showId'] != null ? 'show' : 'movie'),
      mediaId: hasUnresolvedMovieChoices
          ? null
          : _intValue(json['movieId'] ?? json['showId'] ?? json['mediaId']),
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      movieTitle: hasUnresolvedMovieChoices
          ? null
          : movie?['title'] as String? ?? json['movieTitle'] as String?,
      moviePosterPath: hasUnresolvedMovieChoices
          ? null
          : movie?['posterPath'] as String? ??
              json['moviePosterUrl'] as String? ??
              json['moviePosterPath'] as String?,
      requesterUsername: requester?['username'] as String? ??
          json['requesterUsername'] as String?,
      requesterAvatar: requester?['avatar'] == null
          ? null
          : ProfileAvatar.fromJson(
              requester!['avatar'] as Map<String, dynamic>,
            ),
      requesterProfileBadges:
          (requester?['profileBadges'] as List<dynamic>? ?? const [])
              .map((badge) => badge is Map ? badge['badge'] : badge)
              .whereType<String>()
              .toList(),
      memberStatuses: statusList,
      messages: messagesRaw
          .map((e) => GroupRequestMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      candidates: candidates,
      selectedCandidateId: selectedCandidateId,
      status: WatchRequestStatus.fromString(json['status'] as String?),
      proposedDate: json['proposedDate'] as String?,
      scheduledFor: json['scheduledFor'] as String?,
      location: (json['location'] ?? json['locationLabel']) as String?,
      expiresAt: json['expiresAt'] as String?,
      completedAt: json['completedAt'] as String?,
      cancelledAt: json['cancelledAt'] as String?,
      acceptedCount: rawAccepted,
      declinedCount: rawDeclined,
      maybeCount: rawMaybe,
      responseCount: rawResponse,
      lastActivityAt: json['lastActivityAt'] as String?,
      currentUserResponse: currentUserResponseDecision,
      hasCurrentUserAccepted: _boolValue(json['hasCurrentUserAccepted']),
      hasCurrentUserCompleted: _boolValue(json['hasCurrentUserCompleted']),
      canSchedule: _boolValue(json['canSchedule']),
      canComplete: _boolValue(json['canComplete']),
      canCancel: _boolValue(json['canCancel']),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper getters
  // ---------------------------------------------------------------------------

  /// True when the request is open or scheduled (still relevant for planning).
  bool get isActive =>
      status == WatchRequestStatus.open ||
      status == WatchRequestStatus.accepted ||
      status == WatchRequestStatus.scheduled;

  String get analyticsContentType =>
      mediaType?.toLowerCase() == 'show' ? 'show' : 'movie';

  /// Total intended participants, including the creator. Response rows are
  /// created for each invited group member, including pending responses.
  int get analyticsParticipantCount {
    final inviteeIds = memberStatuses
        .map((status) => status.memberId)
        .where((id) => id.isNotEmpty && id != userId)
        .toSet();
    if (inviteeIds.isNotEmpty) return 1 + inviteeIds.length;
    final knownInvitees =
        responseCount > acceptedCount ? responseCount : acceptedCount;
    return 1 + knownInvitees;
  }

  /// True when the request is completed, expired, or cancelled.
  bool get isArchived =>
      status == WatchRequestStatus.completed ||
      status == WatchRequestStatus.expired ||
      status == WatchRequestStatus.cancelled;

  /// True when the request has an expiry date that has already passed.
  bool get hasExpired {
    if (status == WatchRequestStatus.expired) return true;
    if (expiresAt == null) return false;
    final expiry = DateTime.tryParse(expiresAt!);
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  /// True when members can still respond (request is active and not expired).
  bool get canRespond => isActive && !hasExpired;

  /// A group request is mirrored between Postgres and the conversation store.
  /// Deep links may contain either identifier depending on where they began.
  bool matchesId(String requestId) =>
      id == requestId || databaseRequestId == requestId;

  bool canScheduleFor(String userId) =>
      canSchedule ??
      ((status == WatchRequestStatus.accepted ||
              status == WatchRequestStatus.scheduled) &&
          !hasExpired);

  bool canCompleteFor(String userId) =>
      canComplete ??
      ((status == WatchRequestStatus.accepted ||
              status == WatchRequestStatus.scheduled) &&
          hasCurrentUserCompleted != true &&
          _userAccepted(userId));

  bool canCancelFor(String userId) =>
      canCancel ?? (isActive && this.userId == userId);

  /// A user-facing label for the current status.
  String get statusLabel => status.statusLabel;

  bool _userAccepted(String userId) {
    if (hasCurrentUserAccepted == true) return true;
    return currentUserResponse == WatchResponseDecision.accepted ||
        memberStatuses.any(
          (s) => s.memberId == userId && s.status == 'ACCEPTED',
        );
  }
}

String _normalizedResponseStatus(dynamic value) {
  final raw = value?.toString().trim().toUpperCase() ?? '';
  switch (raw) {
    case 'ACCEPT':
    case 'ACCEPTED':
      return 'ACCEPTED';
    case 'DECLINE':
    case 'DECLINED':
      return 'DECLINED';
    case 'MAYBE':
      return 'MAYBE';
    case 'PENDING':
    case 'OPEN':
      return 'PENDING';
    default:
      return raw;
  }
}

bool? _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is String) return bool.tryParse(value);
  return null;
}

int? _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
