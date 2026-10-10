import 'package:flixie_app/models/conversation.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'chat_service.dart';
import 'group_service.dart';

/// Data boundary for one group's chat session. It owns no account cache.
class GroupChatService {
  const GroupChatService();

  Future<Group> group(String id) => GroupService.getGroup(id);
  Future<List<GroupMember>> members(String id) =>
      GroupService.getGroupMembers(id);
  Future<Conversation> conversation(
          String userId, String groupId, String name, List<String> members) =>
      ChatService.getOrCreateGroupConversation(
          creatorId: userId,
          pgGroupId: groupId,
          name: name,
          memberIds: members);
  Future<Map<String, String>> usernames(String id) =>
      ChatService.fetchMemberUsernames(id);
  Future<List<GroupWatchRequest>> requests(String id, String userId) =>
      GroupService.getConversationWatchRequests(id,
          filter: WatchRequestFilter.all, userId: userId);
  Stream<List<ChatMessage>> messages(String id) =>
      ChatService.messagesStream(id);
}
