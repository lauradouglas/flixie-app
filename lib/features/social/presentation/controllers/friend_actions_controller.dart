import 'package:flixie_app/features/social/data/social_repository_impl.dart';
import 'package:flixie_app/features/social/data/friend_actions_usecase.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friendship.dart';

class FriendActionsController {
  FriendActionsController({FriendActionsUseCase? useCase}) : _useCase = useCase ?? FriendActionsUseCase(SocialRepositoryImpl());

  static final FriendActionsController instance = FriendActionsController();

  final FriendActionsUseCase _useCase;

  Future<FriendsData> getFriends(String userId) => _useCase.getFriends(userId);
  Future<List<ActivityListItem>> getFriendsActivityLists(String userId) => _useCase.getFriendsActivityLists(userId);
  Future<void> acceptRequest(String requestId) => _useCase.acceptRequest(requestId);
  Future<void> declineRequest(String requestId) => _useCase.declineRequest(requestId);
  Future<void> sendFriendRequest(Map<String, dynamic> body) => _useCase.sendFriendRequest(body);
  Future<void> removeFriend(String userId, String friendId) => _useCase.removeFriend(userId, friendId);
}
