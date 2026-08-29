import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/auth/notification_deep_link.dart';
import 'package:flixie_app/core/utils/notification_visibility.dart';
import 'package:flixie_app/models/notification.dart';

FlixieNotification watchNotification({
  required String id,
  required String event,
  required String planId,
  required String createdAt,
  String scope = 'DIRECT',
  String? groupId,
}) =>
    FlixieNotification(
      id: id,
      userId: 'user-1',
      type: scope == 'GROUP'
          ? FlixieNotification.groupRequest
          : FlixieNotification.movieWatchRequest,
      message: 'Watch Plan update',
      createdAt: createdAt,
      event: event,
      data: {
        'category': 'WATCH_PLAN',
        'event': event,
        'scope': scope,
        'watchPlanId': planId,
        if (groupId != null) 'groupId': groupId,
      },
    );

void main() {
  test('maps legacy completion to all participants logged', () {
    final notification = watchNotification(
      id: 'n1',
      event: 'everyone_rated',
      planId: 'plan-1',
      createdAt: '2026-08-25T10:00:00Z',
    );
    expect(notification.watchPlanEvent, 'ALL_PARTICIPANTS_LOGGED');
    expect(notification.isWatchPlanNotification, isTrue);
  });

  test('canonical payload opens the exact direct or group plan', () {
    expect(
      notificationDeepLinkPath({
        'category': 'WATCH_PLAN',
        'event': 'PLAN_SCHEDULED',
        'scope': 'DIRECT',
        'watchPlanId': 'direct-plan',
      }),
      '/watch-requests/direct-plan',
    );
    expect(
      notificationDeepLinkPath({
        'category': 'WATCH_PLAN',
        'event': 'ALL_PARTICIPANTS_LOGGED',
        'scope': 'GROUP',
        'watchPlanId': 'group-plan',
        'groupId': 'group-1',
      }),
      '/groups/group-1?tab=requests&requestId=group-plan',
    );
  });

  test('a canonical lifecycle duplicate keeps the newest notification only', () {
    final visible = visibleNotificationsForUser([
      watchNotification(
        id: 'old',
        event: 'PLAN_SCHEDULED',
        planId: 'plan-1',
        createdAt: '2026-08-25T09:00:00Z',
      ),
      watchNotification(
        id: 'new',
        event: 'PLAN_SCHEDULED',
        planId: 'plan-1',
        createdAt: '2026-08-25T10:00:00Z',
      ),
      watchNotification(
        id: 'recap',
        event: 'ALL_PARTICIPANTS_LOGGED',
        planId: 'plan-1',
        createdAt: '2026-08-25T11:00:00Z',
      ),
    ], 'user-1');

    expect(visible.map((item) => item.id), ['recap', 'new']);
  });

  test('a notification media route opens its movie or show detail', () {
    final movie = watchNotification(
      id: 'movie',
      event: 'TITLE_SELECTED',
      planId: 'plan-1',
      createdAt: '2026-08-25T10:00:00Z',
    ).copyWith(data: {
      'category': 'WATCH_PLAN',
      'event': 'TITLE_SELECTED',
      'movieId': '123',
    });
    final show = watchNotification(
      id: 'show',
      event: 'TITLE_SELECTED',
      planId: 'plan-2',
      createdAt: '2026-08-25T10:00:00Z',
    ).copyWith(data: {
      'category': 'WATCH_PLAN',
      'event': 'TITLE_SELECTED',
      'showId': '456',
    });
    expect(movie.watchMediaRoute, '/movies/123?source=notification');
    expect(show.watchMediaRoute, '/shows/456?source=notification');
  });
}
