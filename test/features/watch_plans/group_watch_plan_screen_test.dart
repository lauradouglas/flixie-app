import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/features/watch_plans/presentation/pages/group_watch_plan_v2_screen.dart';
import 'package:flixie_app/models/user.dart';
import '../../../patrol_test/support/group_watch_plan_fixture.dart';
import '../../support/api_fixture.dart';
import '../../support/watchlist_auth.dart';

class Auth extends TestAuth {
  String id = GroupWatchPlanFixture.viewer;
  @override
  User get dbUser => User(
      id: id,
      username: 'Casey',
      email: '',
      iconColorId: 0,
      darkMode: true,
      completedSetup: true);
  void switchAccount() {
    id = 'other-viewer';
    notifyListeners();
  }
}

Future<void> open(WidgetTester tester, GroupWatchPlanFixture fixture,
    {double scale = 1,
    Auth? auth,
    bool embedded = false,
    String? initialId = 'patrol-plan'}) async {
  SharedPreferences.setMockInitialValues({});
  useApiFixture(fixture.client);
  final viewer = auth ?? Auth();
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
            body: GroupWatchPlanV2Screen(
                groupId: 'fixture-group',
                groupName: 'Four Film Friends',
                initialRequestId: initialId,
                embedded: embedded)))
  ]);
  addTearDown(viewer.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: viewer,
      child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'logging a watch keeps a failed save open, then refreshes and closes after retry',
      (tester) async {
    final fixture = GroupWatchPlanFixture()..schedule();
    await open(tester, fixture);
    var attempts = 0;
    final writes = <Map<String, dynamic>>[];
    useApiFixture(MockClient((request) async {
      if (request.url.path == '/conversations/group') {
        return http.Response(jsonEncode({'id': 'fixture-conversation'}), 200);
      }
      if (request.url.path ==
          '/conversations/fixture-conversation/watch-requests/patrol-plan/complete') {
        attempts++;
        if (attempts == 1) {
          return http.Response(
              jsonEncode({'message': 'Fixture save unavailable'}), 503);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        writes.add(body);
        for (final member in fixture.statuses) {
          if (member['memberId'] == GroupWatchPlanFixture.viewer) {
            member['watchedAt'] = '2026-10-08T12:00:00Z';
          }
        }
        return http.Response(jsonEncode(fixture.plan), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return fixture.handle(request);
    }));
    Future<void> tap(String label) async {
      final button = find
          .ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton))
          .first;
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    await tap('Already watched? Log your watch');
    await tap('Mark watched without rating');
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(writes, isEmpty);
    await tap('Mark watched without rating');
    expect(writes.single['userId'], GroupWatchPlanFixture.viewer);
    expect(writes.single['watched'], true);
    expect(attempts, 2);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
        find.text(
            'Your watch has been logged. Waiting for the rest of the group.'),
        findsOneWidget);
    expect(fixture.unexpected, isEmpty);
  });
  for (final size in [
    const Size(320, 640),
    const Size(430, 932),
    const Size(844, 390),
    const Size(1024, 1366)
  ]) {
    for (final stage in ['invite', 'votes', 'scheduled', 'proposal']) {
      testWidgets(
          '$stage stays usable at ${size.width} x ${size.height} with large text',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = GroupWatchPlanFixture(
            invited: stage == 'invite', multiple: stage == 'votes');
        if (stage == 'scheduled') fixture.schedule();
        if (stage == 'proposal') fixture.proposal();
        await open(tester, fixture, scale: size.width == 430 ? 1 : 2);
        for (var i = 0; i < 4; i++) {
          await tester.drag(
              find.byType(Scrollable).first, const Offset(0, -400));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(fixture.writes, isEmpty);
      });
    }
  }
  testWidgets(
      'simultaneous refresh signals read the group once and disposal removes listeners',
      (tester) async {
    final fixture = GroupWatchPlanFixture();
    await open(tester, fixture);
    final before = fixture.calls
        .where((c) => c == 'GET /groups/fixture-group/requests')
        .length;
    TabRefreshController.social.value++;
    TabRefreshController.watchPlans.value++;
    await tester.pumpAndSettle();
    expect(
        fixture.calls
            .where((c) => c == 'GET /groups/fixture-group/requests')
            .length,
        before + 1);
    await tester.pumpWidget(const SizedBox());
    final after = fixture.calls.length;
    TabRefreshController.social.value++;
    TabRefreshController.watchPlans.value++;
    await tester.pumpAndSettle();
    expect(fixture.calls.length, after);
  });
  testWidgets(
      'account change removes an open schedule sheet without sending its proposal',
      (tester) async {
    final fixture = GroupWatchPlanFixture()..schedule();
    final auth = Auth();
    await open(tester, fixture, auth: auth);
    final button = find.ancestor(
        of: find.text('Update date or time'),
        matching: find.byType(OutlinedButton));
    await tester.scrollUntilVisible(button, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    auth.switchAccount();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(fixture.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'embedded selection returns to the list without popping the parent route',
      (tester) async {
    final fixture = GroupWatchPlanFixture()..schedule();
    await open(tester, fixture, embedded: true);
    await tester.tap(find.byTooltip('Back to Watch Plans'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Active ·'), findsOneWidget);
    expect(find.byType(GroupWatchPlanV2Screen), findsOneWidget);
  });
}
