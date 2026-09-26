import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/core/utils/notification_destination.dart';

void main() {
  test(
      'new clients use the Community destination alongside a build 70 fallback',
      () {
    expect(
        notificationDestination(const FlixieNotification(
          userId: 'me',
          type: 'COMMUNITY_REACTION',
          message: '',
          data: {
            'route': '/movies/101',
            'communityRoute': '/community/posts/me/movie-review/review-7'
          },
        )),
        '/community/posts/me/movie-review/review-7');
  });
  test(
      'fallback-only Community notifications still open existing media screens',
      () {
    expect(
        notificationDestination(const FlixieNotification(
          userId: 'me',
          type: 'COMMUNITY_REACTION',
          message: '',
          data: {'route': '/movies/101'},
        )),
        '/movies/101?source=notification');
  });
  test('invalid optional Community destinations use the compatible fallback',
      () {
    expect(
        notificationDestination(const FlixieNotification(
          userId: 'me',
          type: 'COMMUNITY_REACTION',
          message: '',
          data: {'route': '/shows/202', 'communityRoute': '/unknown-screen'},
        )),
        '/shows/202?source=notification');
  });

  for (final type in ['MOVIE_WATCH_REQUEST', 'SHOW_WATCH_REQUEST']) {
    test('$type opens its exact plan', () {
      expect(
          notificationDestination(FlixieNotification(
              userId: 'me',
              type: type,
              message: '',
              data: {'watchPlanId': 'plan-7'})),
          '/watch-requests/plan-7');
    });
  }
  test('group plan opens requests tab and exact plan', () {
    expect(
        notificationDestination(const FlixieNotification(
            userId: 'me',
            type: 'GROUP_REQUEST',
            message: '',
            data: {'watchPlanId': 'p', 'groupId': 'g', 'scope': 'GROUP'})),
        '/groups/g?tab=requests&requestId=p');
  });
  test('group invite opens invitation decision screen', () {
    expect(
        notificationDestination(const FlixieNotification(
            userId: 'me',
            type: 'GROUP_INVITE',
            message: '',
            relatedId: 'invite',
            data: {'groupId': 'g'})),
        '/group-invites/invite?groupId=g');
  });
  test('friend notification opens sender profile', () {
    expect(
        notificationDestination(const FlixieNotification(
            userId: 'me',
            type: 'FRIEND_REQUEST',
            message: '',
            senderUser: {'id': 'friend'})),
        '/friends/friend');
  });
  test('list and referral route without optional route strings', () {
    expect(
        notificationDestination(const FlixieNotification(
            userId: 'me',
            type: 'LIST_SHARED',
            message: '',
            data: {'listId': 'list'})),
        '/movie-lists/list');
    expect(
        notificationDestination(const FlixieNotification(
            userId: 'me',
            type: 'REFERRAL_JOINED',
            message: '',
            senderUser: {'id': 'friend'})),
        '/friends/friend');
  });
}
