import 'dart:convert';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/widgets/add_to_list_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/add_show_to_list_sheet.dart';
import '../../../support/watchlist_auth.dart';
import '../../../support/api_fixture.dart';

var fixtureSequence = 0;

class ListFixtureAuth extends TestAuth {
  final fixtureId = 'list-fixture-${fixtureSequence++}';
  @override
  User get dbUser => super.dbUser.copyWith(id: fixtureId);
}

class ListAnalytics extends ChangeNotifier implements AnalyticsController {
  @override
  Future<void> movieAddedToList() async {}
  @override
  Future<void> movieRemovedFromList() async {}
  @override
  Future<void> showAddedToList() async {}
  @override
  Future<void> showRemovedFromList() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> addToListJourney(WidgetTester tester,
    {bool retry = false,
    bool saveAndUndo = false,
    bool membershipRetry = false,
    bool show = false}) async {
  final before = show
      ? const bool.fromEnvironment('TV_LIST_BEFORE')
      : const bool.fromEnvironment('ADD_LIST_BEFORE');
  final auth = ListFixtureAuth();
  addTearDown(auth.dispose);
  var friends = 0, memberships = 0, adds = 0, removes = 0, overviewReads = 0;
  final analytics = ListAnalytics();
  addTearDown(analytics.dispose);
  Map<String, dynamic>? created;
  useApiFixture(MockClient((request) async {
    if (request.url.path.contains('/friends/')) {
      friends++;
      if (retry && friends == 1) {
        return http.Response('{"message":"offline"}', 503);
      }
      return http.Response(
          jsonEncode({
            'friendships': [
              for (var i = 0; i < 12; i++)
                {
                  'id': 'edge-$i',
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
    if (request.url.path.endsWith(show ? '/shows/1' : '/movies/1')) {
      if (request.method == 'POST') {
        adds++;
        return http.Response('{"id":"entry","movieId":1,"removed":false}', 200);
      }
      removes++;
      return http.Response('{}', 200);
    }
    if (request.method == 'POST') {
      created = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
          jsonEncode(
              {'id': 'created', 'name': created!['name'], 'removed': false}),
          201);
    }
    if (request.url.path.endsWith('/lists')) {
      overviewReads++;
      return http.Response(
          jsonEncode([
            for (var i = 0; i < 40; i++)
              {'id': 'list-$i', 'name': 'Alien collection $i', 'removed': false}
          ]),
          200);
    }
    if (request.url.path.contains('/lists/containing/')) {
      memberships++;
      if (membershipRetry && memberships == 1) {
        return http.Response('{"message":"offline"}', 503);
      }
      return http.Response('{"listIds":[]}', 200);
    }
    if (request.url.path.contains('/lists/')) {
      memberships++;
      return http.Response('[]', 200);
    }
    throw StateError('Unexpected ${request.method} ${request.url}');
  }));
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<AnalyticsController>.value(value: analytics)
      ],
      child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          useRootNavigator: true,
                          useSafeArea: true,
                          isScrollControlled: true,
                          builder: (_) => show
                              ? const AddShowToListSheet(
                                  showId: 1, showTitle: 'Alien Earth')
                              : const AddToListSheet(
                                  movieId: 1, movieTitle: 'Alien')),
                      child: const Text('Open lists')))))));
  await tester.tap(find.text('Open lists'));
  await tester.pumpAndSettle();
  if (membershipRetry) {
    expect(
        find.text('Couldn’t check your lists. Please retry.'), findsOneWidget);
    expect(find.text('New list'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
  }
  expect(
      memberships,
      before
          ? 40
          : membershipRetry
              ? 2
              : 1);
  expect(overviewReads, membershipRetry ? 2 : 1);
  await tester.ensureVisible(find.text('New list'));
  await tester.tap(find.text('New list'));
  await tester.pumpAndSettle();
  expect(friends, before ? 1 : 0);
  await tester.enterText(
      find.widgetWithText(TextField, 'List Name'), 'Alien and The Odyssey');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Just me'));
  await tester.tap(find.text('Just me'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Me and selected friends').last);
  await tester.pumpAndSettle();
  if (retry) {
    await tester.ensureVisible(find.text('Could not load friends. Retry'));
    await tester.tap(find.text('Could not load friends. Retry'));
    await tester.pumpAndSettle();
  }
  expect(friends, retry ? 2 : 1);
  await tester.ensureVisible(find.text('@AlienFan0'));
  await tester.tap(find.text('@AlienFan0'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Create'));
  await tester.tap(find.text('Create'));
  await tester.pumpAndSettle();
  expect(created!['name'], 'Alien and The Odyssey');
  expect(created!['collaboratorIds'], ['friend-0']);
  expect(find.text('Done · Added to 1 list'), findsOneWidget);
  if (saveAndUndo) {
    await tester.ensureVisible(find.text('Done · Added to 1 list'));
    await tester.tap(find.text('Done · Added to 1 list'));
    await tester.pumpAndSettle();
    expect(adds, 1);
    expect(find.text('Lists updated'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(removes, 1);
    expect(find.text('List changes undone'), findsOneWidget);
  }
  expect(tester.takeException(), isNull);
}
