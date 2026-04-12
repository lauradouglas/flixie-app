import '../models/activity_list_item.dart';
import '../models/group.dart';
import '../models/group_member.dart';
import '../models/group_watch_request.dart';
import '../utils/app_logger.dart';
import 'api_client.dart';

export '../models/group_watch_request.dart'
    show WatchRequestFilter, WatchRequestStatus, WatchResponseDecision;

class GroupService {
  static Future<Group> createGroup(Map<String, dynamic> body) async {
    final data = await ApiClient.post('/groups', body: body);
    return Group.fromJson(data as Map<String, dynamic>);
  }

  static Future<Group> getGroup(String groupId) async {
    final data = await ApiClient.get('/groups/$groupId');
    return Group.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<Group>> getUserGroups(String userId) async {
    final data = await ApiClient.get('/groups/user/$userId');
    return (data as List<dynamic>)
        .map((e) => Group.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Group> updateGroup(
      String groupId, Map<String, dynamic> body) async {
    final data = await ApiClient.put('/groups/$groupId', body: body);
    return Group.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteGroup(String groupId) async {
    await ApiClient.delete('/groups/$groupId');
  }

  static Future<void> addMember(String groupId, String userId) async {
    await ApiClient.post(
      '/groups/$groupId/members',
      body: {'userId': userId},
    );
  }

  static Future<void> removeMember(String groupId, String userId) async {
    await ApiClient.delete(
      '/groups/$groupId/members',
      body: {'userId': userId},
    );
  }

  static Future<void> sendGroupMessage(
      String groupId, Map<String, dynamic> body) async {
    await ApiClient.post('/groups/$groupId/messages', body: body);
  }

  static Future<List<dynamic>> getGroupMessages(String groupId) async {
    final data = await ApiClient.get('/groups/$groupId/messages');
    return data as List<dynamic>;
  }

  static Future<List<GroupMember>> getGroupMembers(String groupId) async {
    final data = await ApiClient.get('/groups/$groupId/members');
    logger.d('[getGroupMembers] raw response: $data');
    return (data as List<dynamic>)
        .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> addMembersToGroup(
      String groupId, List<Map<String, dynamic>> members,
      {String? inviterId}) async {
    await ApiClient.post(
      '/groups/$groupId/members',
      body: inviterId != null
          ? members.map((m) => {...m, 'inviterId': inviterId}).toList()
          : members,
    );
  }

  static Future<void> removeMembersFromGroup(
      String groupId, List<String> memberIds) async {
    await ApiClient.delete(
      '/groups/$groupId/members',
      body: memberIds,
    );
  }

  static Future<void> updateRoleOfMemberInGroup(
      String groupId, String memberId, String roleId) async {
    await ApiClient.put(
      '/groups/$groupId/members/$memberId/role',
      body: {'roleId': roleId},
    );
  }

  static Future<void> updateMemberInviteStatus(
      String groupId, String memberId, String inviteStatus) async {
    await ApiClient.put(
      '/groups/$groupId/members/$memberId/inviteStatus',
      body: {'inviteStatus': inviteStatus},
    );
  }

  /// Create a watch request scoped to a known Firestore [conversationId].
  ///
  /// Returns the newly created [GroupWatchRequest].
  static Future<GroupWatchRequest> createConversationWatchRequest(
    String conversationId, {
    required String senderId,
    int? movieId,
    int? showId,
    String? movieTitle,
    String? moviePosterUrl,
    String? message,
    String? proposedDate,
  }) async {
    final data = await ApiClient.post(
      '/conversations/$conversationId/watch-requests',
      body: {
        'senderId': senderId,
        if (movieId != null) 'movieId': movieId,
        if (showId != null) 'showId': showId,
        if (movieTitle != null) 'movieTitle': movieTitle,
        if (moviePosterUrl != null) 'moviePosterUrl': moviePosterUrl,
        if (message != null && message.isNotEmpty) 'message': message,
        if (proposedDate != null) 'proposedDate': proposedDate,
      },
    );
    return GroupWatchRequest.fromJson(data as Map<String, dynamic>);
  }

  /// Legacy fallback: POST /groups/:groupId/send-request
  ///
  /// Use [createConversationWatchRequest] when a [conversationId] is available.
  /// Returns the raw response map, which may contain [conversationId] and
  /// [watchRequest] fields from the updated backend.
  static Future<Map<String, dynamic>?> sendWatchRequest(
    String groupId,
    String userId,
    String message,
    String mediaType,
    int mediaId, {
    String? proposedDate,
  }) async {
    final data = await ApiClient.post(
      '/groups/$groupId/send-request',
      body: {
        'userId': userId,
        'message': message,
        'mediaType': mediaType,
        'mediaId': mediaId,
        if (proposedDate != null) 'proposedDate': proposedDate,
      },
    );
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  /// Legacy: update a member's response on a watch request.
  ///
  /// Prefer [respondToWatchRequest] when a [conversationId] is available.
  static Future<void> updateWatchRequestForMember(
    String requestId,
    String memberId,
    String response,
    String status,
  ) async {
    await ApiClient.put(
      '/groups/request/$requestId/response',
      body: {'memberId': memberId, 'response': response, 'status': status},
    );
  }

  static Future<GroupRequestMessage> addMessageToRequest(
    String requestId,
    String userId,
    String message,
  ) async {
    final data = await ApiClient.post(
      '/groups/request/$requestId/message',
      body: {'userId': userId, 'message': message},
    );
    return GroupRequestMessage.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> sendFriendRequestsToGroupMembers(
    String groupId,
    String userId,
    String message,
  ) async {
    await ApiClient.post(
      '/groups/$groupId/send-friend-requests',
      body: {'userId': userId, 'message': message},
    );
  }

  static Future<void> updateGroupVisibility(
      String groupId, String visibility) async {
    await ApiClient.put(
      '/groups/$groupId/visibility',
      body: {'visibility': visibility},
    );
  }

  static Future<void> updateGroupRequestMessageVotes(
    String messageId,
    bool upVote,
    bool downVote,
  ) async {
    await ApiClient.put(
      '/groups/request/message/$messageId/votes',
      body: {'upVote': upVote, 'downVote': downVote},
    );
  }

  static Future<List<GroupWatchRequest>> getGroupWatchRequests(
      String groupId) async {
    final data = await ApiClient.get('/groups/$groupId/requests');
    return (data as List<dynamic>)
        .map((e) => GroupWatchRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch watch requests for a conversation with an optional [filter] and
  /// [userId].
  static Future<List<GroupWatchRequest>> getConversationWatchRequests(
    String conversationId, {
    WatchRequestFilter filter = WatchRequestFilter.active,
    String? userId,
  }) async {
    final params = <String, String>{'filter': filter.apiValue};
    if (userId != null && userId.isNotEmpty) params['userId'] = userId;
    final data = await ApiClient.get(
      '/conversations/$conversationId/watch-requests',
      queryParams: params,
    );
    return (data as List<dynamic>)
        .map((e) => GroupWatchRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /conversations/:conversationId/watch-requests/:requestId/responses
  ///
  /// The new endpoint expects lowercase decision values
  /// ("accepted"|"declined"|"maybe"), so [decision.apiValue] is lowercased
  /// here. The legacy [updateWatchRequestForMember] endpoint uses uppercase.
  static Future<void> respondToWatchRequest(
    String conversationId,
    String requestId,
    String userId,
    WatchResponseDecision decision, {
    String? message,
  }) async {
    await ApiClient.post(
      '/conversations/$conversationId/watch-requests/$requestId/responses',
      body: {
        'userId': userId,
        'decision': decision.apiValue.toLowerCase(),
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
  }

  /// PATCH /conversations/:conversationId/watch-requests/:requestId/complete
  static Future<void> completeWatchRequest(
    String conversationId,
    String requestId,
    String userId,
  ) async {
    await ApiClient.patch(
      '/conversations/$conversationId/watch-requests/$requestId/complete',
      body: {'userId': userId},
    );
  }

  /// PATCH /conversations/:conversationId/watch-requests/:requestId/cancel
  static Future<void> cancelWatchRequest(
    String conversationId,
    String requestId,
    String userId,
  ) async {
    await ApiClient.patch(
      '/conversations/$conversationId/watch-requests/$requestId/cancel',
      body: {'userId': userId},
    );
  }

  /// PATCH /conversations/:conversationId/watch-requests/:requestId/schedule
  static Future<void> scheduleWatchRequest(
    String conversationId,
    String requestId, {
    required String actingUserId,
    required String scheduledFor,
  }) async {
    await ApiClient.patch(
      '/conversations/$conversationId/watch-requests/$requestId/schedule',
      body: {'actingUserId': actingUserId, 'scheduledFor': scheduledFor},
    );
  }

  static Future<void> deleteWatchRequest(
      String groupId, String requestId) async {
    await ApiClient.delete('/groups/$groupId/requests/$requestId');
  }

  static Future<List<ActivityListItem>> getGroupActivity(String groupId) async {
    final data = await ApiClient.get('/groups/$groupId/activity');
    return (data as List<dynamic>)
        .map((e) => ActivityListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
