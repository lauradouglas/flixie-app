import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import 'package:flixie_app/features/watch_plans/presentation/pages/group_watch_plan_v2_screen.dart';
import '../patrol_test/support/watch_plan_fixture.dart';
import '../patrol_test/support/group_watch_plan_fixture.dart';
import '../patrol_test/support/store_screenshot_fixture.dart';
import 'support/api_fixture.dart';

void main() {
  for (final group in [false, true]) {
    testWidgets(
        '${group ? 'group' : 'friend'} refresh ignores an older response arriving after the newest',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final WatchPlanFixture api = group
          ? GroupWatchPlanFixture()
          : WatchPlanFixture(status: 'ACCEPTED');
      final path = group
          ? '/groups/fixture-group/requests'
          : '/watch-requests/patrol-plan/state';
      Completer<void>? hold;
      var delayedStarted = false;
      final client = MockClient((request) async {
        final pending = hold;
        if (request.url.path == path && pending != null) {
          hold = null;
          final oldResponse = await api.handle(request);
          delayedStarted = true;
          await pending.future;
          return oldResponse;
        }
        return api.handle(request);
      });
      useApiFixture(client);
      final auth = StoreScreenshotAuth();
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => group
                ? const GroupWatchPlanV2Screen(
                    groupId: 'fixture-group', initialRequestId: 'patrol-plan')
                : const WatchRequestsScreen(initialRequestId: 'patrol-plan'))
      ]);
      addTearDown(auth.dispose);
      addTearDown(router.dispose);
      await tester.pumpWidget(storeScreenshotApp(auth, router));
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      hold = gate;
      TabRefreshController.watchPlans.value++;
      await tester.pumpAndSettle();
      expect(delayedStarted, true);
      api.plan['movie'] = {'id': 348, 'title': 'Latest server movie'};
      if (group) api.plan['movieTitle'] = 'Latest server movie';
      for (final candidate in api.plan['candidates'] as List) {
        if (candidate['id'] == 'alien') {
          candidate['movie'] = {'id': 348, 'title': 'Latest server movie'};
        }
      }
      TabRefreshController.watchPlans.value++;
      await tester.pumpAndSettle();
      expect(find.textContaining('Latest server movie'), findsWidgets);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('Latest server movie'), findsWidgets);
      expect(api.unexpected, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
