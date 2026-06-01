import '../../domain/repositories/social_repository.dart';
import '../../models/activity_list_item.dart';
import '../../models/friendship.dart';
import '../../services/friend_service.dart';

class SocialRepositoryImpl implements SocialRepository {
  @override
  Future<FriendsData> getFriends(String userId) => FriendService.getFriends(userId);

  @override
  Future<List<ActivityListItem>> getFriendsActivityLists(String userId) =>
      FriendService.getFriendsActivityLists(userId);

  @override
  Future<void> updateRequest(String requestId, String status, {String response = ''}) =>
      FriendService.updateRequest(requestId, status, response: response);

  @override
  Future<void> sendFriendRequest(Map<String, dynamic> body) => FriendService.sendFriendRequest(body);

  @override
  Future<void> removeFriend(String userId, String friendId) => FriendService.removeFriend(userId, friendId);
}
