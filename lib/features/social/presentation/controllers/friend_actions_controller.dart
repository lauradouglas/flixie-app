import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friendship.dart';

class FriendActionsController {
  const FriendActionsController();

  static const FriendActionsController instance = FriendActionsController();

  Future<FriendsData> getFriends(String userId) =>
      FriendService.getFriends(userId);
  Future<List<ActivityListItem>> getFriendsActivityLists(String userId) =>
      FriendService.getFriendsActivityLists(userId);
  Future<void> acceptRequest(String requestId) =>
      FriendService.updateRequest(requestId, 'ACCEPTED');
  Future<void> declineRequest(String requestId) =>
      FriendService.updateRequest(requestId, 'DECLINED');
  Future<void> sendFriendRequest(Map<String, dynamic> body) =>
      FriendService.sendFriendRequest(body);
  Future<void> removeFriend(String userId, String friendId) =>
      FriendService.removeFriend(userId, friendId);
}
