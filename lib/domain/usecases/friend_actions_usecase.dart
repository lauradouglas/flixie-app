import '../repositories/social_repository.dart';
import '../../models/activity_list_item.dart';
import '../../models/friendship.dart';

class FriendActionsUseCase {
  FriendActionsUseCase(this._socialRepository);

  final SocialRepository _socialRepository;

  Future<FriendsData> getFriends(String userId) => _socialRepository.getFriends(userId);

  Future<List<ActivityListItem>> getFriendsActivityLists(String userId) =>
      _socialRepository.getFriendsActivityLists(userId);

  Future<void> acceptRequest(String requestId) => _socialRepository.updateRequest(requestId, 'ACCEPTED');

  Future<void> declineRequest(String requestId) => _socialRepository.updateRequest(requestId, 'DECLINED');

  Future<void> sendFriendRequest(Map<String, dynamic> body) => _socialRepository.sendFriendRequest(body);

  Future<void> removeFriend(String userId, String friendId) => _socialRepository.removeFriend(userId, friendId);
}
