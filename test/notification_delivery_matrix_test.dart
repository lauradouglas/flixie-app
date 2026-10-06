import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/auth/foreground_notification_dispatcher.dart';
import 'package:flixie_app/core/auth/foreground_watch_plan_notice.dart';

void main() {
  var planRefreshes = 0;
  var socialRefreshes = 0;
  final banners = <ForegroundWatchPlanNotice>[];
  void deliver(Map<String, dynamic> data,
      {String? user = 'casey', String? location = '/home'}) {
    dispatchForegroundNotification(
      RemoteMessage(
          data: data,
          messageId: 'delivery',
          notification:
              const RemoteNotification(title: 'Robin', body: 'Updated')),
      currentUserId: user,
      currentUri: location == null ? null : Uri.parse(location),
      refreshWatchPlans: () => planRefreshes++,
      refreshSocial: () => socialRefreshes++,
      showBanner: banners.add,
    );
  }

  setUp(() {
    planRefreshes = 0;
    socialRefreshes = 0;
    banners.clear();
  });
  // Explicit product expectations: invitations and DMs interrupt; routine
  // activity stays quiet. Legacy watch requests require WATCH_PLAN metadata.
  const types = {
    'MOVIE_WATCH_REQUEST': false,
    'SHOW_WATCH_REQUEST': false,
    'GROUP_REQUEST': false,
    'FRIEND_REQUEST': true,
    'GROUP_INVITE': true,
    'LIST_SHARED': false,
    'REFERRAL_JOINED': false,
    'COMMUNITY_REPLY': false,
    'COMMUNITY_REACTION': false,
    'DIRECT_MESSAGE': true,
    'GROUP_MESSAGE': false,
    'FRIEND_REQUEST_ACCEPTED': false,
    'UNKNOWN': false,
  };
  for (final entry in types.entries) {
    test('${entry.key} refreshes data with expected banner policy', () {
      deliver({
        'type': entry.key,
        'senderId': 'robin',
        'recipientId': 'casey',
        'route': '/chat/robin',
        'notificationId': 'notification'
      });
      expect(socialRefreshes, 1);
      expect(planRefreshes, 0);
      expect(banners.length, entry.value ? 1 : 0);
      if (entry.value) {
        expect(banners.single.title, 'Robin');
        expect(banners.single.body, 'Updated');
        expect(banners.single.path,
            entry.key == 'DIRECT_MESSAGE' ? '/chat/robin' : '/notifications');
      }
    });
  }
  const events = {
    'PLAN_INVITED': true,
    'PLAN_ACCEPTED': true,
    'PLAN_DECLINED': true,
    'SCHEDULE_PROPOSED': true,
    'SCHEDULE_ACCEPTED': true,
    'SCHEDULE_DECLINED': true,
    'SCHEDULE_KEPT': true,
    'PLAN_SCHEDULED': true,
    'PLAN_RESCHEDULED': true,
    'LOCATION_UPDATED': true,
    'PLAN_CANCELLED': true,
    'TITLE_PROPOSED': false,
    'TITLE_SELECTED': true,
    'CHOICES_SAVED': false,
    'ALL_PARTICIPANTS_LOGGED': true,
  };
  for (final scope in ['DIRECT', 'GROUP']) {
    for (final entry in events.entries) {
      test('$scope ${entry.key} refreshes the plan and follows banner policy',
          () {
        deliver({
          'category': 'WATCH_PLAN',
          'scope': scope,
          'event': entry.key,
          'watchPlanId': 'plan',
          'requestId': 'plan',
          'groupId': 'group',
          'actorId': 'robin'
        });
        expect(planRefreshes, 1);
        expect(socialRefreshes, 0);
        expect(banners.length, entry.value ? 1 : 0);
      });
    }
  }
  for (final data in [
    {'recipientId': 'ellis'},
    {'actorId': 'casey'},
    {'senderId': 'casey'},
  ]) {
    test('foreign or own event does not refresh or display: $data', () {
      deliver({'type': 'FRIEND_REQUEST', ...data});
      expect(banners, isEmpty);
      expect(socialRefreshes + planRefreshes, 0);
    });
  }
  test('logged-out delivery causes no refresh or banner', () {
    deliver({'type': 'FRIEND_REQUEST'}, user: null);
    expect(banners, isEmpty);
    expect(socialRefreshes + planRefreshes, 0);
  });
  test('open DM refreshes social data without interrupting the conversation',
      () {
    deliver(
        {'type': 'DIRECT_MESSAGE', 'senderId': 'robin', 'route': '/chat/robin'},
        location: '/chat/robin?message=old');
    expect(socialRefreshes, 1);
    expect(banners, isEmpty);
  });
  test(
      'missing navigator still refreshes; banner delivery can safely be dropped',
      () {
    deliver({'type': 'COMMUNITY_REPLY'}, location: null);
    expect(socialRefreshes, 1);
    expect(banners, isEmpty);
  });
}
