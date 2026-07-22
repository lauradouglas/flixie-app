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

  test('watch request opens its full-page detail route', () {
    expect(
      notificationDeepLinkPath({
        'type': 'datetime_accepted',
        'watchRequestId': 'request-1',
        'conversationId': 'conversation-1',
        'route': '/conversations/conversation-1?watchRequestId=request-1',
      }),
      '/watch-requests/request-1',
    );
  });

  test('legacy conversation watch route recovers its request id', () {
    expect(
      notificationDeepLinkPath({
        'type': 'datetime_accepted',
        'route': '/conversations/conversation-1?watchRequestId=request-legacy',
      }),
      '/watch-requests/request-legacy',
    );
  });

  test('group watch request opens the request tab for its group', () {
    expect(
      notificationDeepLinkPath({
        'type': 'request_scheduled',
        'watchRequestId': 'request-1',
        'groupId': 'group-1',
      }),
      '/groups/group-1?tab=requests&requestId=request-1',
    );
  });

  test('friend request id is not mistaken for a watch request', () {
    expect(
      notificationDeepLinkPath({
        'type': 'FRIEND_REQUEST',
        'requestId': 'friend-request-1',
        'friendId': 'friend-1',
      }),
      '/friends/friend-1',
    );
  });
}
