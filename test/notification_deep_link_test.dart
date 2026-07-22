import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/auth/notification_deep_link.dart';

void main() {
  test('group message opens the group chat tab', () {
    expect(
      notificationDeepLinkPath({
        'type': 'GROUP_MESSAGE',
        'groupId': 'group-1',
        'conversationId': 'conversation-1',
      }),
      '/groups/group-1?tab=chat',
    );
  });

  test('explicit backend route takes priority', () {
    expect(
      notificationDeepLinkPath({
        'type': 'GROUP_MESSAGE',
        'groupId': 'group-1',
        'route': '/groups/group-2?tab=chat',
      }),
      '/groups/group-2?tab=chat',
    );
  });
}
