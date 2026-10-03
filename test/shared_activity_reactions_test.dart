import 'package:flixie_app/features/social/data/activity_state_batch.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_feed_card.dart';
import '../patrol_test/support/fixture_app.dart';
import 'community_activity_feed_test.dart' as fixtures;

void main() {
  setUp(ActivityStateBatch.clear);
  tearDown(ActivityStateBatch.clear);
  testWidgets(
      'a reaction changed in Community updates the mounted Friends card',
      (tester) async {
    final auth = FixtureAuth();
    addTearDown(auth.dispose);
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var mine = '❤️';
    final client = MockClient((request) async {
      if (request.method == 'PUT') {
        mine = (jsonDecode(request.body)['reaction'] as String?) ?? '';
      }
      final summary = {
        'counts': {'❤️': mine.isEmpty ? 0 : 1},
        'mine': mine.isEmpty ? null : mine
      };
      if (request.url.path == '/community/activity-state') {
        return http.Response(
            jsonEncode({
              'items': [
                for (final target
                    in jsonDecode(request.body)['targets'] as List)
                  {...target, 'reactions': summary, 'saved': false}
              ]
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response(
          jsonEncode(
              request.method == 'GET' && request.url.path.contains('/friends/')
                  ? {'movie-review:shared-review': summary}
                  : summary),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    ApiClient.useClientForTesting(client);
    addTearDown(() {
      ApiClient.useClientForTesting(null);
      client.close();
    });

    final item = fixtures.fixture('shared-review');
    await tester.pumpWidget(fixtureApp(
        auth,
        Scaffold(
            body: Column(children: [
          ActivityTile(item: item),
          ActivityTile(item: item, community: true),
        ]))));
    await tester.pumpAndSettle();
    expect(find.text('❤️ 1'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Love this · Tap to remove').last);
    await tester.pumpAndSettle();
    final cards =
        tester.widgetList<ActivityFeedCard>(find.byType(ActivityFeedCard));
    expect(cards.every((card) => card.reactions.mine == null), isTrue);
    expect(find.text('❤️ 1'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Friends comments action opens the private activity route',
      (tester) async {
    final item = fixtures.fixture('comment-route');
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(body: ActivityTile(item: item))),
      GoRoute(
          path: '/friends/activity/:owner/:type/:id',
          builder: (_, state) => Scaffold(
              body: Text(
                  'Comments for ${state.pathParameters['owner']}/${state.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Comments'));
    await tester.pumpAndSettle();
    expect(find.text('Comments for friend/comment-route'), findsOneWidget);
  });
}
