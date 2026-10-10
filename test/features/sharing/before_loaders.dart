import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';

// Original loader bodies retained for the controlled request baseline.
class BeforeShareLoaders {
  BeforeShareLoaders(this.auth);
  final AuthProvider auth;
  Future<List<Group>> loadGroups(String userId) async {
    final cached = auth.cachedGroups ?? const <Group>[];
    if (cached.isNotEmpty) {
      return cached.where((group) => group.id?.isNotEmpty == true).toList();
    }

    final fetched = await GroupService.getUserGroups(userId);
    auth.updateCachedGroups(fetched);
    return fetched.where((group) => group.id?.isNotEmpty == true).toList();
  }

  Future<List<Friendship>> loadFriends(String userId) async {
    final cached = auth.cachedFriends?.friendships ?? const <Friendship>[];
    if (cached.isNotEmpty) {
      return cached
          .where((friendship) => friendship.friendUser?.id.isNotEmpty == true)
          .toList();
    }

    final fetched = await FriendService.getFriends(userId);
    auth.updateCachedFriends(fetched);
    return fetched.friendships
        .where((friendship) => friendship.friendUser?.id.isNotEmpty == true)
        .toList();
  }
}
