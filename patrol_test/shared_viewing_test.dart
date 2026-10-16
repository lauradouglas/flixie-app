import 'package:http/testing.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import '../test/support/api_fixture.dart';
import 'support/store_screenshot_fixture.dart';
import 'support/watch_plan_fixture.dart';

void main() {
  patrolTest(
      'third participant opens one shared viewing and logs their own watch',
      ($) async {
    final api = WatchPlanFixture(status: 'ACCEPTED');
    api.plan.addAll({
      'lightweight': true,
      'groupId': null,
      'recipientId': 'fixture-ellis',
      'recipient': {'id': 'fixture-ellis', 'username': 'Ellis'},
      'participants': [
        {
          'userId': 'fixture-robin',
          'user': {
            'id': 'fixture-robin',
            'username': 'Robin',
            'profileBadges': [
              {'badge': 'EARLY_ADOPTER'}
            ]
          }
        },
        {
          'userId': 'fixture-ellis',
          'user': {'id': 'fixture-ellis', 'username': 'Ellis'}
        },
        {'userId': 'store-viewer', 'user': screenshotPerson},
      ],
      'watchConfirmations': [
        {
          'id': 'robin-watch',
          'userId': 'fixture-robin',
          'watched': true,
          'rating': 8,
          'watchEntry': {'watchedAt': null}
        }
      ],
    });
    useApiFixture(MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/watch-confirmations')) {
        final before = List<Map<String, dynamic>>.from(
            api.plan['watchConfirmations'] as List);
        await api.handle(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        api.plan['watchConfirmations'] = [
          ...before,
          {...body, 'id': 'viewer-watch', 'watchEntryId': 'fixture-watch'}
        ];
        api.plan['status'] = 'ACCEPTED';
        api.plan['watchedStatus'] = 'PARTIAL';
        return api.json(api.state);
      }
      return api.handle(request);
    }));
    final auth = StoreScreenshotAuth();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) =>
              const WatchRequestsScreen(initialRequestId: 'patrol-plan')),
    ]);
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    addTearDown(() => expect(api.unexpected, isEmpty));
    await $.pumpWidgetAndSettle(storeScreenshotApp(auth, router));
    await $('Of 3 people').waitUntilVisible();
    await $('Ellis').waitUntilVisible();
    await $('Log your watch').tap();
    await $('Save watch').waitUntilVisible();
    expect(find.text('Robin'), findsWidgets);
    expect(find.text('Ellis'), findsWidgets);
    await $('Save watch').tap();
    await $('2 watched').waitUntilVisible();
    expect(api.diary, hasLength(1));
    expect(api.writes.single['userId'], 'store-viewer');
    expect(
        api.calls.where(
            (c) => c == 'POST /watch-requests/patrol-plan/watch-confirmations'),
        hasLength(1));
    expect(api.calls.any((c) => c.startsWith('POST /groups')), isFalse);
  });
}
