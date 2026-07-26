import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/models/notification.dart';

void main() {
  test('referral notification exposes sender and profile route', () {
    final notification = FlixieNotification.fromJson({
      'id': 'notification-1',
      'userId': 'inviter-1',
      'type': 'REFERRAL_JOINED',
      'action': 'RECEIVED',
      'message': 'joined Flixie using your referral. You’re now friends!',
      'data': {
        'sender': {
          'id': 'referred-1',
          'username': 'new_friend',
          'firstName': 'New',
        },
        'route': '/friends/referred-1',
      },
    });

    expect(notification.isRequest, isFalse);
    expect(notification.senderName, 'new_friend');
    expect(notification.route, '/friends/referred-1');
  });
}
