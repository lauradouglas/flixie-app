import '../models/friend.dart';
import '../models/friendship.dart';
import 'api_client.dart';

class FriendService {
  static Future<FriendsData> getFriends(String userId) async {
    final data = await ApiClient.get('/friends/$userId');
    return FriendsData.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> addFriend(String userId, String friendId) async {
    await ApiClient.post(
      '/friends',
      body: {'userId': userId, 'friendId': friendId},
    );
  }

  static Future<void> removeFriend(String userId, String friendId) async {
    await ApiClient.delete(
      '/friends',
      body: {'userId': userId, 'friendId': friendId},
    );
  }

  static Future<void> sendFriendRequest(Map<String, dynamic> body) async {
    await ApiClient.post('/requests', body: body);
  }

  static Future<List<FriendRequest>> getRequests(String userId) async {
    final data = await ApiClient.get('/requests/$userId');
    return (data as List<dynamic>)
        .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> updateRequest(String requestId, String status,
      {String response = ''}) async {
    await ApiClient.post('/requests/update', body: {
      'id': requestId,
      'status': status,
      'response': response,
    });
  }
}
