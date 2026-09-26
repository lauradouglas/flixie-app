import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/activity_list_item.dart';

class GenreCommunity {
  const GenreCommunity(
      {required this.id, required this.name, required this.joined});
  final int id;
  final String name;
  final bool joined;
  factory GenreCommunity.fromJson(Map data) => GenreCommunity(
      id: data['id'] as int,
      name: data['name'] as String,
      joined: data['joined'] == true);
  GenreCommunity withJoined(bool value) =>
      GenreCommunity(id: id, name: name, joined: value);
}

class GenreMemberRating {
  const GenreMemberRating(this.average, this.count);
  final double average;
  final int count;
}

class GenreCommunityPage {
  const GenreCommunityPage(
      {required this.community,
      required this.items,
      this.nextCursor,
      this.ratings = const {},
      this.showRatings = const {}});
  final GenreCommunity community;
  final List<ActivityListItem> items;
  final String? nextCursor;
  final Map<int, GenreMemberRating> ratings;
  final Map<int, GenreMemberRating> showRatings;
  factory GenreCommunityPage.fromJson(Map data) => GenreCommunityPage(
        community: GenreCommunity.fromJson(data['community'] as Map),
        items: (data['items'] as List)
            .map((v) => ActivityListItem.fromJson(Map<String, dynamic>.from(v)))
            .toList(),
        nextCursor: data['nextCursor'] as String?,
        showRatings: {
          for (final r in data['ratings'] as List)
            if (r['showId'] != null)
              r['showId'] as int: GenreMemberRating(
                  (r['average'] as num).toDouble(), r['count'] as int)
        },
        ratings: {
          for (final r in data['ratings'] as List)
            if (r['movieId'] != null)
              r['movieId'] as int: GenreMemberRating(
                  (r['average'] as num).toDouble(), r['count'] as int)
        },
      );
}

class GenreCommunityService {
  const GenreCommunityService();
  String _path(int id) =>
      id == -1 ? '/community/topics/anime' : '/community/genres/$id';
  Future<List<GenreCommunity>> list() async {
    final data = await ApiClient.get('/community/genres') as Map;
    return (data['items'] as List)
        .map((v) => GenreCommunity.fromJson(v as Map))
        .toList();
  }

  Future<void> setJoined(int id, bool value) async {
    await ApiClient.put('${_path(id)}/membership', body: {'joined': value});
  }

  Future<GenreCommunityPage> feed(int id,
          {String sort = 'latest', String? cursor}) async =>
      GenreCommunityPage.fromJson(await ApiClient.get('${_path(id)}/activity',
              queryParams: {'sort': sort, if (cursor != null) 'cursor': cursor})
          as Map);
}
