import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/features/profile/presentation/widgets/notification_inbox_card.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

void main() {
  test('legacy sent notification is actionable only for the pending recipient',
      () {
    FlixieNotification request(String viewer, String status) =>
        FlixieNotification(
          userId: viewer,
          type: 'FRIEND_REQUEST',
          action: 'SENT',
          message: '',
          link: {
            'request': {
              'requesterId': 'sender',
              'recipientId': 'receiver',
              'status': status,
              'requester': {'id': 'sender', 'username': 'Dougasaur'},
              'recipient': {'id': 'receiver', 'username': 'Recipient'}
            }
          },
        );
    final incoming = request('receiver', 'PENDING');
    expect(
        notificationHeadline(incoming), 'Dougasaur sent you a friend request');
    expect(notificationNeedsResponse(incoming), isTrue);
    expect(notificationNeedsResponse(request('sender', 'PENDING')), isFalse);
    expect(notificationHeadline(request('sender', 'PENDING')),
        'Friend request sent to Recipient');
    for (final status in ['ACCEPTED', 'DECLINED', 'CANCELLED']) {
      expect(notificationNeedsResponse(request('receiver', status)), isFalse);
    }
    expect(notificationNeedsResponse(incoming.copyWith(closed: true)), isFalse);
  });
  test('legacy group invitations need a response only from a pending recipient',
      () {
    FlixieNotification invite(String viewer, String status) =>
        FlixieNotification(
          userId: viewer,
          type: 'GROUP_INVITE',
          action: 'SENT',
          message: '',
          link: {
            'request': {
              'requesterId': 'sender',
              'recipientId': 'receiver',
              'status': status
            }
          },
        );
    expect(notificationNeedsResponse(invite('receiver', 'PENDING')), isTrue);
    expect(notificationNeedsResponse(invite('sender', 'PENDING')), isFalse);
    for (final status in ['ACCEPTED', 'DECLINED', 'CANCELLED']) {
      expect(notificationNeedsResponse(invite('receiver', status)), isFalse);
    }
  });
  const incoming = FlixieNotification(
      id: 'n',
      userId: 'me',
      type: FlixieNotification.friendRequest,
      action: 'RECEIVED',
      message: '',
      senderUser: {
        'username': 'A friend with a particularly long name',
        'profileBadges': ['founder']
      });
  test('read state does not resolve a pending request', () {
    expect(notificationNeedsResponse(incoming.copyWith(read: true)), isTrue);
    expect(notificationNeedsResponse(incoming.copyWith(action: 'ACCEPTED')),
        isFalse);
    expect(notificationNeedsResponse(incoming.copyWith(action: 'DECLINED')),
        isFalse);
    expect(notificationNeedsResponse(incoming.copyWith(closed: true)), isFalse);
  });
  test('resolved current plan supersedes an old invitation', () {
    const n = FlixieNotification(
        userId: 'me',
        type: 'MOVIE_WATCH_REQUEST',
        action: 'RECEIVED',
        event: 'PLAN_INVITED',
        message: '',
        link: {
          'request': {
            'id': 'p',
            'requesterId': 'friend',
            'recipientId': 'me',
            'status': 'cancelled',
          }
        });
    expect(notificationNeedsResponse(n), isFalse);
  });
  test(
      'informational lifecycle events do not become pending because of RECEIVED',
      () {
    for (final event in [
      'PLAN_CANCELLED',
      'PLAN_SCHEDULED',
      'PLAN_DUE_SOON',
      'ALL_PARTICIPANTS_LOGGED'
    ]) {
      expect(
          notificationNeedsResponse(FlixieNotification(
              userId: 'me',
              type: 'MOVIE_WATCH_REQUEST',
              action: 'RECEIVED',
              event: event,
              message: '')),
          isFalse);
    }
  });
  for (final width in [320.0, 430.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'request reflows at $width / $scale and preserves actions and badges',
          (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var accepted = false;
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
                data: MediaQueryData(
                    size: Size(width, 1100),
                    textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                    body: SingleChildScrollView(
                        child: NotificationInboxCard(
                  notification: incoming,
                  date: '20m ago',
                  onOptions: () {},
                  onAccept: () => accepted = true,
                  onDecline: () {},
                ))))));
        expect(tester.takeException(), isNull);
        expect(
            tester
                .widget<ProfileAvatarView>(find.byType(ProfileAvatarView))
                .profileBadges,
            ['founder']);
        await tester.tap(find.text('Accept'));
        expect(accepted, isTrue);
      });
    }
  }
}
