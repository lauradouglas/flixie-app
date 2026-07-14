import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/review.dart';

class AuthPrefetchSnapshot {
  const AuthPrefetchSnapshot({
    this.activity,
    this.friends,
    this.friendsActivity,
    this.ratings,
    this.reviews,
    this.trending,
    this.nowPlaying,
    this.unreadNotificationCount,
  });

  final List<ActivityListItem>? activity;
  final FriendsData? friends;
  final List<ActivityListItem>? friendsActivity;
  final List<MovieRating>? ratings;
  final List<Review>? reviews;
  final List<MovieShort>? trending;
  final List<MovieShort>? nowPlaying;
  final int? unreadNotificationCount;
}
