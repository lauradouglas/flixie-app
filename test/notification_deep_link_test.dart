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

  test('group message route without chat tab is normalized to chat destination',
      () {
    expect(
      notificationDeepLinkPath({
        'type': 'GROUP_MESSAGE',
        'route': '/groups/group-2',
      }),
      '/groups/group-2?tab=chat',
    );
  });

  test('direct message opens the sender chat', () {
    expect(
      notificationDeepLinkPath({
        'type': 'DIRECT_MESSAGE',
        'senderId': 'friend-1',
        'conversationId': 'conversation-1',
      }),
      '/chat/friend-1',
    );
  });

  test('lowercase direct message payload opens its explicit chat route', () {
    expect(
      notificationDeepLinkPath({
        'type': 'direct_message',
        'route': '/chat/friend-2',
      }),
      '/chat/friend-2',
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

  test('saved group movie choices open the focused Watch Plan', () {
    expect(
      notificationDeepLinkPath({
        'category': 'WATCH_PLAN',
        'event': 'CHOICES_SAVED',
        'groupId': 'group-123',
        'watchPlanId': 'plan-456',
      }),
      '/groups/group-123?tab=requests&requestId=plan-456',
    );
  });

  test('group Watch Plan route still opens when groupId is absent from data',
      () {
    expect(
      notificationDeepLinkPath({
        'category': 'WATCH_PLAN',
        'watchPlanId': 'plan-456',
        'route': '/groups/group-123?tab=requests&requestId=plan-456',
      }),
      '/groups/group-123?tab=requests&requestId=plan-456',
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

  test('content route opened from a notification carries its source', () {
    expect(
      notificationDeepLinkPath({
        'type': 'MOVIE_SHARED',
        'route': '/movies/42',
      }),
      '/movies/42?source=notification',
    );
  });
}
