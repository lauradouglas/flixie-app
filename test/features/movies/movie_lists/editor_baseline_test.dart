import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_lists_screen.dart';
import '../../../support/watchlist_auth.dart';
import '../../../support/api_fixture.dart';

void main() {
  testWidgets('personal editor opens without awaiting relationship reads',
      (tester) async {
    const before = bool.fromEnvironment('LISTS_BEFORE');
    final auth = TestAuth();
    addTearDown(auth.dispose);
    final friends = Completer<http.Response>();
    final groups = Completer<http.Response>();
    final requests = <String>[];
    useApiFixture(MockClient((request) async {
      requests.add(request.url.path);
      if (request.url.path.contains('/friends/')) return friends.future;
      if (request.url.path.contains('/groups/user/')) return groups.future;
      if (request.url.path.endsWith('/lists')) {
        return http.Response(
            jsonEncode([
              for (var i = 0; i < 40; i++)
                {
                  'id': 'fixture-$i',
                  'userId': 'viewer',
                  'name': 'Alien collection $i',
                  'removed': false
                }
            ]),
            200);
      }
      throw StateError('Unexpected ${request.url}');
    }));
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth, child: const MaterialApp(home: MovieListsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New list').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Make a little collection.'),
        before ? findsNothing : findsOneWidget);
    expect(
        requests
            .where(
                (p) => p.contains('/friends/') || p.contains('/groups/user/'))
            .length,
        before ? 2 : 0);
    friends.complete(http.Response(
        '{"friendships":[],"pendingFriends":[],"requestedFriends":[]}', 200));
    groups.complete(http.Response('[]', 200));
    await tester.pumpAndSettle();
    expect(find.text('Make a little collection.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
