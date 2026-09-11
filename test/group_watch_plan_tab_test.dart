import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import 'package:flixie_app/features/watch_plans/presentation/pages/group_watch_plan_v2_screen.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/watch_request.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  User get dbUser => const User(
      id: 'me',
      username: 'Laura',
      email: '',
      iconColorId: 0,
      completedSetup: true,
      darkMode: true);
  @override
  List<Group> get cachedGroups => [];
  @override
  List<WatchRequest> get cachedWatchRequests => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets(
      'Groups tab embeds V2 directly and refreshes without opening another route',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = _Auth();
    addTearDown(auth.dispose);
    var groupLoads = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: WatchRequestsScreen()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Groups ·'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupWatchPlanV2Screen), findsOneWidget);
      expect(
          tester
              .widget<GroupWatchPlanV2Screen>(
                  find.byType(GroupWatchPlanV2Screen))
              .embedded,
          isTrue);
      expect(find.text('Open Group Watch Plans'), findsNothing);
      expect(find.text('Plan your next movie night'), findsOneWidget);
      final before = groupLoads;
      TabRefreshController.requestSocialRefresh();
      await tester.pumpAndSettle();
      expect(groupLoads, greaterThan(before));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      TabRefreshController.requestSocialRefresh();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.startsWith('/groups/user/')) groupLoads++;
              return http.Response(jsonEncode([]), 200);
            }));
  });
}
