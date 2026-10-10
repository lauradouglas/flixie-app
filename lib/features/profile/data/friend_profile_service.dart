import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friendship.dart';
import 'user_service.dart';

/// Existing API boundary for another user's visible profile; adds no cache.
class FriendProfileService {
  const FriendProfileService();
  Future<User?> user(String id) => UserService.getUserById(id);
  Future<List<Review>> reviews(String id) => UserService.getUserReviews(id);
  Future<List<MovieRating>> ratings(String id) =>
      UserService.getUserMovieRatings(id);
  Future<({List<ActivityListItem> items, String? nextCursor})> activity(
      String id,
      {String? cursor}) async {
    final page = await UserService.getUserActivityPage(id, cursor: cursor);
    return (items: page.items, nextCursor: page.nextCursor);
  }

  Future<FriendsData> friends(String id) => FriendService.getFriends(id);
  Future<void> sendFriendRequest(Map<String, dynamic> data) async {
    await FriendService.sendFriendRequest(data);
  }

  Future<void> removeFriend(String viewer, String subject) async {
    await FriendService.removeFriend(viewer, subject);
  }

  Future<void> updateRequest(String id, String status) async {
    await FriendService.updateRequest(id, status);
  }
}
