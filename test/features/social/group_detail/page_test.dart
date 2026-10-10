import '../../../support/api_fixture.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/features/social/presentation/pages/group_detail_screen.dart';
import '../../home/home_controller_test.dart' show SessionAuth, viewer;

http.Response response(Object value) => http.Response(jsonEncode(value), 200,
    headers: {'content-type': 'application/json'});

void main() => registerDetailJourneys((name, body) => testWidgets(name, body));

void registerDetailJourneys(
    void Function(String, Future<void> Function(WidgetTester)) register) {
  register(
      'header does not wait for lists; group and account switches replace child state',
      (tester) async {
    final auth = SessionAuth();
    final cache = WatchRequestCache();
    addTearDown(auth.dispose);
    addTearDown(cache.dispose);
    final lists = Completer<http.Response>();
    final lateGroup = Completer<http.Response>();
    final reads = <String>[];
    final methods = <String>[];
    Widget page(String id) => MultiProvider(providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<WatchRequestCache>.value(value: cache),
        ], child: MaterialApp(home: GroupDetailScreen(groupId: id)));
    final client = MockClient((request) async {
      // Native frame callbacks can run outside the assertion's test zone.
      methods.add(request.method);
      final path = request.url.path;
      reads.add(path);
      if (path == '/groups/old') return lateGroup.future;
      if (path == '/groups/new') {
        return response({'id': 'new', 'name': 'New group', 'ownerId': 'first'});
      }
      if (path.endsWith('/activity/feed')) {
        return response({'items': [], 'reactions': {}});
      }
      if (path.contains('/users/first/')) return lists.future;
      return response([]);
    });
    useApiFixture(client);
    await (() async {
      await tester.pumpWidget(page('old'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpWidget(page('new'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('New group'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Loading…'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Create'), findsNothing);
      lateGroup.complete(
          response({'id': 'old', 'name': 'Old group', 'ownerId': 'first'}));
      lists.complete(response([]));
      await tester.pumpAndSettle();
      expect(find.text('Old group'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Create'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('New group'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      auth.select(viewer('second'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();
      // Native frames and HTTP completion need not settle in the same pump.
      // Wait for the account-owned reload, then keep the exact request budget.
      final reloadDeadline = DateTime.now().add(const Duration(seconds: 5));
      while ((reads.where((p) => p == '/groups/new').length < 2 ||
              !reads.any((p) => p.contains('/users/second/'))) &&
          DateTime.now().isBefore(reloadDeadline)) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(reads.where((p) => p == '/groups/new'), hasLength(2));
      expect(reads.any((p) => p.contains('second')), true);
      expect(reads.any((p) => p.contains('conversation')), false,
          reason: 'opening Activity does not resolve or create chat');
      expect(methods, everyElement('GET'),
          reason: 'cancelled deletion sends no mutation');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    })();
  });
}
