import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/presentation/pages/notification_screen.dart';
import '../test/support/api_fixture.dart';
import '../test/features/profile/notifications/journey.dart';
import '../test/features/profile/notifications/widget_test.dart'
    show dismissJourney, pagingJourney;
import 'notification_navigation_test.dart' as navigation;

void main() {
  navigation.main();
  patrolTest('notification paging and account-wide mark-all-read', ($) async {
    await pagingJourney($.tester);
  });
  patrolTest(
      'inbox refreshes once on return and ignores resume behind another page',
      ($) async {
    final auth = InboxAuth();
    addTearDown(auth.dispose);
    var reads = 0;
    useApiFixture(MockClient((request) async {
      if (request.url.path.startsWith('/notifications/user/')) {
        reads++;
        return http.Response(jsonEncode(inboxPayload(auth.id!)), 200);
      }
      return http.Response('{}', 200);
    }));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const NotificationScreen()),
      GoRoute(
          path: '/covered',
          builder: (_, __) =>
              const Scaffold(body: Text('The Odyssey details'))),
    ]);
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(
            theme: AppTheme.darkTheme, routerConfig: router)));
    Future<void> waitForPublication(int count) async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (auth.cacheOwners.length < count &&
          DateTime.now().isBefore(deadline)) {
        await $.tester.pump(const Duration(milliseconds: 100));
      }
      expect(auth.cacheOwners.length, count);
      await $.tester.pumpAndSettle();
    }

    await waitForPublication(1);
    expect(reads, 1);
    router.push('/covered');
    await $.tester.pumpAndSettle();
    await $.platform.mobile.pressHome();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    debugPrint(
        'INBOX_NATIVE background lifecycle=${WidgetsBinding.instance.lifecycleState} reads=$reads');
    await $.platform.mobile.openApp();
    await $.tester.pumpAndSettle();
    expect(reads, 1);
    router.pop();
    await $.tester.pumpAndSettle();
    await waitForPublication(2);
    expect(reads, 2);
    await $.platform.mobile.pressHome();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    debugPrint(
        'INBOX_NATIVE background lifecycle=${WidgetsBinding.instance.lifecycleState} reads=$reads');
    await $.platform.mobile.openApp();
    await $.tester.pumpAndSettle();
    await waitForPublication(3);
    debugPrint(
        'INBOX_NATIVE resumed lifecycle=${WidgetsBinding.instance.lifecycleState} reads=$reads');
    expect(reads, 3);
    expect(auth.saved!.length, 100);
    await $.tester.pumpWidget(const SizedBox());
  });
  patrolTest('inbox failed swipe restores the card and retry removes it',
      ($) async {
    await dismissJourney($.tester);
  });
}
