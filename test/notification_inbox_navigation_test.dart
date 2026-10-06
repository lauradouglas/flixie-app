import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/utils/notification_destination.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/features/profile/presentation/pages/notification_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/notification_inbox_card.dart';
import '../patrol_test/support/store_screenshot_fixture.dart';
import 'support/api_fixture.dart';
import 'notification_navigation_matrix_test.dart' show navigationCases;

void main() {
  for (final entry in navigationCases.entries) {
    testWidgets(
        '${entry.key} inbox card returns through inbox to original draft',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final payload = {
        'id': 'fixture-notification',
        'userId': 'store-viewer',
        'type': entry.value['type'] ?? 'RECOMMENDATION',
        'action': 'RECEIVED',
        'read': false,
        'message': 'Fixture update',
        'notificationReceived': '2026-10-05T12:00:00Z',
        'relatedId': entry.key == 'group invitation' ? 'fixture-invite' : null,
        'senderUser': {'id': 'robin', 'username': 'Robin', 'profileBadges': []},
        'data': {
          ...entry.value,
          if (entry.key == 'group invitation') 'groupId': 'group'
        },
      };
      final notification = FlixieNotification.fromJson(payload);
      final destination = notificationDestination(notification);
      useApiFixture(MockClient((request) async => http.Response(
          jsonEncode(request.url.path.startsWith('/notifications/user/')
              ? [payload]
              : payload),
          200,
          headers: {'content-type': 'application/json'})));
      final auth = StoreScreenshotAuth();
      final draft = TextEditingController();
      final router = GoRouter(initialLocation: '/origin', routes: [
        GoRoute(
            path: '/', builder: (_, __) => const Scaffold(body: Text('Home'))),
        GoRoute(
            path: '/origin',
            builder: (_, __) => Scaffold(body: TextField(controller: draft))),
        GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationScreen()),
        if (destination != '/notifications')
          GoRoute(
              path: Uri.parse(destination).path,
              builder: (_, __) => Scaffold(
                  appBar: AppBar(leading: const FlixieBackButton()),
                  body: Text('Opened $destination'))),
      ]);
      addTearDown(auth.dispose);
      addTearDown(draft.dispose);
      addTearDown(router.dispose);
      await tester.pumpWidget(storeScreenshotApp(auth, router));
      await tester.enterText(find.byType(TextField), 'My original draft');
      router.push('/notifications');
      await tester.pumpAndSettle();
      final card = find.byType(NotificationInboxCard);
      expect(card, findsOneWidget);
      final onOpen = tester.widget<NotificationInboxCard>(card).onOpen;
      if (destination == '/notifications') {
        expect(onOpen, isNull); // An unroutable update stays in the inbox.
      } else {
        expect(onOpen, isNotNull);
        await tester.tap(find
            .descendant(
                of: card,
                matching: find.byWidgetPredicate(
                    (w) => w is InkWell && w.onTap == onOpen))
            .first);
        await tester.pumpAndSettle();
        expect(find.text('Opened $destination'), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.byType(NotificationScreen), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(draft.text, 'My original draft');
      expect(tester.takeException(), isNull);
    });
  }
}
