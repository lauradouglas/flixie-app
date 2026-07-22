import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/watch_provider.dart';

class AuthPrefetchSnapshot {
  const AuthPrefetchSnapshot({
    this.activity,
    this.friends,
    this.friendsActivity,
    this.groups,
    this.ratings,
    this.reviews,
    this.trending,
    this.nowPlaying,
    this.unreadNotificationCount,
    this.notifications,
    this.watchProvidersByMovieId,
    this.userWatchProviderIds,
  });

  final List<ActivityListItem>? activity;
  final FriendsData? friends;
  final List<ActivityListItem>? friendsActivity;
  final List<Group>? groups;
  final List<MovieRating>? ratings;
  final List<Review>? reviews;
  final List<MovieShort>? trending;
  final List<MovieShort>? nowPlaying;
  final int? unreadNotificationCount;
  final List<FlixieNotification>? notifications;
  final Map<int, List<WatchProvider>>? watchProvidersByMovieId;
  final Set<int>? userWatchProviderIds;
}
