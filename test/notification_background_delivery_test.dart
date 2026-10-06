import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // No platform-channel mock: attempting to initialize/show a system
  // notification would fail this test with MissingPluginException.
  for (final field in ['type', 'notificationType']) {
    for (final type in ['COMMUNITY_REPLY', 'community_reply']) {
      test('queued $field=$type never initializes or displays a local push',
          () async {
        await PushNotificationService.showBackgroundDataNotification(
          RemoteMessage(data: {
            field: type,
            'title': 'Community replies',
            'body': 'People have replied to your discussion.',
            'communityRoute': '/genre-communities/1/discussions/thread'
          }),
        );
      });
    }
  }
}
