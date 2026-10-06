import 'dart:async';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import '../patrol_test/support/watch_plan_fixture.dart';
import '../patrol_test/support/store_screenshot_fixture.dart';
import 'support/api_fixture.dart';

void main() {
  for (final phase in ['resolving', 'loaded', 'failed', 'group']) {
    for (final pushed in [false, true]) {
      testWidgets(
          '$phase plan back ${pushed ? 'returns to chat' : 'opens Home'}',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        final api = WatchPlanFixture();
        final gate = Completer<http.Response>();
        useApiFixture(MockClient((request) async {
          if (phase == 'resolving' &&
              request.url.path == '/groups/user/store-viewer') {
            return gate.future;
          }
          if (phase == 'group') {
            if (request.url.path == '/groups/user/store-viewer') {
              return api.json([
                {
                  'id': 'fixture-group',
                  'name': 'Film friends',
                  'ownerId': 'fixture-owner'
                }
              ]);
            }
            if (request.url.path == '/groups/fixture-group/requests') {
              return api.json([
                {'id': 'patrol-plan', 'status': 'OPEN'}
              ]);
            }
          }
          if (phase == 'failed') {
            return api.json({'message': 'Unavailable'}, 400);
          }
          return api.handle(request);
        }));
        final auth = StoreScreenshotAuth();
        final router =
            GoRouter(initialLocation: pushed ? '/chat' : '/detail', routes: [
          GoRoute(
              path: '/chat',
              builder: (_, __) => const Scaffold(body: Text('Fixture chat'))),
          GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('Fixture Home'))),
          GoRoute(
              path: '/groups/:id',
              builder: (_, __) => Scaffold(
                    appBar: AppBar(leading: const FlixieBackButton()),
                    body: const Text('Resolved group plan'),
                  )),
          GoRoute(
              path: '/detail',
              builder: (_, __) =>
                  const WatchRequestDetailScreen(requestId: 'patrol-plan')),
        ]);
        addTearDown(auth.dispose);
        addTearDown(router.dispose);
        await tester.pumpWidget(storeScreenshotApp(auth, router));
        if (pushed) router.push('/detail');
        if (phase == 'resolving') {
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
        } else {
          await tester.pumpAndSettle();
        }
        if (phase == 'group') {
          expect(find.text('Resolved group plan'), findsOneWidget);
        }
        expect(find.byType(FlixieBackButton), findsOneWidget);
        await tester.tap(find.byType(FlixieBackButton));
        await tester.pumpAndSettle();
        expect(find.text(pushed ? 'Fixture chat' : 'Fixture Home'),
            findsOneWidget);
        if (phase == 'resolving') {
          gate.complete(api.json([]));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
