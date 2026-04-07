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

  static Future<void> sendWatchRequest(
    String groupId,
    String userId,
    String message,
    String mediaType,
    int mediaId,
  ) async {
    await ApiClient.post(
      '/groups/$groupId/send-request',
      body: {
        'userId': userId,
        'message': message,
        'mediaType': mediaType,
        'mediaId': mediaId,
      },
    );
  }

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

  /// Fetch watch requests for a conversation (group or direct) with an
  /// optional [filter].  Falls back to the legacy group endpoint when
  /// [conversationId] is null.
  static Future<List<GroupWatchRequest>> getConversationWatchRequests(
    String conversationId, {
    WatchRequestFilter filter = WatchRequestFilter.active,
  }) async {
    final data = await ApiClient.get(
      '/conversations/$conversationId/watch-requests',
      queryParams: {'filter': filter.apiValue},
    );
    return (data as List<dynamic>)
        .map((e) => GroupWatchRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /watch-requests/:id/respond
  static Future<void> respondToWatchRequest(
    String requestId,
    WatchResponseDecision decision,
  ) async {
    await ApiClient.post(
      '/watch-requests/$requestId/respond',
      body: {'decision': decision.apiValue},
    );
  }

  /// POST /watch-requests/:id/complete
  static Future<void> completeWatchRequest(String requestId) async {
    await ApiClient.post('/watch-requests/$requestId/complete', body: {});
  }

  /// POST /watch-requests/:id/cancel
  static Future<void> cancelWatchRequest(String requestId) async {
    await ApiClient.post('/watch-requests/$requestId/cancel', body: {});
  }

  /// POST /watch-requests/:id/schedule
  static Future<void> scheduleWatchRequest(
    String requestId, {
    required String scheduledFor,
  }) async {
    await ApiClient.post(
      '/watch-requests/$requestId/schedule',
      body: {'scheduledFor': scheduledFor},
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
