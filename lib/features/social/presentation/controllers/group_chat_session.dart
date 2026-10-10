import 'package:flutter/foundation.dart';
import 'package:flixie_app/models/conversation.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import '../../data/group_chat_service.dart';

/// One account/group owns one initialization and one stable message stream.
class GroupChatSession extends ChangeNotifier {
  GroupChatSession({this.service = const GroupChatService()});
  final GroupChatService service;
  String? userId;
  String? groupId;
  String? conversationId;
  Stream<List<ChatMessage>>? messages;
  Map<String, String> usernames = {};
  Map<String, GroupMember> members = {};
  List<GroupWatchRequest> requests = [];
  bool loading = true;
  String? error;
  int _generation = 0;
  bool _disposed = false;
  int get generation => _generation;
  bool owns(int generation) => !_disposed && generation == _generation;

  void bind(String group, String? user) {
    if (groupId == group && userId == user) return;
    groupId = group;
    userId = user;
    _start();
  }

  void retry() {
    if (!loading) _start();
  }

  void _start() {
    final generation = ++_generation;
    conversationId = null;
    messages = null;
    usernames = {};
    members = {};
    requests = [];
    error = null;
    loading = true;
    notifyListeners();
    final user = userId;
    final group = groupId;
    if (user != null && group != null) _load(group, user, generation);
  }

  Future<void> _load(String groupId, String userId, int generation) async {
    try {
      final values = await Future.wait([
        service.group(groupId),
        service.members(groupId),
      ]);
      if (!owns(generation)) return;
      final group = values[0] as Group;
      final groupMembers = values[1] as List<GroupMember>;
      final ids = groupMembers.map((m) => m.memberId).toList();
      if (!ids.contains(userId)) ids.add(userId);
      final conversation =
          await service.conversation(userId, groupId, group.name, ids);
      if (!owns(generation)) return;
      final detail = await Future.wait([
        service.usernames(conversation.id),
        service.requests(conversation.id, userId),
      ]);
      if (!owns(generation)) return;
      conversationId = conversation.id;
      usernames = detail[0] as Map<String, String>;
      requests = detail[1] as List<GroupWatchRequest>;
      members = {for (final member in groupMembers) member.memberId: member};
      messages = service.messages(conversation.id);
      loading = false;
      notifyListeners();
    } catch (_) {
      if (!owns(generation)) return;
      loading = false;
      error = 'Could not load chat';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
