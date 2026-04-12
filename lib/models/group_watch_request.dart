enum WatchRequestFilter {
  all,
  open,
  closed;

  String get apiValue => name;
}

enum WatchRequestStatus {
  open,
  closed,
  cancelled;

  String get apiValue => name.toUpperCase();
}

enum WatchResponseDecision {
  accepted,
  declined,
  maybe;

  String get apiValue => name;

  static WatchResponseDecision fromString(String raw) {
    final lower = raw.toLowerCase();
    return values.firstWhere((e) => e.name == lower,
        orElse: () => accepted);
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
  final int acceptedCount;
  final int declinedCount;
  final int maybeCount;
  final int responseCount;
  final WatchResponseDecision? currentUserResponse;

  bool get canRespond => true;

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
    this.acceptedCount = 0,
    this.declinedCount = 0,
    this.maybeCount = 0,
    this.responseCount = 0,
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
      groupId: json['groupId']?.toString() ?? '',
      userId: (json['requesterId'] ?? json['userId'])?.toString() ?? '',
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
      acceptedCount: rawAccepted,
      declinedCount: rawDeclined,
      maybeCount: rawMaybe,
      responseCount: rawResponse,
      currentUserResponse: currentUserResponseDecision,
    );
  }
}
