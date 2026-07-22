import 'package:flixie_app/models/notification.dart';

List<FlixieNotification> visibleNotificationsForUser(
  Iterable<FlixieNotification> notifications,
  String userId,
) {
  final byDeduplicationKey = <String, FlixieNotification>{};
  final visible = <FlixieNotification>[];

  for (final notification in notifications.where((n) => n.userId == userId)) {
    final key = _scheduleKey(notification) ?? _watchLifecycleKey(notification);
    if (key == null) {
      visible.add(notification);
      continue;
    }
    final existing = byDeduplicationKey[key];
    if (existing == null ||
        _sortDate(notification).isAfter(_sortDate(existing))) {
      byDeduplicationKey[key] = notification;
    }
  }

  visible.addAll(byDeduplicationKey.values);
  visible.sort((a, b) => _sortDate(b).compareTo(_sortDate(a)));
  return visible;
}

int visibleUnreadNotificationCount(
  Iterable<FlixieNotification> notifications,
  String userId,
) =>
    visibleNotificationsForUser(notifications, userId)
        .where((notification) => !notification.isRead)
        .length;

String? _watchLifecycleKey(FlixieNotification notification) {
  if (notification.type != FlixieNotification.movieWatchRequest &&
      notification.type != FlixieNotification.showWatchRequest) {
    return null;
  }
  if (notification.action != FlixieNotification.actionAccepted &&
      notification.action != FlixieNotification.actionDeclined) {
    return null;
  }
  final requestId = notification.linkedRequestId;
  if (requestId == null || requestId.isEmpty) return null;
  return '${notification.type}:$requestId:${notification.action}';
}

String? _scheduleKey(FlixieNotification notification) {
  if (notification.type != FlixieNotification.movieWatchRequest &&
      notification.type != FlixieNotification.showWatchRequest) {
    return null;
  }
  final requestId = notification.linkedRequestId;
  if (requestId == null || requestId.isEmpty) return null;
  final status = notification.watchRequestScheduleStatus?.toUpperCase();
  if (status != 'PROPOSED' && status != 'AGREED' && status != 'DECLINED') {
    return null;
  }
  final proposal = notification.latestWatchScheduleProposal;
  final proposalId = proposal?['id']?.toString();
  final proposedFor = proposal?['proposedFor']?.toString();
  return [
    notification.type,
    requestId,
    status,
    if (proposalId?.isNotEmpty == true)
      proposalId
    else if (proposedFor?.isNotEmpty == true)
      proposedFor,
  ].join(':');
}

DateTime _sortDate(FlixieNotification notification) =>
    DateTime.tryParse(notification.receivedAt) ??
    DateTime.fromMillisecondsSinceEpoch(0);
