import '../models/notification.dart';
import 'api_client.dart';

class NotificationService {
  /// Fetches all notifications for the given user.
  static Future<List<FlixieNotification>> getNotifications(
      String userId) async {
    final data = await ApiClient.get('/notifications/user/$userId');
    final list = data as List<dynamic>;
    return list
        .map((e) => FlixieNotification.fromJson(e as Map<String, dynamic>))
        .toList();
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
