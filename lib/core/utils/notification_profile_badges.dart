import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/notification.dart';

/// Resolve only a known sender's badges; absent identities must never match.
List<String> notificationProfileBadges(
  FlixieNotification notification,
  FriendsData? friends,
) {
  if (notification.senderProfileBadges.isNotEmpty) {
    return notification.senderProfileBadges;
  }
  final senderId = notification.senderId;
  if (senderId == null || senderId.isEmpty || friends == null) return const [];
  for (final relationship in [
    ...friends.friendships,
    ...friends.pendingFriends,
    ...friends.requestedFriends,
  ]) {
    for (final user in [
      relationship.friend,
      relationship.requester,
      relationship.recipient
    ]) {
      if (user != null &&
          user.id == senderId &&
          user.profileBadges.isNotEmpty) {
        return user.profileBadges;
      }
    }
  }
  return const [];
}
