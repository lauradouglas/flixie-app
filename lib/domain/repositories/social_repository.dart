import '../../models/activity_list_item.dart';
import '../../models/friendship.dart';

abstract class SocialRepository {
  Future<FriendsData> getFriends(String userId);
  Future<List<ActivityListItem>> getFriendsActivityLists(String userId);
  Future<void> updateRequest(String requestId, String status, {String response = ''});
  Future<void> sendFriendRequest(Map<String, dynamic> body);
  Future<void> removeFriend(String userId, String friendId);
}
