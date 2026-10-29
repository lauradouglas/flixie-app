import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/features/home/domain/home_community_selection.dart';

ActivityListItem post(String id, String user, String type,
        {int? movie, int? show}) =>
    ActivityListItem.fromJson({
      'id': id,
      'userId': user,
      'type': type,
      'movieId': movie,
      'showId': show,
      'rating': 8,
      'createdAt': '2026-10-27T12:00:00Z',
    });
void main() {
  test(
      'review subsumes its own rating without merging other people or media types',
      () {
    final items = [
      post('rating', 'maya', 'movie-rating', movie: 1),
      post('review', 'maya', 'movie-review', movie: 1),
      post('other', 'alex', 'movie-rating', movie: 1),
      post('tv', 'maya', 'show-rating', show: 1),
      post('unknown', 'maya', 'movie-rating'),
    ];
    expect(selectHomeCommunityItems(items).map((e) => e.id),
        ['review', 'other', 'tv', 'unknown']);
    expect(selectHomeCommunityItems(items.reversed).map((e) => e.id),
        ['unknown', 'tv', 'other', 'review']);
  });
  test('show review subsumes show rating and standalone ratings remain', () {
    expect(
        selectHomeCommunityItems([
          post('rating', 'maya', 'show-rating', show: 2),
          post('review', 'maya', 'show-review', show: 2),
          post('standalone', 'maya', 'movie-rating', movie: 2),
        ]).map((e) => e.id),
        ['review', 'standalone']);
  });
}
