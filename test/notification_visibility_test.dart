import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/core/utils/notification_visibility.dart';
import 'package:flixie_app/models/notification.dart';

FlixieNotification notification({
  required String id,
  required String userId,
  required String requestId,
  required String action,
  required String createdAt,
  bool read = false,
}) {
  return FlixieNotification(
    id: id,
    userId: userId,
    type: FlixieNotification.movieWatchRequest,
    action: action,
    message: 'Watch request update',
    read: read,
    createdAt: createdAt,
    link: {
      'request': {'id': requestId},
    },
  );
}

void main() {
  test('visible count matches lifecycle notifications shown in the list', () {
    final notifications = [
      notification(
        id: 'old-duplicate',
        userId: 'user-1',
        requestId: 'request-1',
        action: FlixieNotification.actionAccepted,
        createdAt: '2026-07-22T10:00:00Z',
      ),
      notification(
        id: 'new-duplicate',
        userId: 'user-1',
        requestId: 'request-1',
        action: FlixieNotification.actionAccepted,
        createdAt: '2026-07-22T10:01:00Z',
      ),
      notification(
        id: 'unique',
        userId: 'user-1',
        requestId: 'request-2',
        action: FlixieNotification.actionDeclined,
        createdAt: '2026-07-22T10:02:00Z',
      ),
      notification(
        id: 'another-user',
        userId: 'user-2',
        requestId: 'request-3',
        action: FlixieNotification.actionAccepted,
        createdAt: '2026-07-22T10:03:00Z',
      ),
    ];

    final visible = visibleNotificationsForUser(notifications, 'user-1');

    expect(visible.map((item) => item.id), ['unique', 'new-duplicate']);
    expect(visibleUnreadNotificationCount(notifications, 'user-1'), 2);
  });

  test('read state of the displayed duplicate controls the badge', () {
    final notifications = [
      notification(
        id: 'old-unread',
        userId: 'user-1',
        requestId: 'request-1',
        action: FlixieNotification.actionAccepted,
        createdAt: '2026-07-22T10:00:00Z',
      ),
      notification(
        id: 'new-read',
        userId: 'user-1',
        requestId: 'request-1',
        action: FlixieNotification.actionAccepted,
        createdAt: '2026-07-22T10:01:00Z',
        read: true,
      ),
    ];

    expect(visibleUnreadNotificationCount(notifications, 'user-1'), 0);
  });
}
