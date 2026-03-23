import '../models/friend.dart';
import 'api_client.dart';

class FriendService {
  static Future<List<Friend>> getFriends(String userId) async {
    final data = await ApiClient.get('/friends/$userId');
    return (data as List<dynamic>)
        .map((e) => Friend.fromJson(e as Map<String, dynamic>))
        .toList();
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

  static Future<void> updateRequest(
      String requestId, Map<String, dynamic> body) async {
    await ApiClient.put('/requests/$requestId', body: body);
  }
}
