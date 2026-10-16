import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/profile/presentation/pages/notification_screen.dart';
import 'package:flixie_app/features/settings/presentation/widgets/availability_alert_setting.dart';
import '../test/support/api_fixture.dart';
import 'support/store_screenshot_fixture.dart';

void main() {
  for (final type in ['movie', 'tv']) {
    patrolTest('$type availability alert opens its title and returns to inbox',
        ($) async {
      final path = type == 'movie' ? 'movies' : 'shows';
      final notice = {
        'id': 'fixture-availability-$type',
        'userId': 'store-viewer',
        'type': 'AVAILABILITY_ALERT',
        'action': 'RECEIVED',
        'read': false,
        'closed': false,
        'message': 'Fictional availability update',
        'notificationReceived': '2026-10-14T09:00:00Z',
        'data': {
          'mediaType': type,
          'mediaTitle': 'Alien',
          'providerNames': 'Netflix',
          'country': 'GB',
          'route': '/$path/348?source=notification'
        }
      };
      useApiFixture(MockClient((request) async => http.Response(
          jsonEncode(request.url.path.startsWith('/notifications/user/')
              ? {
                  'items': [notice],
                  'nextCursor': null,
                  'unreadCount': 1
                }
              : {}),
          200,
          headers: {'content-type': 'application/json'})));
      final auth = StoreScreenshotAuth();
      final router = GoRouter(initialLocation: '/notifications', routes: [
        GoRoute(
            path: '/', builder: (_, __) => const Scaffold(body: Text('Home'))),
        GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationScreen()),
        GoRoute(
            path: '/$path/:id',
            builder: (_, state) => Scaffold(
                appBar: AppBar(title: const Text('Fixture title')),
                body: Text(
                    '${state.uri.path} · ${state.uri.queryParameters['source']}'))),
      ]);
      addTearDown(auth.dispose);
      addTearDown(router.dispose);
      await $.pumpWidgetAndSettle(storeScreenshotApp(auth, router));
      await $(find.text('View title →')).tap();
      await $(find.text('/$path/348 · notification')).waitUntilVisible();
      await $(find.byTooltip('Back')).tap();
      await $(find.text('Notifications')).waitUntilVisible();
    });
  }
  patrolTest(
      'availability alerts require explicit opt-in and save selected state',
      ($) async {
    var enabled = false;
    useApiFixture(MockClient((request) async {
      if (request.url.path != '/availability-alerts') {
        return http.Response('{}', 404);
      }
      if (request.method == 'POST') {
        enabled = (jsonDecode(request.body) as Map)['enabled'] == true;
      }
      return http.Response(
          jsonEncode({
            'enabled': enabled,
            'countryName': 'United Kingdom',
            'services': [
              {'id': 8, 'providerName': 'Netflix'}
            ]
          }),
          200,
          headers: {'content-type': 'application/json'});
    }));
    final auth = StoreScreenshotAuth();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
              body: SingleChildScrollView(
                  child: AvailabilityAlertSetting(
                      userId: 'store-viewer', showPushChoice: false))))
    ]);
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    ApiClient.setToken('fictional-test-token');
    addTearDown(() => ApiClient.setToken(null));
    await $.pumpWidgetAndSettle(storeScreenshotApp(auth, router));
    expect(enabled, isFalse);
    await $(find.byType(Switch)).tap();
    await $.pumpAndSettle();
    expect(enabled, isTrue);
    await $(find.byType(Switch)).tap();
    await $.pumpAndSettle();
    expect(enabled, isFalse);
  });
}
