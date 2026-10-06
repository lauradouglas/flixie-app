import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flixie_app/models/notification.dart';

/// Detects new inbox events after an initial snapshot. Existing unread items
/// are never replayed at login or resume. Only active account items are used.
class ForegroundInboxTracker {
  String? _userId;
  final Set<String> _seen = {};
  bool _hasBaseline = false;

  List<RemoteMessage> observe(String userId, List<FlixieNotification> items,
      {bool announce = true}) {
    if (_userId != userId) {
      reset();
      _userId = userId;
    }
    final messages = <RemoteMessage>[];
    for (final item in items.reversed) {
      final id = item.id;
      if (item.userId != userId || id == null) continue;
      final fresh = _seen.add(id);
      if (!_hasBaseline ||
          !announce ||
          !fresh ||
          item.isRead ||
          item.closed == true) continue;
      if ((item.type == FlixieNotification.friendRequest ||
              item.type == FlixieNotification.groupInvite) &&
          !item.isPending) continue;
      final data = <String, dynamic>{
        'type': item.type,
        'event': item.event,
        ...?item.data,
        'notificationId': id,
        'recipientId': userId,
      };
      messages.add(RemoteMessage(
          messageId: id,
          data: data,
          notification: RemoteNotification(
              title: item.title ?? item.data?['title']?.toString(),
              body: item.message)));
    }
    _hasBaseline = true;
    // Bound state without forgetting current inbox items and replaying them.
    if (_seen.length > 1000) {
      final current = items
          .where((n) => n.userId == userId)
          .map((n) => n.id)
          .whereType<String>()
          .toSet();
      _seen.removeWhere((id) => !current.contains(id));
    }
    return messages;
  }

  void reset() {
    _userId = null;
    _hasBaseline = false;
    _seen.clear();
  }
}
