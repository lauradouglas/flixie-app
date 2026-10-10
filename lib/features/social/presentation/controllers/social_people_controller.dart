import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/friendship.dart';
import 'friend_actions_controller.dart';

/// Owns People reads and confirmed request responses for one mounted account.
class SocialPeopleController extends ChangeNotifier {
  SocialPeopleController(
      {required this.auth, this.actions = const FriendActionsController()})
      : viewer = auth.dbUser?.id {
    data = auth.cachedFriends;
    loading = data == null && viewer != null;
  }
  final AuthProvider auth;
  final FriendActionsController actions;
  final String? viewer;
  FriendsData? data;
  bool loading = false;
  String? error;
  int _generation = 0;
  bool _disposed = false;
  final _busy = <String>{};
  bool get owns => !_disposed && auth.dbUser?.id == viewer;
  void _notify() {
    if (owns) notifyListeners();
  }

  Future<void> load() async {
    if (!owns || viewer == null) return;
    final generation = ++_generation;
    try {
      final result = await actions.getFriends(viewer!);
      if (!owns || generation != _generation) return;
      data = result;
      error = null;
      auth.updateCachedFriends(result);
    } catch (_) {
      if (owns && generation == _generation) {
        error = data == null ? 'Failed to load friends.' : null;
      }
    } finally {
      if (owns && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  /// Null means ignored, disposed or a different account now owns the screen.
  Future<bool?> respond(Friendship request, {required bool accept}) async {
    if (!owns ||
        viewer == null ||
        data == null ||
        !data!.pendingFriends.any((f) => f.id == request.id) ||
        !_busy.add(request.id)) {
      return null;
    }
    try {
      if (accept) {
        await actions.acceptRequest(request.id);
      } else {
        await actions.declineRequest(request.id);
      }
      if (!owns) return null;
      // A pending read must not restore the request we just resolved.
      _generation++;
      loading = false;
      data = data!.copyWith(
          pendingFriends:
              data!.pendingFriends.where((f) => f.id != request.id).toList(),
          friendships: [
            ...data!.friendships,
            if (accept && !data!.friendships.any((f) => f.id == request.id))
              Friendship(
                  id: request.id,
                  friend: request.friendUser,
                  createdAt: '',
                  updatedAt: ''),
          ]);
      auth.updateCachedFriends(data!);
      _notify();
      return true;
    } catch (_) {
      return owns ? false : null;
    } finally {
      _busy.remove(request.id);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
