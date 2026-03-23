import '../models/notification.dart';
import 'api_client.dart';

class NotificationService {
  static Future<List<FlixieNotification>> getNotifications(
      String userId) async {
    final data = await ApiClient.get('/notifications/$userId');
    return (data as List<dynamic>)
        .map((e) => FlixieNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> markAsRead(String notificationId) async {
    await ApiClient.patch(
      '/notifications/$notificationId',
      body: {'isRead': true},
    );
  }

  static Future<FlixieNotification> createNotification(
      Map<String, dynamic> body) async {
    final data = await ApiClient.post('/notifications', body: body);
    return FlixieNotification.fromJson(data as Map<String, dynamic>);
  }
}
