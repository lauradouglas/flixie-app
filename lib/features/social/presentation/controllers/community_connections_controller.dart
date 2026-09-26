import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/models/friendship.dart';
import 'friend_actions_controller.dart';

enum CommunityConnection { unknown, available, outgoing, incoming, friends }

/// One relationship snapshot per feed, shared by every post from an author.
class CommunityConnectionsController extends ChangeNotifier {
  CommunityConnectionsController(
      {required this.userId,
      this.actions = const FriendActionsController(),
      this.onSnapshot});
  final String userId;
  final FriendActionsController actions;
  final ValueChanged<FriendsData>? onSnapshot;
  FriendsData? _data;
  final Map<String, CommunityConnection> _confirmed = {};
  final Set<String> _busy = {};
  bool _disposed = false;
  int _revision = 0;
  bool loading = false;
  bool failed = false;

  String? _otherId(Friendship item) => item.friendUser?.id ?? item.friendId;
  CommunityConnection stateFor(String id) {
    if (_confirmed.containsKey(id)) return _confirmed[id]!;
    final data = _data;
    if (data == null) return CommunityConnection.unknown;
    if (data.friendships.any((f) => _otherId(f) == id)) {
      return CommunityConnection.friends;
    }
    if (data.pendingFriends.any((f) => _otherId(f) == id)) {
      return CommunityConnection.incoming;
    }
    if (data.requestedFriends.any((f) => _otherId(f) == id)) {
      return CommunityConnection.outgoing;
    }
    return CommunityConnection.available;
  }

  bool busyFor(String id) => _busy.contains(id);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    final revision = ++_revision;
    loading = true;
    failed = false;
    _notify();
    try {
      final data = await actions.getFriends(userId);
      if (_disposed || revision != _revision) return;
      _data = data;
      _confirmed.clear();
      onSnapshot?.call(data);
    } catch (_) {
      if (!_disposed && revision == _revision) failed = true;
    } finally {
      if (!_disposed && revision == _revision) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> connect(FriendshipUser author) async {
    if (_disposed ||
        author.id == userId ||
        author.id.isEmpty ||
        SafetyService.isBlocked(author.id) ||
        _busy.contains(author.id)) {
      return;
    }
    final state = stateFor(author.id);
    if (state != CommunityConnection.available &&
        state != CommunityConnection.incoming) {
      return;
    }
    ++_revision; // A refresh started before this action must not undo its result.
    loading = false;
    _busy.add(author.id);
    _notify();
    try {
      if (state == CommunityConnection.incoming) {
        final request =
            _data!.pendingFriends.firstWhere((f) => _otherId(f) == author.id);
        await actions.acceptRequest(request.id);
      } else {
        await actions.sendFriendRequest({
          'requesterId': userId,
          'recipientId': author.id,
          'responderUsername': author.username,
          'message': '',
          'type': 'FRIEND_REQUEST',
        });
      }
      if (_disposed) return;
      _confirmed[author.id] = state == CommunityConnection.incoming
          ? CommunityConnection.friends
          : CommunityConnection.outgoing;
      // The feed's confirmed state remains usable on a temporary read failure.
      await refresh();
    } finally {
      _busy.remove(author.id);
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_revision;
    super.dispose();
  }
}
