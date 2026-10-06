import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/auth/foreground_watch_plan_notice.dart';

void main() {
  const dm = <String, dynamic>{
    'type': 'DIRECT_MESSAGE',
    'senderId': 'robin',
    'messageId': 'message-1',
    'conversationId': 'viewer_dm_robin',
    'route': '/chat/robin',
  };
  ForegroundWatchPlanNotice? notice(Map<String, dynamic> data,
          {String? current = '/home', String? user = 'viewer'}) =>
      ForegroundWatchPlanNotice.fromPayload(data,
          currentUserId: user,
          currentUri: current == null ? null : Uri.parse(current));

  test('direct message outside its conversation offers the exact conversation',
      () {
    final result = notice(dm)!;
    expect(result.path, '/chat/robin');
    expect(result.actionLabel, 'View message');
    expect(result.icon, Icons.chat_bubble_outline);
    expect(notice(dm, current: '/chat/ellis'), isNotNull);
  });
  test('open conversation suppresses its banner including query parameters',
      () {
    expect(notice(dm, current: '/chat/robin'), isNull);
    expect(notice(dm, current: '/chat/robin?messageId=older'), isNull);
  });
  for (final type in ['FRIEND_REQUEST', 'GROUP_INVITE']) {
    test(
        '$type opens actionable invitations without accepting or entering a private group',
        () {
      final result = notice({
        'type': type,
        'requestId': 'request',
        'notificationId': 'invite',
        'senderId': 'robin',
        'route': '/groups/private-group',
        'groupId': 'private-group'
      })!;
      expect(result.path, '/notifications');
      expect(result.actionLabel, 'View invitation');
      expect(
          result.icon,
          type == 'GROUP_INVITE'
              ? Icons.group_add_outlined
              : Icons.person_add_outlined);
      expect(result.key, 'invite');
    });
  }
  test('routine and unknown notifications stay quiet', () {
    for (final type in [
      'GROUP_MESSAGE',
      'COMMUNITY_REACTION',
      'COMMUNITY_REPLY',
      'FRIEND_REQUEST_ACCEPTED',
      'REACTION',
      'LIKE',
      'MOVIE_RATING',
      'UNKNOWN'
    ]) {
      expect(notice({'type': type, 'senderId': 'robin'}), isNull, reason: type);
    }
  });
  test('individual film votes and shortlist additions stay quiet', () {
    for (final event in ['CHOICES_SAVED', 'TITLE_PROPOSED']) {
      expect(
          notice({
            'category': 'WATCH_PLAN',
            'event': event,
            'watchPlanId': 'plan',
            'actorId': 'robin'
          }),
          isNull);
    }
    expect(
        notice({
          'category': 'WATCH_PLAN',
          'event': 'TITLE_SELECTED',
          'watchPlanId': 'plan',
          'actorId': 'robin'
        }),
        isNotNull);
  });
  test('social notices suppress own, wrong-account and logged-out delivery',
      () {
    expect(notice(dm, user: 'robin'), isNull);
    expect(notice(dm, user: null), isNull);
    expect(notice({...dm, 'recipientId': 'ellis'}), isNull);
  });
  test('a direct message without a usable conversation target stays quiet', () {
    expect(notice({'type': 'DIRECT_MESSAGE', 'messageId': 'missing-target'}),
        isNull);
  });
  test('text and image messages preserve supplied notification content', () {
    for (final type in ['text', 'image']) {
      final result = ForegroundWatchPlanNotice.fromPayload(
          {...dm, 'messageType': type},
          currentUserId: 'viewer',
          title: 'Robin',
          body: type == 'image' ? 'Sent a photo' : 'Friday instead?')!;
      expect(result.title, 'Robin');
      expect(result.body, type == 'image' ? 'Sent a photo' : 'Friday instead?');
    }
  });
  testWidgets('message and invitation buttons invoke their supplied navigation',
      (tester) async {
    for (final data in [
      dm,
      {'type': 'GROUP_INVITE', 'notificationId': 'invite'}
    ]) {
      final result = notice(data)!;
      var opened = false;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: WatchPlanNoticeBanner(
                  notice: result,
                  onOpen: () => opened = true,
                  onDismiss: () {}))));
      expect(find.text('View plan'), findsNothing);
      await tester.tap(find.text(result.actionLabel));
      expect(opened, true);
    }
  });
}
