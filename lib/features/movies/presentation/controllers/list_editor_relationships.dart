import 'package:flutter/foundation.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';

/// Per-editor lazy relationship reads. Successful results survive scope toggles.
class ListEditorRelationships extends ChangeNotifier {
  ListEditorRelationships(
      {required this.userId,
      required this.isCurrentUser,
      this.loadFriends = FriendService.getFriends,
      this.loadGroups = GroupService.getUserGroups});
  final String userId;
  final bool Function() isCurrentUser;
  final Future<FriendsData> Function(String) loadFriends;
  final Future<List<Group>> Function(String) loadGroups;
  List<FriendshipUser> friends = const [];
  List<Group> groups = const [];
  bool loadingFriends = false, loadingGroups = false;
  bool friendsLoaded = false, groupsLoaded = false;
  String? friendsError, groupsError;
  bool _disposed = false;
  bool get _active => !_disposed && isCurrentUser();

  Future<void> load(String scope) async {
    if (!_active) return;
    if (scope == ListScope.friends) {
      if (loadingFriends || friendsLoaded) return;
      loadingFriends = true;
      friendsError = null;
      notifyListeners();
      try {
        final data = await loadFriends(userId);
        if (!_active) return;
        friends = List.unmodifiable(data.friendships
            .map((f) => f.friendUser)
            .whereType<FriendshipUser>());
        friendsLoaded = true;
      } catch (_) {
        if (!_active) return;
        friendsError = 'Could not load friends. Retry';
      }
      if (!_active) return;
      loadingFriends = false;
      notifyListeners();
    } else if (scope == ListScope.group) {
      if (loadingGroups || groupsLoaded) return;
      loadingGroups = true;
      groupsError = null;
      notifyListeners();
      try {
        final data = await loadGroups(userId);
        if (!_active) return;
        groups = List.unmodifiable(data);
        groupsLoaded = true;
      } catch (_) {
        if (!_active) return;
        groupsError = 'Could not load groups. Retry';
      }
      if (!_active) return;
      loadingGroups = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
