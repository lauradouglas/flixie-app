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
      moviePosterPath:
          movie?['posterPath'] as String? ?? json['moviePosterPath'] as String?,
      requesterUsername: requester?['username'] as String? ??
          json['requesterUsername'] as String?,
      memberStatuses: statusesRaw
          .map((e) =>
              GroupRequestMemberStatus.fromJson(e as Map<String, dynamic>))
          .toList(),
      messages: messagesRaw
          .map((e) => GroupRequestMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
