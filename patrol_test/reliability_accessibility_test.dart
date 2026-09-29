import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/features/movies/presentation/pages/watch_history_screen.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import '../test/support/api_fixture.dart';
import 'support/fixture_app.dart';

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}

void main() {
  patrolTest(
      'failed history retries and watch sheet covers the nested navigator',
      ($) async {
    var fail = true;
    useApiFixture(MockClient((request) async {
      Object data = [];
      var status = 200;
      if (fail) {
        status = 500;
        data = {'error': 'fixture offline'};
      } else if (request.url.path.endsWith('/movies/watched')) {
        data = [
          {
            'id': 'fictional-watch',
            'movieId': 348,
            'userId': 'patrol-viewer',
            'movie': {'id': 348, 'title': 'Alien'}
          }
        ];
      } else {
        expect(
            request.url.path.endsWith('/movies/reviews') ||
                request.url.path.endsWith('/watches'),
            isTrue);
      }
      return http.Response(jsonEncode(data), status,
          headers: {'content-type': 'application/json'});
    }));
    final auth = FixtureAuth();
    addTearDown(auth.dispose);
    final root = _Routes();
    final nested = _Routes();
    await $.pumpWidgetAndSettle(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            navigatorObservers: [root],
            home: Navigator(
                observers: [nested],
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => const WatchHistoryScreen())))));
    await $('Couldn’t load your watch history.').waitUntilVisible();
    fail = false;
    await $('Retry').tap();
    await $('Alien').waitUntilVisible();
    final nestedBefore = nested.pushed.length;
    await $(find.byType(PopupMenuButton<String>)).tap();
    await $('Log another watch').tap();
    await $(RewatchLogSheet).waitUntilVisible();
    expect(root.pushed.last, isA<ModalBottomSheetRoute>());
    expect((root.pushed.last as ModalBottomSheetRoute).useSafeArea, isTrue);
    expect(nested.pushed.length, nestedBefore + 1,
        reason:
            'Only the popup menu belongs to the nested navigator; the sheet is on the root.');
    await $(find.byIcon(Icons.close)).tap();
    await $('Alien').waitUntilVisible();
    expect(find.byType(RewatchLogSheet), findsNothing);
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $('Alien').waitUntilVisible();
  });
}
