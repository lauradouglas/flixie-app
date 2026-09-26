import 'dart:math';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friendship.dart';

class ActivityComment {
  const ActivityComment(
      {required this.id,
      required this.author,
      required this.body,
      required this.containsSpoilers,
      this.createdAt});
  final String id, body;
  final DateTime? createdAt;
  final FriendshipUser author;
  final bool containsSpoilers;
  factory ActivityComment.fromJson(Map<String, dynamic> data) =>
      ActivityComment(
          id: data['id'] as String,
          createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
          author:
              FriendshipUser.fromJson(Map<String, dynamic>.from(data['user'])),
          body: data['body'] as String,
          containsSpoilers: data['containsSpoilers'] == true);
}

class ActivityCommentPage {
  const ActivityCommentPage(this.items, this.nextCursor);
  final List<ActivityComment> items;
  final String? nextCursor;
}

class FriendActivityService {
  const FriendActivityService();
  String postPath(ActivityListItem item) =>
      '/friends/activity/${Uri.encodeComponent(item.userId)}/${item.type.value}/${Uri.encodeComponent(item.id)}';
  Future<ActivityListItem> post(String owner, String type, String id) async =>
      ActivityListItem.fromJson(Map<String, dynamic>.from(await ApiClient.get(
          '/friends/activity/${Uri.encodeComponent(owner)}/${Uri.encodeComponent(type)}/${Uri.encodeComponent(id)}')));
  Future<ActivityCommentPage> comments(ActivityListItem item,
      {String? cursor}) async {
    final data = await ApiClient.get('${postPath(item)}/comments',
        queryParams: {if (cursor != null) 'cursor': cursor}) as Map;
    return ActivityCommentPage(
        (data['items'] as List)
            .map((r) => ActivityComment.fromJson(Map<String, dynamic>.from(r)))
            .toList(),
        data['nextCursor'] as String?);
  }

  Future<void> comment(ActivityListItem item,
      {required String id,
      required String body,
      required bool spoilers}) async {
    await ApiClient.post('${postPath(item)}/comments',
        body: {'id': id, 'body': body, 'containsSpoilers': spoilers});
  }

  Future<void> deleteComment(ActivityListItem item, String id) async {
    await ApiClient.delete(
        '${postPath(item)}/comments/${Uri.encodeComponent(id)}');
  }

  static String newCommentId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
