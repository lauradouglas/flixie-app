import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';

void main() {
  const events = [
    'PLAN_INVITED',
    'PLAN_ACCEPTED',
    'PLAN_DECLINED',
    'SCHEDULE_PROPOSED',
    'SCHEDULE_ACCEPTED',
    'SCHEDULE_DECLINED',
    'SCHEDULE_KEPT',
    'PLAN_SCHEDULED',
    'PLAN_RESCHEDULED',
    'LOCATION_UPDATED',
    'PLAN_CANCELLED',
    'TITLE_SELECTED',
    'ALL_PARTICIPANTS_LOGGED'
  ];
  for (final kind in [
    'message',
    'invitation',
    'group invitation',
    for (final scope in ['DIRECT', 'GROUP'])
      for (final event in events) '$scope:$event'
  ]) {
    testWidgets('$kind banner Back restores the original page and draft',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      final draft = TextEditingController();
      addTearDown(draft.dispose);
      final isPlan = kind.contains(':');
      final group = kind.startsWith('GROUP:');
      final target = isPlan
          ? group
              ? '/groups/fixture-group?tab=requests&requestId=fixture-plan'
              : '/watch-requests/fixture-plan'
          : kind == 'message'
              ? '/chat/robin'
              : '/notifications';
      final router = GoRouter(navigatorKey: key, routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(body: TextField(controller: draft))),
        GoRoute(
            path: Uri.parse(target).path,
            builder: (_, __) => Scaffold(
                  appBar: AppBar(
                      leading: const FlixieBackButton(fallbackLocation: '/')),
                  body: const Text('Notification destination'),
                )),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.enterText(find.byType(TextField), 'My unfinished review');
      await expectLater(
          PushNotificationService.initialize(
            userId: 'fixture-firebase-$kind',
            databaseUserId: 'fixture-viewer-$kind',
            navigatorKey: key,
          ),
          throwsA(isA<FirebaseException>()));
      PushNotificationService.handleForegroundMessage(RemoteMessage(
        messageId: 'fixture-banner-$kind',
        data: {
          'recipientId': 'fixture-viewer-$kind',
          'senderId': 'robin',
          if (isPlan) ...{
            'category': 'WATCH_PLAN',
            'event': kind.split(':').last,
            'scope': group ? 'GROUP' : 'DIRECT',
            if (group) 'groupId': 'fixture-group',
            'watchPlanId': 'fixture-plan',
          } else ...{
            'type': kind == 'message'
                ? 'DIRECT_MESSAGE'
                : kind == 'group invitation'
                    ? 'GROUP_INVITE'
                    : 'FRIEND_REQUEST',
            'route': target,
          },
        },
      ));
      await tester.pump();
      await tester.tap(find.text(isPlan
          ? 'View plan'
          : kind == 'message'
              ? 'View message'
              : 'View invitation'));
      await tester.pumpAndSettle();
      expect(find.text('Notification destination'), findsOneWidget);
      expect(router.canPop(), isTrue);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'My unfinished review');
      expect(find.text('Notification destination'), findsNothing);
    });
  }
}
