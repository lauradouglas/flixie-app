import 'package:flixie_app/core/utils/notification_visibility.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/core/api/api_client.dart';

class NotificationService {
  static Future<NotificationPage> getPage(String userId,
      {String? cursor}) async {
    final query =
        cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}';
    final data =
        await ApiClient.get('/notifications/user/$userId?page=true$query');
    // Supports the currently deployed API while backend and app roll out.
    if (data is List) {
      final items = data
          .map((e) => FlixieNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      return NotificationPage(visibleNotificationsForUser(items, userId),
          unreadCount: visibleUnreadNotificationCount(items, userId),
          supportsBulkRead: false);
    }
    final page = data as Map<String, dynamic>;
    return NotificationPage(
        (page['items'] as List)
            .map((e) => FlixieNotification.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: page['nextCursor'] as String?,
        unreadCount: page['unreadCount'] as int);
  }

  static Future<List<FlixieNotification>> getNotifications(
          String userId) async =>
      (await getPage(userId)).items;

  static Future<void> markAllRead() async {
    await ApiClient.post('/notifications/read-all', body: {});
  }

  /// Marks a notification as read.
  static Future<void> markAsRead(String notificationId) async {
    await ApiClient.post(
      '/notifications/update',
      body: {'id': notificationId, 'read': true},
    );
  }

  /// Updates a notification (e.g. accept or decline a request).
  ///
  /// Pass [action] as one of [FlixieNotification.actionAccepted] or
  /// [FlixieNotification.actionDeclined].
  static Future<FlixieNotification> updateNotification(
    String id, {
    String? action,
    bool? read,
    bool? closed,
    String? linkId,
  }) async {
    final data = await ApiClient.post('/notifications/update', body: {
      'id': id,
      if (action != null) 'action': action,
      if (read != null) 'read': read,
      if (closed != null) 'closed': closed,
      if (linkId != null) 'linkId': linkId,
    });
    return FlixieNotification.fromJson(data as Map<String, dynamic>);
  }

  /// Deletes a notification.
  static Future<void> deleteNotification(String notificationId) async {
    await ApiClient.delete('/notifications/delete/$notificationId');
  }

  static Future<FlixieNotification> createNotification(
      Map<String, dynamic> body) async {
    final data = await ApiClient.post('/notifications', body: body);
    return FlixieNotification.fromJson(data as Map<String, dynamic>);
  }
}

class NotificationPage {
  const NotificationPage(this.items,
      {this.nextCursor,
      required this.unreadCount,
      this.supportsBulkRead = true});
  final List<FlixieNotification> items;
  final String? nextCursor;
  final int unreadCount;
  final bool supportsBulkRead;
}
