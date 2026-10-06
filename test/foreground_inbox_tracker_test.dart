import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/auth/foreground_inbox_tracker.dart';
import 'package:flixie_app/core/auth/foreground_watch_plan_notice.dart';
import 'package:flixie_app/models/notification.dart';

FlixieNotification item(String id,
        {String user = 'recipient',
        String type = 'FRIEND_REQUEST',
        bool read = false,
        bool closed = false,
        String action = 'RECEIVED'}) =>
    FlixieNotification(
        id: id,
        userId: user,
        type: type,
        title: 'New friend request',
        action: action,
        message: 'Robin sent you a friend request',
        read: read,
        closed: closed,
        data: const {'friendId': 'robin', 'route': '/friends/robin'});

void main() {
  test('initial unread items stay quiet; new item delivers full content once',
      () {
    final tracker = ForegroundInboxTracker();
    expect(tracker.observe('recipient', [item('existing')]), isEmpty);
    final incoming =
        tracker.observe('recipient', [item('new'), item('existing')]);
    expect(incoming, hasLength(1));
    expect(incoming.single.notification?.title, 'New friend request');
    expect(
        incoming.single.notification?.body, 'Robin sent you a friend request');
    expect(incoming.single.data['recipientId'], 'recipient');
    expect(
        tracker.observe('recipient', [item('new'), item('existing')]), isEmpty);
  });
  test('read, closed, resolved and foreign items never generate a banner', () {
    final tracker = ForegroundInboxTracker()..observe('recipient', []);
    expect(
        tracker.observe('recipient', [
          item('read', read: true),
          item('closed', closed: true),
          item('foreign', user: 'other'),
          item('accepted', action: 'ACCEPTED')
        ]),
        isEmpty);
  });
  test(
      'resume records unseen items silently; new foreground event still announces',
      () {
    final tracker = ForegroundInboxTracker()..observe('recipient', []);
    expect(tracker.observe('recipient', [item('background')], announce: false),
        isEmpty);
    expect(tracker.observe('recipient', [item('background')]), isEmpty);
    expect(tracker.observe('recipient', [item('fresh'), item('background')]),
        hasLength(1));
  });
  test('account switch and logout reset seed a new quiet baseline', () {
    final tracker = ForegroundInboxTracker()..observe('recipient', []);
    expect(tracker.observe('other', [item('other-event', user: 'other')]),
        isEmpty);
    tracker.reset();
    expect(tracker.observe('recipient', [item('old')]), isEmpty);
  });
  test('quiet community replies use the same banner policy and never interrupt',
      () {
    final tracker = ForegroundInboxTracker()..observe('recipient', []);
    final messages =
        tracker.observe('recipient', [item('reply', type: 'COMMUNITY_REPLY')]);
    expect(messages, hasLength(1));
    expect(
        ForegroundWatchPlanNotice.fromPayload(messages.single.data,
            currentUserId: 'recipient'),
        isNull);
  });
  test('inbox and remote delivery share the notification ID for deduplication',
      () {
    final data = {
      'type': 'FRIEND_REQUEST',
      'notificationId': 'notification',
      'recipientId': 'recipient'
    };
    final remote = ForegroundWatchPlanNotice.fromPayload(data,
        currentUserId: 'recipient', messageId: 'firebase-message')!;
    final inbox = ForegroundWatchPlanNotice.fromPayload(data,
        currentUserId: 'recipient', messageId: 'notification')!;
    expect(remote.key, inbox.key);
  });
  test('API title survives read-state copies and serialization', () {
    final n = FlixieNotification.fromJson({
      'id': 'n',
      'userId': 'recipient',
      'type': 'FRIEND_REQUEST',
      'title': 'New invitation',
      'message': 'Robin invited you'
    });
    expect(n.copyWith(read: true).title, 'New invitation');
    expect(n.toJson()['title'], 'New invitation');
  });
}
