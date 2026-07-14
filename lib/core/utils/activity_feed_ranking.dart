import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';

int computeActivityFallbackScore(ActivityListItem item) {
  final rating = item.mediaRating ?? item.reviewData?.rating;

  var baseScore = 20;
  switch (item.type) {
    case ActivityListType.movieRating:
    case ActivityListType.showRating:
      baseScore = (rating != null && rating >= 9) ? 100 : 60;
      break;
    case ActivityListType.movieReview:
    case ActivityListType.showReview:
      baseScore = 90;
      break;
    case ActivityListType.movieWatched:
    case ActivityListType.showWatched:
      baseScore = item.isRewatch ? 80 : 60;
      break;
    case ActivityListType.favoriteMovie:
    case ActivityListType.favoriteShow:
    case ActivityListType.favoritePerson:
      baseScore = 70;
      break;
    case ActivityListType.movieWatchlist:
    case ActivityListType.showWatchlist:
      baseScore = 40;
      break;
    case ActivityListType.watchRequestSent:
    case ActivityListType.watchRequestAccepted:
    case ActivityListType.watchRequest:
    case ActivityListType.unknown:
      baseScore = 20;
      break;
  }

  return baseScore + _recencyBoost(_tryParseDate(item.timestamp));
}

List<ActivityListItem> rankActivitiesForFeed(
    List<ActivityListItem> activities) {
  if (activities.length < 2) return List<ActivityListItem>.from(activities);

  final hasBackendScores = activities.any((a) => a.activityScore > 0);
  if (hasBackendScores) return List<ActivityListItem>.from(activities);

  final ranked = List<ActivityListItem>.from(activities);
  ranked.sort((a, b) {
    final scoreCompare = computeActivityFallbackScore(b)
        .compareTo(computeActivityFallbackScore(a));
    if (scoreCompare != 0) return scoreCompare;

    final aDate = _tryParseDate(a.timestamp);
    final bDate = _tryParseDate(b.timestamp);
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  });
  return ranked;
}

int computeMovieFriendActivityFallbackScore(MovieFriendActivity activity) {
  var baseScore = 0;
  if (activity.rating != null && activity.rating! >= 9) {
    baseScore = 100;
  } else if (activity.reviewRecommended != null) {
    baseScore = 90;
  } else if (activity.watched && activity.isRewatch) {
    baseScore = 80;
  } else if (activity.favorited) {
    baseScore = 70;
  } else if (activity.watched) {
    baseScore = 60;
  } else if (activity.onWatchlist) {
    baseScore = 40;
  }

  return baseScore + _recencyBoost(_tryParseDate(activity.createdAt));
}

List<MovieFriendActivity> rankMovieFriendActivities(
    List<MovieFriendActivity> activities) {
  if (activities.length < 2) {
    return List<MovieFriendActivity>.from(activities);
  }

  final hasBackendScores = activities.any((a) => a.activityScore > 0);
  if (hasBackendScores) return List<MovieFriendActivity>.from(activities);

  final ranked = List<MovieFriendActivity>.from(activities);
  ranked.sort((a, b) {
    final scoreCompare = computeMovieFriendActivityFallbackScore(b)
        .compareTo(computeMovieFriendActivityFallbackScore(a));
    if (scoreCompare != 0) return scoreCompare;

    final aDate = _tryParseDate(a.createdAt);
    final bDate = _tryParseDate(b.createdAt);
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  });
  return ranked;
}

int _recencyBoost(DateTime? date) {
  if (date == null) return 0;
  final age = DateTime.now().difference(date);
  if (age.inHours < 6) return 10;
  if (age.inHours < 24) return 8;
  if (age.inDays < 3) return 5;
  if (age.inDays < 7) return 3;
  return 0;
}

DateTime? _tryParseDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  return DateTime.tryParse(iso);
}
