import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/chat_service.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import '../models/chat_share_media.dart';

/// A single sharing flow belongs to the account that opened it.
class MediaShareSession extends ChangeNotifier {
  MediaShareSession(this._auth) : userId = _auth.dbUser?.id {
    _auth.addListener(_accountChanged);
  }
  final AuthProvider _auth;
  final String? userId;
  bool _invalid = false;
  bool _disposed = false;
  bool get isCurrent =>
      !_disposed && !_invalid && userId != null && _auth.dbUser?.id == userId;

  void _accountChanged() {
    if (!_invalid && _auth.dbUser?.id != userId) {
      _invalid = true;
      notifyListeners();
    }
  }

  void _check() {
    if (!isCurrent) throw StateError('Sharing account changed');
  }

  Future<List<Group>> loadGroups() async {
    _check();
    var groups = _auth.cachedGroups;
    if (groups == null) {
      groups = await GroupService.getUserGroups(userId!);
      _check();
      _auth.updateCachedGroups(groups);
    }
    return groups.where((g) => g.id?.isNotEmpty == true).toList();
  }

  Future<List<Friendship>> loadFriends() async {
    _check();
    var friends = _auth.cachedFriends;
    if (friends == null) {
      friends = await FriendService.getFriends(userId!);
      _check();
      _auth.updateCachedFriends(friends);
    }
    return friends.friendships
        .where((f) => f.friendUser?.id.isNotEmpty == true)
        .toList();
  }

  Future<void> shareGroup(
      {required ChatShareMedia movie,
      required Group group,
      required String message}) async {
    _check();
    final groupId = group.id;
    if (groupId == null || groupId.isEmpty) throw StateError('Missing group');
    final members = await GroupService.getGroupMembers(groupId);
    _check();
    final memberIds = members
        .where((m) => m.isAccepted)
        .map((m) => m.memberId)
        .toSet()
      ..add(userId!);
    final conversation = await ChatService.getOrCreateGroupConversation(
        creatorId: userId!,
        pgGroupId: groupId,
        name: group.name,
        memberIds: memberIds.toList());
    _check();
    await ChatService.sendMessage(
        conversationId: conversation.id,
        senderId: userId!,
        text: buildMediaSharePayload(
            movie: movie,
            message: message.isEmpty ? 'Has anyone ever seen this?' : message));
  }

  Future<void> shareDirect(
      {required ChatShareMedia movie,
      required Friendship friend,
      required String message}) async {
    _check();
    final recipient = friend.friendUser;
    if (recipient == null || recipient.id.isEmpty) {
      throw StateError('Missing friend');
    }
    final conversation = await ChatService.getOrCreateDirectConversation(
        userId: userId!, otherUserId: recipient.id);
    _check();
    await ChatService.sendMessage(
        conversationId: conversation.id,
        senderId: userId!,
        text: buildMediaSharePayload(
            movie: movie,
            message: message.isEmpty ? 'You should watch this.' : message));
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_accountChanged);
    super.dispose();
  }
}
