import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/models/notification.dart';

void main() {
  testWidgets(
      'Firebase UID registers tokens while database ID receives the banner',
      (tester) async {
    final key = GlobalKey<NavigatorState>();
    final router = GoRouter(
        navigatorKey: key,
        routes: [GoRoute(path: '/', builder: (_, state) => const Scaffold())]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    // Firebase transport is intentionally unavailable in this widget test.
    // Account setup must still use the database identity before transport setup.
    await expectLater(
        PushNotificationService.initialize(
            userId: 'firebase-auth-uid',
            databaseUserId: 'flixie-database-id',
            navigatorKey: key),
        throwsA(isA<FirebaseException>()));
    PushNotificationService.observeInbox('flixie-database-id', []);
    final inboxItem = FlixieNotification.fromJson({
      'id': 'friend-invitation',
      'userId': 'flixie-database-id',
      'type': 'FRIEND_REQUEST',
      'action': 'RECEIVED',
      'title': 'New friend request',
      'message': 'Robin sent you a friend request',
      'data': {
        'recipientId': 'flixie-database-id',
        'notificationId': 'friend-invitation'
      },
    });
    PushNotificationService.observeInbox('flixie-database-id', [inboxItem]);
    await tester.pump();
    expect(find.text('Robin sent you a friend request'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss update'));
    await tester.pump();
    // A delayed remote push for the same item must not reopen a dismissed banner.
    PushNotificationService.handleForegroundMessage(const RemoteMessage(
        messageId: 'late-firebase-message',
        data: {
          'type': 'FRIEND_REQUEST',
          'recipientId': 'flixie-database-id',
          'notificationId': 'friend-invitation'
        },
        notification: RemoteNotification(
            title: 'New friend request',
            body: 'Robin sent you a friend request')));
    await tester.pump();
    expect(find.text('Robin sent you a friend request'), findsNothing);
    PushNotificationService.handleForegroundMessage(const RemoteMessage(
        messageId: 'wrong-account',
        data: {'type': 'FRIEND_REQUEST', 'recipientId': 'someone-else'},
        notification: RemoteNotification(title: 'Wrong account')));
    await tester.pump();
    expect(find.text('Wrong account'), findsNothing);
    await tester.pump(const Duration(seconds: 9));
  });
}
