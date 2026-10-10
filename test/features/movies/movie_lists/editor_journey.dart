import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_lists_screen.dart';
import '../../../support/watchlist_auth.dart';
import '../../../support/api_fixture.dart';

/// Fictional 40-list, 12-friend, 3-group fixture; never uses a real account.
Future<void> movieListsEditorJourney(WidgetTester tester) async {
  final auth = TestAuth();
  addTearDown(auth.dispose);
  var friendReads = 0, groupReads = 0, saves = 0;
  var failFriends = true;
  Map<String, dynamic>? saved;
  useApiFixture(MockClient((request) async {
    if (request.url.path.contains('/friends/')) {
      friendReads++;
      if (failFriends) return http.Response('{"message":"offline"}', 503);
      return http.Response(
          jsonEncode({
            'friendships': [
              for (var i = 0; i < 12; i++)
                {
                  'id': 'friendship-$i',
                  'createdAt': '',
                  'updatedAt': '',
                  'friend': {
                    'id': 'friend-$i',
                    'username': 'AlienFan$i',
                    'profileBadges': ['FOUNDER']
                  }
                }
            ],
            'pendingFriends': [],
            'requestedFriends': []
          }),
          200);
    }
    if (request.url.path.contains('/groups/user/')) {
      groupReads++;
      return http.Response(
          jsonEncode([
            for (var i = 0; i < 3; i++)
              {
                'id': 'group-$i',
                'name': 'Odyssey group $i',
                'ownerId': 'viewer'
              }
          ]),
          200);
    }
    if (request.method == 'POST') {
      saved = jsonDecode(request.body) as Map<String, dynamic>;
      saves++;
      if (saves == 1) {
        return http.Response('{"message":"fixture save failure"}', 503);
      }
      return http.Response(
          jsonEncode({
            'id': 'created',
            'userId': 'viewer',
            'name': saved!['name'],
            'removed': false
          }),
          201);
    }
    if (request.url.path.endsWith('/lists')) {
      return http.Response(
          jsonEncode([
            for (var i = 0; i < 40; i++)
              {
                'id': 'list-$i',
                'userId': 'viewer',
                'name': 'Alien collection $i',
                'removed': false
              }
          ]),
          200);
    }
    throw StateError('Unexpected ${request.method} ${request.url}');
  }));
  String? addParameter;
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const MovieListsScreen()),
    GoRoute(
        path: '/movie-lists/:id',
        builder: (_, state) {
          addParameter = state.uri.queryParameters['add'];
          return const Scaffold(body: Text('Created list destination'));
        }),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child:
          MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('New list').first);
  await tester.pumpAndSettle();
  expect(friendReads + groupReads, 0);
  await tester.enterText(
      find.widgetWithText(TextField, 'List name'), 'Alien and The Odyssey');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('With friends'));
  await tester.tap(find.text('With friends'));
  await tester.pumpAndSettle();
  expect(find.text('Could not load friends. Retry'), findsOneWidget);
  failFriends = false;
  await tester.ensureVisible(find.text('Could not load friends. Retry'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Could not load friends. Retry'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('@AlienFan0'));
  await tester.tap(find.text('@AlienFan0'));
  await tester.pumpAndSettle();
  expect(friendReads, 2);
  expect(groupReads, 0);
  await tester.ensureVisible(find.text('Create'));
  await tester.tap(find.text('Create'));
  await tester.pumpAndSettle();
  expect(find.widgetWithText(TextField, 'List name'), findsOneWidget);
  expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'List name'))
          .controller!
          .text,
      'Alien and The Odyssey');
  await tester.tap(find.text('Create'));
  await tester.pumpAndSettle();
  for (var i = 0;
      i < 50 && find.text('Created list destination').evaluate().isEmpty;
      i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.text('Created list destination'), findsOneWidget);
  expect(addParameter, 'true');
  expect(saved!['scope'], 'FRIENDS');
  expect(saved!['collaboratorIds'], ['friend-0']);
  expect(saved!['visibility'], 'PRIVATE');
  expect(saved!['whoCanAddItems'], 'members');
  expect(saves, 2);
  expect(tester.takeException(), isNull);
}
