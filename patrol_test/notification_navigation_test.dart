import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/features/profile/presentation/pages/notification_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/notification_inbox_card.dart';
import 'package:flixie_app/features/social/presentation/pages/group_invitation_detail_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/community_post_screen.dart';
import '../test/support/api_fixture.dart';
import 'support/store_screenshot_fixture.dart';

void main() {
  for (final coldStart in [false, true]) {
    patrolTest(
        coldStart
            ? 'cold notification destination offers Home after app resume'
            : 'in-app banner and inbox invitation preserve the original draft after resume',
        ($) async {
      // Fixture accounts and responses only; no Firebase login or remote push.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      final invite = {
        'id': 'fixture-invite-notification',
        'userId': 'store-viewer',
        'type': 'GROUP_INVITE',
        'action': 'RECEIVED',
        'read': false,
        'message': 'Movie night invitation',
        'relatedId': 'fixture-invite',
        'notificationReceived': '2026-10-05T12:00:00Z',
        'senderUser': {'id': 'robin', 'username': 'Robin', 'profileBadges': []},
        'data': {'groupId': 'fixture-group'},
      };
      useApiFixture(MockClient((request) async => http.Response(
            jsonEncode(request.url.path.startsWith('/notifications/user/')
                ? [invite]
                : request.url.path == '/notifications/update'
                    ? invite
                    : {'message': 'Fixture unavailable'}),
            request.url.path.startsWith('/notifications/') ? 200 : 400,
            headers: {'content-type': 'application/json'},
          )));
      final auth = StoreScreenshotAuth();
      final draft = TextEditingController();
      final key = GlobalKey<NavigatorState>();
      final router =
          GoRouter(navigatorKey: key, initialLocation: '/origin', routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('Home destination'))),
        GoRoute(
            path: '/origin',
            builder: (_, __) => Scaffold(body: TextField(controller: draft))),
        GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationScreen()),
        GoRoute(
            path: '/group-invites/:id',
            builder: (_, __) => const GroupInvitationDetailScreen(
                groupId: 'fixture-group', requestId: 'fixture-invite')),
        GoRoute(
            path: '/community/posts/:owner/:type/:id',
            builder: (_, __) => const CommunityPostScreen(
                ownerId: 'robin',
                type: 'movie-review',
                postId: 'fixture-post')),
      ]);
      addTearDown(auth.dispose);
      addTearDown(draft.dispose);
      addTearDown(router.dispose);
      await $.pumpWidgetAndSettle(storeScreenshotApp(auth, router));
      await $(find.byType(TextField)).enterText('Keep this original draft');
      await expectLater(
          PushNotificationService.initialize(
              userId: 'fixture-patrol-$coldStart',
              databaseUserId: 'store-viewer',
              navigatorKey: key),
          throwsA(isA<FirebaseException>()));
      PushNotificationService.attachRouter(router);
      if (coldStart) {
        PushNotificationService.handleNotificationTap({
          'type': 'COMMUNITY_REACTION',
          'communityRoute': '/community/posts/robin/movie-review/fixture-post'
        }, coldStart: true);
        await $(find.byTooltip('Home')).waitUntilVisible();
      } else {
        PushNotificationService.handleForegroundMessage(const RemoteMessage(
            messageId: 'fixture-patrol-invite',
            data: {
              'type': 'GROUP_INVITE',
              'senderId': 'robin',
              'recipientId': 'store-viewer'
            }));
        await $('View invitation').tap();
        await $(find.byType(NotificationInboxCard)).waitUntilVisible();
        final card = find.byType(NotificationInboxCard);
        final onOpen = $.tester.widget<NotificationInboxCard>(card).onOpen;
        await $(find
                .descendant(
                    of: card,
                    matching: find.byWidgetPredicate(
                        (w) => w is InkWell && w.onTap == onOpen))
                .first)
            .tap();
        await $('Group invitation').waitUntilVisible();
      }
      await $.platform.mobile.pressHome();
      await $.platform.mobile.openApp();
      await $(find.byTooltip(coldStart ? 'Home' : 'Back')).tap();
      if (coldStart) {
        await $('Home destination').waitUntilVisible();
      } else {
        await $(find.byType(NotificationScreen)).waitUntilVisible();
        await $(find.byTooltip('Back')).tap();
        await $(find.byType(TextField)).waitUntilVisible();
        expect(draft.text, 'Keep this original draft');
      }
      expect($.tester.takeException(), isNull);
    });
  }
}
