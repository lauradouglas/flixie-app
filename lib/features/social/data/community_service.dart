import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friendship.dart';

class CommunityPage {
  const CommunityPage(this.items, this.nextCursor);
  final List<ActivityListItem> items;
  final String? nextCursor;
  factory CommunityPage.fromJson(Map data) => CommunityPage(
      (data['items'] as List)
          .map((item) =>
              ActivityListItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      data['nextCursor'] as String?);
}

class CommunityProfile {
  const CommunityProfile(
      {required this.user,
      this.bio,
      this.favourites = const [],
      this.genres = const []});
  final FriendshipUser user;
  final String? bio;
  final List<String> genres;
  final List<Map<String, dynamic>> favourites;
}

class CommunityService {
  const CommunityService();
  Future<CommunityPage> load(
      {String? cursor,
      String filter = 'all',
      String sort = 'latest',
      String? owner,
      bool saved = false}) async {
    final query = <String, String>{
      if (cursor != null) 'cursor': cursor,
      if (!saved) ...{
        'filter': filter,
        'sort': sort,
        if (owner != null) 'owner': owner
      }
    };
    final data = await ApiClient.get(
        saved ? '/community/saved' : '/community/activity',
        queryParams: query) as Map;
    return CommunityPage.fromJson(data);
  }

  Future<Map<String, dynamic>> settings() async =>
      Map<String, dynamic>.from(await ApiClient.get('/community/settings'));
  Future<bool> sharing() async =>
      (await settings())['communitySharing'] == true;
  Future<void> setSharing(bool enabled) =>
      updateSettings({'communitySharing': enabled});
  Future<void> updateSettings(Map<String, bool> values) async {
    await ApiClient.put('/community/settings', body: values);
  }

  Future<CommunityProfile> profile(String id) async {
    final data = Map<String, dynamic>.from(
        await ApiClient.get('/community/profiles/${Uri.encodeComponent(id)}'));
    return CommunityProfile(
        user: FriendshipUser.fromJson(data),
        bio: data['bio'] as String?,
        genres: (data['genres'] as List? ?? [])
            .map((g) => g['name'].toString())
            .toList(),
        favourites: (data['favourites'] as List)
            .map((v) => Map<String, dynamic>.from(v))
            .toList());
  }

  String postPath(ActivityListItem item) =>
      '/community/posts/${Uri.encodeComponent(item.userId)}/${item.type.value}/${Uri.encodeComponent(item.id)}';
  Future<ActivityListItem> post(String owner, String type, String id) async =>
      ActivityListItem.fromJson(Map<String, dynamic>.from(await ApiClient.get(
          '/community/posts/${Uri.encodeComponent(owner)}/${Uri.encodeComponent(type)}/${Uri.encodeComponent(id)}')));
  Future<bool> isSaved(ActivityListItem item) async =>
      (await ApiClient.get('${postPath(item)}/bookmark'))['saved'] == true;
  Future<void> save(ActivityListItem item, bool saved) async {
    await ApiClient.put('${postPath(item)}/bookmark', body: {'saved': saved});
  }

  Future<List<Map<String, dynamic>>> people() async =>
      List<Map<String, dynamic>>.from(
          (await ApiClient.get('/community/people'))['items']);
  Future<CommunityPage> following(
          {String? cursor,
          String filter = 'all',
          String sort = 'latest'}) async =>
      CommunityPage.fromJson(
          await ApiClient.get('/community/activity', queryParams: {
        'audience': 'following',
        'filter': filter,
        'sort': sort,
        if (cursor != null) 'cursor': cursor
      }));
  Future<bool> follows(String path) async =>
      (await ApiClient.get('/community/$path/follow'))['following'] == true;
  Future<void> follow(String path, bool value) async {
    await ApiClient.put('/community/$path/follow', body: {'following': value});
  }

  Future<void> feedPreference(ActivityListItem item, String action) async {
    await ApiClient.put('/community/feed-preferences', body: {
      'ownerId': item.userId,
      'activityType': item.type.value,
      'activityId': item.id,
      'action': action
    });
  }

  Future<void> resetFeedPreferences() async {
    await ApiClient.delete('/community/feed-preferences');
  }

  Future<Map<String, dynamic>> replies(ActivityListItem item,
          {String? cursor, String? parent}) async =>
      Map<String, dynamic>.from(await ApiClient.get('${postPath(item)}/replies',
          queryParams: {
            if (cursor != null) 'cursor': cursor,
            if (parent != null) 'parent': parent
          }));
  Future<void> reply(ActivityListItem item,
      {required String id,
      required String body,
      required bool spoilers,
      String? parent}) async {
    await ApiClient.post('${postPath(item)}/replies', body: {
      'id': id,
      'body': body,
      'containsSpoilers': spoilers,
      'parentId': parent
    });
  }

  Future<void> deleteReply(ActivityListItem item, String id) async {
    await ApiClient.delete(
        '${postPath(item)}/replies/${Uri.encodeComponent(id)}');
  }

  Future<void> setReplies(ActivityListItem item, bool enabled) async {
    await ApiClient.put('${postPath(item)}/reply-settings',
        body: {'repliesEnabled': enabled});
  }

  Future<List<Map<String, dynamic>>> invitations() async =>
      List<Map<String, dynamic>>.from(
          (await ApiClient.get('/community/list-invitations'))['items']);
  Future<List<Map<String, dynamic>>> editors(String listId) async =>
      List<Map<String, dynamic>>.from((await ApiClient.get(
          '/community/lists/${Uri.encodeComponent(listId)}/members'))['items']);
  Future<void> invitation(String listId, String userId, String action) async {
    await ApiClient.put(
        '/community/lists/${Uri.encodeComponent(listId)}/invitations/${Uri.encodeComponent(userId)}',
        body: {'action': action});
  }
}

class CommunityReply {
  CommunityReply(Map<String, dynamic> json)
      : id = json['id'] as String,
        body = json['body'] as String,
        author =
            FriendshipUser.fromJson(Map<String, dynamic>.from(json['user'])),
        spoilers = json['containsSpoilers'] == true,
        deleted = json['deleted'] == true;
  final String id, body;
  final FriendshipUser author;
  final bool spoilers, deleted;
}
