import 'package:flixie_app/models/activity_list_item.dart';

/// A review already carries its score, so hide its author's separate rating.
/// Keep different authors and film/show namespaces independent.
List<ActivityListItem> selectHomeCommunityItems(
    Iterable<ActivityListItem> items) {
  String? mediaKey(ActivityListItem item) => item.showId != null
      ? '${item.userId}:show:${item.showId}'
      : item.movieId != null
          ? '${item.userId}:movie:${item.movieId}'
          : null;
  final reviews = {
    for (final item in items)
      if (item.type == ActivityListType.movieReview ||
          item.type == ActivityListType.showReview)
        if (mediaKey(item) != null) mediaKey(item),
  };
  return items
      .where((item) =>
          (item.type != ActivityListType.movieRating &&
              item.type != ActivityListType.showRating) ||
          !reviews.contains(mediaKey(item)))
      .toList();
}
