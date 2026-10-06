import 'package:firebase_messaging/firebase_messaging.dart';
import 'foreground_watch_plan_notice.dart';

/// Foreground FCM delivery refreshes app data and may show an app banner.
/// This path intentionally has no system-notification fallback, including when
/// the navigator is not ready or OS notification permission is denied.
void dispatchForegroundNotification(
  RemoteMessage message, {
  required String? currentUserId,
  required Uri? currentUri,
  required void Function() refreshWatchPlans,
  required void Function() refreshSocial,
  required void Function(ForegroundWatchPlanNotice) showBanner,
}) {
  final data = message.data;
  if (currentUserId == null ||
      (data['recipientId'] != null && data['recipientId'] != currentUserId) ||
      data['actorId'] == currentUserId ||
      data['senderId'] == currentUserId) {
    return;
  }
  if (data['category'] == 'WATCH_PLAN') {
    refreshWatchPlans();
  } else {
    refreshSocial();
  }
  final notice = ForegroundWatchPlanNotice.fromPayload(data,
      currentUserId: currentUserId,
      messageId: message.messageId,
      title: message.notification?.title,
      body: message.notification?.body,
      currentUri: currentUri);
  if (notice != null) showBanner(notice);
}
