/// Status of a watch request in a group or friend conversation.
enum WatchRequestStatus {
  open,
  scheduled,
  completed,
  expired,
  cancelled;

  /// Parse a raw API string to a [WatchRequestStatus], defaulting to [open].
  static WatchRequestStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'scheduled':
        return WatchRequestStatus.scheduled;
      case 'completed':
        return WatchRequestStatus.completed;
      case 'expired':
        return WatchRequestStatus.expired;
      case 'cancelled':
      case 'canceled':
        return WatchRequestStatus.cancelled;
      case 'open':
      default:
        return WatchRequestStatus.open;
    }
  }

  String get apiValue {
    switch (this) {
      case WatchRequestStatus.open:
        return 'open';
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
        return 'No watch requests yet.';
      case WatchRequestFilter.needsResponse:
        return 'No requests need your response';
      case WatchRequestFilter.active:
        return 'No active watch requests';
      case WatchRequestFilter.completed:
        return 'No completed watches yet';
      case WatchRequestFilter.byMe:
        return "You haven't created any requests yet";
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

  const GroupRequestMessage({
    required this.id,
    required this.userId,
    required this.message,
    this.upVotes = 0,
    this.downVotes = 0,
    this.createdAt,
    this.username,
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
  final String? username;

  const GroupRequestMemberStatus({
    required this.memberId,
    required this.status,
    this.response,
    this.username,
  });

  factory GroupRequestMemberStatus.fromJson(Map<String, dynamic> json) {
    return GroupRequestMemberStatus(
      memberId: (json['responderId'] ?? json['memberId'])?.toString() ?? '',
      status: json['status'] as String? ?? '',
      response: json['response'] as String?,
      username: json['username'] as String?,
    );
  }
}

class GroupWatchRequest {
  final String id;
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
  final List<GroupRequestMemberStatus> memberStatuses;
  final List<GroupRequestMessage> messages;

  // Lifecycle fields
  final WatchRequestStatus status;
  final String? proposedDate;
  final String? scheduledFor;
  final String? expiresAt;
  final String? completedAt;
  final String? cancelledAt;
  final int acceptedCount;
  final int declinedCount;
  final int maybeCount;
  final int responseCount;
  final String? lastActivityAt;
  final WatchResponseDecision? currentUserResponse;


  const GroupWatchRequest({
    required this.id,
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
    this.memberStatuses = const [],
    this.messages = const [],
    this.status = WatchRequestStatus.open,
    this.proposedDate,
    this.scheduledFor,
    this.expiresAt,
    this.completedAt,
    this.cancelledAt,
    this.acceptedCount = 0,
    this.declinedCount = 0,
    this.maybeCount = 0,
    this.responseCount = 0,
    this.lastActivityAt,
    this.currentUserResponse,
  });

  factory GroupWatchRequest.fromJson(Map<String, dynamic> json) {
    // API returns nested `responses` and `messages` arrays
    final statusesRaw = json['responses'] as List<dynamic>? ??
        json['memberStatuses'] as List<dynamic>? ??
        [];
    final messagesRaw = json['messages'] as List<dynamic>? ?? [];

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

    // Parse current user response — new API returns `userResponse: { decision: "accepted" }`
    final currentUserResponseRaw = json['currentUserResponse'] as String? ??
        (json['userResponse'] as Map<String, dynamic>?)?['decision'] as String?;
    final currentUserResponseDecision = currentUserResponseRaw != null
        ? WatchResponseDecision.fromString(currentUserResponseRaw)
        : null;

    return GroupWatchRequest(
      id: json['id']?.toString() ?? '',
      groupId: (json['conversationId'] ?? json['groupId'])?.toString() ?? '',
      userId: (json['createdById'] ?? json['requesterId'] ?? json['userId'])
              ?.toString() ??
          '',
      message: json['message'] as String?,
      mediaType: json['mediaType'] as String?,
      mediaId: (json['movieId'] ?? json['mediaId']) as int?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      movieTitle: movie?['title'] as String? ?? json['movieTitle'] as String?,
      moviePosterPath: movie?['posterPath'] as String? ??
          json['moviePosterUrl'] as String? ??
          json['moviePosterPath'] as String?,
      requesterUsername: requester?['username'] as String? ??
          json['requesterUsername'] as String?,
      memberStatuses: statusList,
      messages: messagesRaw
          .map((e) => GroupRequestMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: WatchRequestStatus.fromString(json['status'] as String?),
      proposedDate: json['proposedDate'] as String?,
      scheduledFor: json['scheduledFor'] as String?,
      expiresAt: json['expiresAt'] as String?,
      completedAt: json['completedAt'] as String?,
      cancelledAt: json['cancelledAt'] as String?,
      acceptedCount: rawAccepted,
      declinedCount: rawDeclined,
      maybeCount: rawMaybe,
      responseCount: rawResponse,
      lastActivityAt: json['lastActivityAt'] as String?,
      currentUserResponse: currentUserResponseDecision,
    );
  }

  // ---------------------------------------------------------------------------
  // Helper getters
  // ---------------------------------------------------------------------------

  /// True when the request is open or scheduled (still relevant for planning).
  bool get isActive =>
      status == WatchRequestStatus.open ||
      status == WatchRequestStatus.scheduled;

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

  /// A user-facing label for the current status.
  String get statusLabel => status.statusLabel;
}
