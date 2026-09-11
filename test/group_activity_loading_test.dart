import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/features/social/presentation/pages/group_detail_screen.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_detail_activity_tab.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  User get dbUser => const User(
      id: 'me',
      username: 'Me',
      email: '',
      iconColorId: 0,
      completedSetup: true,
      darkMode: true);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

http.Response response(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
Map<String, dynamic> feed(String title, {bool unavailable = false}) => {
      'items': [
        {
          'id': title,
          'type': 'movie_rating',
          'userId': 'friend',
          'username': 'Friend',
          'rating': 10,
          'createdAt': '2026-09-11T12:00:00Z',
          'movie': {'id': 1, 'title': title}
        }
      ],
      'reactions': {},
      'reactionsUnavailable': unavailable,
    };
void main() {
  testWidgets(
      'one combined load, coalesced refresh, fresh content and removed membership',
      (tester) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    var requests = 0;
    var metadataRefreshes = 0;
    Completer<http.Response>? pending;
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              home: Scaffold(
                  body: GroupActivityTab(
                      group: null,
                      memberCount: 2,
                      groupId: 'fixture',
                      initialRequests: const [],
                      initialActivity: const [],
                      groupLists: const [],
                      onRefresh: () async {
                        metadataRefreshes++;
                      })))));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.text('First'), findsOneWidget);
      pending = Completer<http.Response>();
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      tester
          .state<GroupActivityTabState>(find.byType(GroupActivityTab))
          .didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(requests, 2);
      pending!.complete(response(feed('Second', unavailable: true)));
      await tester.pumpAndSettle();
      await refresh;
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Couldn’t load reactions · Retry'), findsOneWidget);
      pending = Completer<http.Response>();
      final revoked = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      pending!.complete(response({'error': 'Not a member'}, 403));
      await tester.pumpAndSettle();
      await revoked;
      expect(find.text('Second'), findsNothing);
      expect(requests, 3);
      expect(metadataRefreshes, 2);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path != '/groups/fixture/activity/feed') {
                throw StateError('Unexpected request: ${request.url.path}');
              }
              requests++;
              return pending?.future ?? Future.value(response(feed('First')));
            }));
  });

  test('service retains server order for equal timestamps', () async {
    await http.runWithClient(() async {
      final result = await GroupService.getGroupActivityFeed('fixture');
      expect(result.items.map((item) => item.id), ['z', 'a']);
    },
        () => MockClient((_) async => response({
              'items': [
                (feed('z')['items'] as List).first,
                (feed('a')['items'] as List).first
              ],
              'reactions': {}
            })));
  });

  testWidgets('group navigation renders while activity remains pending',
      (tester) async {
    final auth = _Auth();
    final cache = WatchRequestCache();
    addTearDown(auth.dispose);
    addTearDown(cache.dispose);
    final pending = Completer<http.Response>();
    var feedLoads = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<WatchRequestCache>.value(value: cache),
          ],
          child: const MaterialApp(
              home: GroupDetailScreen(groupId: 'fixture', initialTab: 1))));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(pending.isCompleted, isFalse);
      expect(feedLoads, 1);
      pending.complete(response(feed('Ready')));
      await tester.pumpAndSettle();
      expect(find.text('Ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path == '/groups/fixture/activity/feed') {
                feedLoads++;
                return pending.future;
              }
              expect(request.url.path, isNot('/groups/fixture/activity'));
              expect(request.url.path,
                  isNot('/groups/fixture/activity/reactions'));
              if (request.url.path == '/groups/fixture') {
                return response(
                    {'id': 'fixture', 'name': 'Fixture', 'ownerId': 'me'});
              }
              return response([]);
            }));
  });
}
