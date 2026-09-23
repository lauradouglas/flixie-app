import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/features/social/presentation/widgets/activity_filter_bar.dart';

void main() {
  test('combined review remains available under watched, rated and reviews',
      () {
    final item = ActivityListItem.fromJson({
      'id': 'review',
      'userId': 'viewer',
      'type': 'movie_review',
      'movieId': 1,
      'rating': 9,
      'recommended': true,
      'watchLogged': true,
      'body': 'A great film',
      'createdAt': '2026-09-23T10:00:00Z',
    });
    expect(ActivityFeedFilter.watched.matches(item), isTrue);
    expect(ActivityFeedFilter.rated.matches(item), isTrue);
    expect(ActivityFeedFilter.reviews.matches(item), isTrue);
    expect(item.recommended, isTrue);
    expect(item.reviewData?.body, 'A great film');
    expect(ActivityFeedFilter.watchlists.matches(item), isFalse);
  });
  test('linked review keeps its own review id inside the permanent watch card',
      () {
    final item = ActivityListItem.fromJson({
      'id': 'watch-1',
      'watchEntryId': 'watch-1',
      'userId': 'viewer',
      'type': 'watched_movie',
      'movieId': 1,
      'watchLogged': true,
      'rating': 9,
      'recommended': false,
      'review': {
        'id': 'review-1',
        'watchEntryId': 'watch-1',
        'body': 'Later thoughts'
      },
    });
    expect(item.id, 'watch-1');
    expect(item.reviewData?.id, 'review-1');
    expect(item.reviewData?.watchEntryId, 'watch-1');
    expect(item.copyWith().reviewData?.body, 'Later thoughts');
    expect(ActivityFeedFilter.watched.matches(item), isTrue);
    expect(ActivityFeedFilter.rated.matches(item), isTrue);
    expect(ActivityFeedFilter.reviews.matches(item), isTrue);
  });
  test(
      'cleared watch rating and recommendation do not fall back to an old review',
      () {
    final item = ActivityListItem.fromJson({
      'id': 'watch',
      'watchEntryId': 'watch',
      'type': 'watched_movie',
      'rating': null,
      'recommended': null,
      'review': {'id': 'review', 'rating': 8, 'recommended': true},
    });
    expect(item.mediaRating, isNull);
    expect(item.recommended, isNull);
  });
}
