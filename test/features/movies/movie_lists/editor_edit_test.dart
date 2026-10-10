import 'package:flixie_app/models/user.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/controllers/movie_lists_controller.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_lists/movie_list_editor.dart';
import 'package:flixie_app/models/movie_list.dart';
import '../../../support/watchlist_auth.dart';
import '../../../support/api_fixture.dart';

Future<void> openEditor(WidgetTester tester, String scope,
    {TestAuth? suppliedAuth}) async {
  final auth = suppliedAuth ?? TestAuth();
  addTearDown(auth.dispose);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(
            create: (_) => MovieListsProvider(userId: 'viewer')),
      ],
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => showMovieListEditor(context,
                          listId: 'existing',
                          initialName: 'Alien nights',
                          initialScope: scope,
                          initialGroupId:
                              scope == ListScope.group ? 'group-1' : null,
                          initialCollaborators: scope == ListScope.friends
                              ? const [
                                  MovieListCollaborator(
                                      id: 'old', username: 'OldFriend')
                                ]
                              : const []),
                      child: const Text('Edit fixture')))))));
  await tester.tap(find.text('Edit fixture'));
  await tester.pumpAndSettle();
}

class SwitchingAuth extends TestAuth {
  String identity = 'viewer';
  @override
  User get dbUser => super.dbUser.copyWith(id: identity);
}

void main() {
  testWidgets('group edit keeps membership locked and prevents duplicate saves',
      (tester) async {
    var reads = 0, writes = 0;
    final pending = Completer<http.Response>();
    useApiFixture(MockClient((request) async {
      if (request.url.path.contains('/friends/') ||
          request.url.path.contains('/groups/user/')) {
        reads++;
        throw StateError('Unexpected relationship read');
      }
      if (request.method == 'PATCH') {
        writes++;
        final data = jsonDecode(request.body);
        expect(data['scope'], 'GROUP');
        expect(data['groupId'], 'group-1');
        return pending.future;
      }
      return http.Response('[]', 200);
    }));
    await openEditor(tester, ListScope.group);
    expect(reads, 0);
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>));
    expect(dropdown.onChanged, isNull);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(writes, 1);
    expect(find.text('Saving…'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    pending.complete(http.Response('{}', 200));
    await tester.pumpAndSettle();
    expect(find.text('Edit fixture'), findsOneWidget);
  });
  testWidgets('friend edit saves collaborator additions and removals',
      (tester) async {
    final changes = <String>[];
    useApiFixture(MockClient((request) async {
      if (request.url.path.contains('/friends/')) {
        return http.Response(
            jsonEncode({
              'friendships': [
                for (final id in ['old', 'new'])
                  {
                    'id': id,
                    'friend': {'id': id, 'username': id}
                  }
              ],
              'pendingFriends': [],
              'requestedFriends': []
            }),
            200);
      }
      if (request.method == 'PATCH') {
        expect(jsonDecode(request.body)['collaboratorIds'], ['new']);
        return http.Response('{}', 200);
      }
      if (request.method == 'POST') {
        changes.add('add:${jsonDecode(request.body)['collaboratorId']}');
        return http.Response('{}', 200);
      }
      if (request.method == 'DELETE') {
        changes.add('remove:${request.url.path.split('/').last}');
        return http.Response('{}', 200);
      }
      return http.Response('[]', 200);
    }));
    await openEditor(tester, ListScope.friends);
    for (final label in ['@old', '@new']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(changes, ['add:new', 'remove:old']);
    expect(find.text('Edit fixture'), findsOneWidget);
  });
  testWidgets('account switch during edit blocks collaborator follow-up writes',
      (tester) async {
    final auth = SwitchingAuth();
    final patch = Completer<http.Response>();
    var writes = 0, members = 0;
    useApiFixture(MockClient((request) async {
      if (request.url.path.contains('/friends/')) {
        return http.Response(
            '{"friendships":[{"id":"old","friend":{"id":"old","username":"old"}},{"id":"new","friend":{"id":"new","username":"new"}}],"pendingFriends":[],"requestedFriends":[]}',
            200);
      }
      if (request.method == 'PATCH') {
        writes++;
        return patch.future;
      }
      if (request.method != 'GET') {
        members++;
        return http.Response('{}', 200);
      }
      return http.Response('[]', 200);
    }));
    await openEditor(tester, ListScope.friends, suppliedAuth: auth);
    await tester.ensureVisible(find.text('@new'));
    await tester.tap(find.text('@new'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(writes, 1);
    auth.identity = 'another-fixture';
    patch.complete(http.Response('{}', 200));
    await tester.pump();
    expect(members, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'personal edit loads groups only when selected and saves chosen group',
      (tester) async {
    var groupReads = 0;
    Map<String, dynamic>? saved;
    useApiFixture(MockClient((request) async {
      if (request.url.path.contains('/groups/user/')) {
        groupReads++;
        return http.Response(
            '[{"id":"group-1","name":"Odyssey friends","ownerId":"viewer"}]',
            200);
      }
      if (request.url.path.contains('/friends/')) {
        throw StateError('Unneeded friends read');
      }
      if (request.method == 'PATCH') {
        saved = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }
      return http.Response('[]', 200);
    }));
    await openEditor(tester, ListScope.personal);
    expect(groupReads, 0);
    await tester.ensureVisible(find.text('Just me'));
    await tester.tap(find.text('Just me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('With a group').last);
    await tester.pumpAndSettle();
    expect(groupReads, 1);
    await tester.ensureVisible(find.text('Choose group'));
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odyssey friends').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved!['scope'], 'GROUP');
    expect(saved!['groupId'], 'group-1');
  });
}
