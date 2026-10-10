import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import 'package:flixie_app/features/social/presentation/widgets/social_account_sheet.dart';
import '../../../../patrol_test/support/watch_plan_fixture.dart';
import '../../../../patrol_test/support/store_screenshot_fixture.dart';
import '../../../support/api_fixture.dart';
import 'watch_requests_controller_test.dart' show PlansAuth;

Future<GoRouter> mount(WidgetTester tester, PlansAuth auth,
    {bool focused = false, bool resolver = false}) async {
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) => resolver
            ? const WatchRequestDetailScreen(requestId: 'patrol-plan')
            : WatchRequestsScreen(
                initialRequestId: focused ? 'patrol-plan' : null)),
    GoRoute(
        path: '/groups/:id',
        builder: (_, __) => const Scaffold(body: Text('Group destination'))),
  ]);
  addTearDown(router.dispose);
  addTearDown(auth.dispose);
  await tester.pumpWidget(storeScreenshotApp(auth, router));
  await tester.pumpAndSettle();
  return router;
}

Future<void> tapButton(WidgetTester tester, String text) async {
  final button = find
      .ancestor(
          of: find.text(text),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton))
      .first;
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'paired refresh listeners coalesce; Past and Active filtering add no reads',
      (tester) async {
    final api = WatchPlanFixture();
    useApiFixture(api.client);
    final auth = PlansAuth();
    await mount(tester, auth);
    expect(api.calls.where((c) => c == 'GET /requests/store-viewer/all'),
        hasLength(1));
    final original = api.calls.length;
    await tester.tap(find.textContaining('Past ·'));
    await tester.pumpAndSettle();
    expect(find.text('No Watch Plans match'), findsOneWidget);
    await tester.tap(find.textContaining('Active ·'));
    await tester.pumpAndSettle();
    expect(api.calls.length, original);
    TabRefreshController.social.value++;
    TabRefreshController.watchPlans.value++;
    await tester.pumpAndSettle();
    expect(api.calls.where((c) => c == 'GET /requests/store-viewer/all'),
        hasLength(2));
    expect(api.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox());
    final disposedReads = api.calls.length;
    TabRefreshController.social.value++;
    TabRefreshController.watchPlans.value++;
    await tester.pumpAndSettle();
    expect(api.calls.length, disposedReads);
  });
  testWidgets('account switch closes an open schedule sheet without a write',
      (tester) async {
    final api = WatchPlanFixture(status: 'ACCEPTED');
    useApiFixture(MockClient((request) async {
      if (request.url.queryParameters['userId'] == 'other') {
        return api.json({'message': 'Denied'}, 403);
      }
      if (request.url.path == '/requests/other/all') return api.json([]);
      return api.handle(request);
    }));
    final auth = PlansAuth();
    await mount(tester, auth, focused: true);
    await tapButton(tester, 'Suggest a date');
    expect(find.text('Plan date'), findsOneWidget);
    expect(find.byType(SocialAccountSheet), findsOneWidget);
    auth.switchViewer('other');
    await tester.pumpAndSettle();
    expect(find.text('Plan date'), findsNothing);
    expect(api.writes, isEmpty);
    expect(auth.plans, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'two invite taps send one write; a late reply cannot populate another account',
      (tester) async {
    final api = WatchPlanFixture();
    final gate = Completer<void>();
    var writes = 0;
    useApiFixture(MockClient((request) async {
      if (request.url.path == '/requests/update') {
        writes++;
        await gate.future;
      }
      if (request.url.queryParameters['userId'] == 'other') {
        return api.json({'message': 'Denied'}, 403);
      }
      if (request.url.path == '/requests/other/all') return api.json([]);
      return api.handle(request);
    }));
    final auth = PlansAuth();
    await mount(tester, auth, focused: true);
    final button = find
        .ancestor(
            of: find.text('I’m in'),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton))
        .first;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(writes, 1);
    auth.switchViewer('other');
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(auth.plans, isEmpty);
    expect(find.text('Watch Plan accepted.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'notification lookup from an old account cannot redirect the new account',
      (tester) async {
    final api = WatchPlanFixture();
    final gate = Completer<http.Response>();
    var groupReads = 0;
    useApiFixture(MockClient((request) async {
      if (request.url.path == '/groups/user/store-viewer') return gate.future;
      if (request.url.path == '/groups/user/other') return api.json([]);
      if (request.url.path == '/requests/other/all') return api.json([]);
      if (request.url.queryParameters['userId'] == 'other') {
        return api.json({'message': 'Denied'}, 403);
      }
      if (request.url.path == '/groups/old-group/requests') {
        groupReads++;
        return api.json([api.plan]);
      }
      return api.handle(request);
    }));
    final auth = PlansAuth();
    final router = await mount(tester, auth, resolver: true);
    auth.switchViewer('other');
    await tester.pumpAndSettle();
    gate.complete(api.json([
      {'id': 'old-group', 'name': 'Old group', 'ownerId': 'store-viewer'}
    ]));
    await tester.pumpAndSettle();
    expect(groupReads, 0);
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.text('Group destination'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 740),
    const Size(844, 390),
    const Size(768, 1024)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('list and Past filter fit $size at text scale $scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final api = WatchPlanFixture();
        useApiFixture(api.client);
        await mount(tester, PlansAuth());
        expect(find.text('Needs your response'), findsOneWidget);
        await tester.tap(find.textContaining('Past ·'));
        await tester.pumpAndSettle();
        expect(find.text('No Watch Plans match'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(api.unexpected, isEmpty);
      });
    }
  }
}
