import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';
import 'package:flixie_app/core/utils/activity_feed_ranking.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _activityJson({
  required String id,
  required String type,
  double? rating,
  int? watchCount,
  int? activityScore,
  String? createdAt,
}) {
  return <String, dynamic>{
    'id': id,
    'userId': 'u1',
    'username': 'alex',
    'firstName': 'Alex',
    'lastName': 'L',
    'movieId': 10,
    'type': type,
    'rating': rating,
    'watchCount': watchCount,
    'activityScore': activityScore,
    'createdAt': createdAt ?? '2025-01-01T12:00:00.000Z',
    'updatedAt': '2025-01-01T12:00:00.000Z',
    'removed': false,
    'movie': <String, dynamic>{
      'title': 'Movie $id',
      'posterPath': '/poster.jpg',
    },
  };
}

MovieFriendActivity _movieFriend({
  required String id,
  bool watched = false,
  bool favorited = false,
  bool onWatchlist = false,
  int? rating,
  bool? recommended,
  int activityScore = 0,
}) {
  return MovieFriendActivity.fromJson(<String, dynamic>{
    'id': id,
    'user': <String, dynamic>{
      'id': 'u$id',
      'username': 'friend$id',
    },
    'watched': watched,
    'favorited': favorited,
    'onWatchlist': onWatchlist,
    'rating': rating,
    'activityScore': activityScore,
    if (recommended != null)
      'review': <String, dynamic>{'recommended': recommended},
  });
}

void main() {
  test('ActivityListItem parses activity score and rewatch metadata', () {
    final scored = ActivityListItem.fromJson(_activityJson(
      id: 'a1',
      type: 'rewatched',
      watchCount: 3,
      activityScore: 87,
    ));

    final fallback = ActivityListItem.fromJson(_activityJson(
      id: 'a2',
      type: 'added_to_favourites',
    ));

    expect(scored.activityScore, 87);
    expect(scored.isRewatch, isTrue);
    expect(scored.watchCount, 3);
    expect(scored.type, ActivityListType.movieWatched);

    expect(fallback.activityScore, 0);
    expect(fallback.type, ActivityListType.favoriteMovie);
  });

  test('rankActivitiesForFeed falls back to deterministic priority ordering',
      () {
    final activities = <ActivityListItem>[
      ActivityListItem.fromJson(
          _activityJson(id: 'watchlist', type: 'watchlist-movie')),
      ActivityListItem.fromJson(
          _activityJson(id: 'watched', type: 'watched-movie')),
      ActivityListItem.fromJson(
          _activityJson(id: 'fav', type: 'favorite-movie')),
      ActivityListItem.fromJson(
          _activityJson(id: 'rewatch', type: 'rewatched', watchCount: 2)),
      ActivityListItem.fromJson(
          _activityJson(id: 'review', type: 'movie-review')),
      ActivityListItem.fromJson(
          _activityJson(id: 'rating', type: 'movie-rating', rating: 9.2)),
    ];

    final ranked = rankActivitiesForFeed(activities);
    final ids = ranked.map((a) => a.id).toList(growable: false);

    expect(ids,
        <String>['rating', 'review', 'rewatch', 'fav', 'watched', 'watchlist']);
  });

  test(
      'rankActivitiesForFeed keeps backend order when activityScore is present',
      () {
    final activities = <ActivityListItem>[
      ActivityListItem.fromJson(_activityJson(
        id: 'b',
        type: 'watchlist-movie',
        activityScore: 40,
      )),
      ActivityListItem.fromJson(_activityJson(
        id: 'a',
        type: 'movie-review',
        activityScore: 90,
      )),
    ];

    final ranked = rankActivitiesForFeed(activities);
    expect(ranked.map((a) => a.id).toList(growable: false), <String>['b', 'a']);
  });

  test('rankMovieFriendActivities fallback prioritizes strong actions', () {
    final activities = <MovieFriendActivity>[
      _movieFriend(id: '1', onWatchlist: true),
      _movieFriend(id: '2', watched: true),
      _movieFriend(id: '3', favorited: true),
      _movieFriend(id: '4', watched: true, recommended: true),
      _movieFriend(id: '5', rating: 10),
    ];

    final ranked = rankMovieFriendActivities(activities);
    final ids = ranked.map((a) => a.userId).toList(growable: false);

    expect(ids, <String>['u5', 'u4', 'u3', 'u2', 'u1']);
  });
}
