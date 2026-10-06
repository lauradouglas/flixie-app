import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/features/social/presentation/pages/group_invitation_detail_screen.dart';
import '../patrol_test/support/store_screenshot_fixture.dart';
import 'support/api_fixture.dart';

void main() {
  testWidgets('old invitation opens an already joined group without responding',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <String>[];
    useApiFixture(MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.url.path.startsWith('/groups/user/')) {
        return http.Response(
            jsonEncode([
              {'id': 'fixture-group', 'name': 'Movie night', 'ownerId': 'robin'}
            ]),
            200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    }));
    final auth = StoreScreenshotAuth();
    final router = GoRouter(initialLocation: '/invite', routes: [
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: Text('Home'))),
      GoRoute(
          path: '/invite',
          builder: (_, __) => const GroupInvitationDetailScreen(
              groupId: 'fixture-group', requestId: 'old-invite')),
      GoRoute(
          path: '/groups/:id',
          builder: (_, __) => const Scaffold(body: Text('Joined group'))),
    ]);
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(storeScreenshotApp(auth, router));
    await tester.pumpAndSettle();
    expect(find.text('Joined group'), findsOneWidget);
    expect(find.text('Accept invitation'), findsNothing);
    expect(find.text('Decline invitation'), findsNothing);
    expect(requests, hasLength(1));
    expect(requests.single, startsWith('GET /groups/user/'));
    expect(tester.takeException(), isNull);
  });
  for (final accepted in [true, false]) {
    for (final pushed in [true, false]) {
      testWidgets(
          '${accepted ? 'accept' : 'decline'} invitation retains ${pushed ? 'origin draft' : 'Home exit'}',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        final updates = <Map<String, dynamic>>[];
        useApiFixture(MockClient((request) async {
          if (request.url.path.startsWith('/groups/user/')) {
            return http.Response('[]', 200,
                headers: {'content-type': 'application/json'});
          }
          if (request.method == 'POST') {
            updates.add(jsonDecode(request.body) as Map<String, dynamic>);
          }
          return http.Response(
              jsonEncode(request.method == 'GET'
                  ? {
                      'id': 'fixture-group',
                      'name': 'Movie night',
                      'ownerId': 'robin'
                    }
                  : {}),
              200,
              headers: {'content-type': 'application/json'});
        }));
        final auth = StoreScreenshotAuth();
        final draft = TextEditingController();
        final router =
            GoRouter(initialLocation: pushed ? '/origin' : '/invite', routes: [
          GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('Home'))),
          GoRoute(
              path: '/origin',
              builder: (_, __) => Scaffold(body: TextField(controller: draft))),
          GoRoute(
              path: '/invite',
              builder: (_, __) => const GroupInvitationDetailScreen(
                  groupId: 'fixture-group', requestId: 'fixture-invite')),
          GoRoute(
              path: '/groups/:id',
              builder: (_, __) => Scaffold(
                  appBar: AppBar(leading: const FlixieBackButton()),
                  body: const Text('Joined group'))),
        ]);
        addTearDown(auth.dispose);
        addTearDown(draft.dispose);
        addTearDown(router.dispose);
        await tester.pumpWidget(storeScreenshotApp(auth, router));
        if (pushed) {
          await tester.enterText(find.byType(TextField), 'Original draft');
          router.push('/invite');
        }
        await tester.pumpAndSettle();
        await tester.tap(
            find.text(accepted ? 'Accept invitation' : 'Decline invitation'));
        await tester.pumpAndSettle();
        expect(updates.single['status'], accepted ? 'ACCEPTED' : 'DECLINED');
        if (accepted) {
          expect(find.text('Joined group'), findsOneWidget);
          expect(router.canPop(), pushed);
          await tester.tap(find.byTooltip(pushed ? 'Back' : 'Home'));
          await tester.pumpAndSettle();
        }
        if (pushed) {
          expect(find.byType(TextField), findsOneWidget);
          expect(draft.text, 'Original draft');
        } else {
          expect(find.text('Home'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
