import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_editor_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/edit_profile_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/change_avatar_sheet.dart';
import 'package:flixie_app/models/user.dart';
import '../../support/watchlist_auth.dart';
import '../../support/api_fixture.dart';

class EditorAuth extends TestAuth {
  late User current = super
      .dbUser
      .copyWith(username: 'Casey', bio: 'Original', profileBadges: ['FOUNDER']);
  @override
  User get dbUser => current;
  @override
  void updateDbUser(User user) {
    current = user;
    notifyListeners();
  }

  @override
  void updateCachedUser(User user) => updateDbUser(user);
}

Future<void> open(WidgetTester tester, EditorAuth auth, Widget sheet) async {
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          useRootNavigator: true,
                          useSafeArea: true,
                          isScrollControlled: true,
                          isDismissible: false,
                          enableDrag: false,
                          builder: (_) => sheet),
                      child: const Text('Open editor')))))));
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

Future<void> profileDraftJourney(WidgetTester tester) async {
  final auth = EditorAuth();
  addTearDown(auth.dispose);
  await open(tester, auth,
      const EditProfileSheet(currentUsername: 'Casey', currentBio: 'Original'));
  await tester.enterText(find.widgetWithText(TextField, 'Bio'), 'Alien night');
  await tester.pump();
  await tester.tap(find.text('Cancel'));
  await tester.pumpAndSettle();
  expect(find.text('Discard unsaved changes?'), findsOneWidget);
  await tester.tap(find.text('Keep editing'));
  await tester.pumpAndSettle();
  expect(find.text('Alien night'), findsOneWidget);
  await tester.tap(find.byTooltip('Close'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Discard changes'));
  await tester.pumpAndSettle();
  expect(find.byType(EditProfileSheet), findsNothing);
  expect(auth.dbUser.bio, 'Original');
}

void main() {
  testWidgets('edited draft can be kept or deliberately discarded',
      profileDraftJourney);
  testWidgets(
      'profile retries only the failed field and preserves library and badges',
      (tester) async {
    final auth = EditorAuth();
    addTearDown(auth.dispose);
    var fail = true;
    final writes = <String>[];
    useApiFixture(MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      writes.add(body.keys.single as String);
      if (body.containsKey('bio') && fail)
        return http.Response('{"message":"offline"}', 503);
      return http.Response(jsonEncode({'id': 'viewer', ...body}), 200);
    }));
    await open(
        tester,
        auth,
        const EditProfileSheet(
            currentUsername: 'Casey', currentBio: 'Original'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Username'), 'CaseyFilm');
    await tester.enterText(
        find.widgetWithText(TextField, 'Bio'), 'Alien night');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(writes, ['username', 'bio']);
    expect(auth.dbUser.username, 'CaseyFilm');
    expect(auth.dbUser.bio, 'Original');
    expect(auth.dbUser.profileBadges, ['FOUNDER']);
    expect(auth.dbUser.movieWatchlist, hasLength(1));
    fail = false;
    await tester.ensureVisible(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(writes, ['username', 'bio', 'bio']);
    expect(auth.dbUser.bio, 'Alien night');
  });
  testWidgets('profile validates inline and suppresses duplicate pending saves',
      (tester) async {
    final auth = EditorAuth();
    addTearDown(auth.dispose);
    var writes = 0;
    final pending = Completer<http.Response>();
    useApiFixture(MockClient((request) {
      writes++;
      return pending.future;
    }));
    await open(
        tester,
        auth,
        const EditProfileSheet(
            currentUsername: 'Casey', currentBio: 'Original'));
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'a');
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(find.text('Use at least 3 characters.'), findsOneWidget);
    expect(writes, 0);
    await tester.enterText(
        find.widgetWithText(TextField, 'Username'), 'CaseyFilm');
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(writes, 1);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    pending
        .complete(http.Response('{"id":"viewer","username":"CaseyFilm"}', 200));
    await tester.pumpAndSettle();
  });
  testWidgets(
      'avatar failed save keeps choice, retries save only and supports Undo',
      (tester) async {
    final auth = EditorAuth();
    addTearDown(auth.dispose);
    var reads = 0, writes = 0, deletes = 0;
    var fail = true;
    const avatar = {
      'id': 1,
      'key': 'pip',
      'displayName': 'Pip',
      'storagePath': 'avatars/pip.png',
      'imageUrl': 'https://example.invalid/pip.png'
    };
    useApiFixture(MockClient((request) async {
      if (request.method == 'GET') {
        reads++;
        return http.Response(
            jsonEncode({
              'avatars': [avatar]
            }),
            200);
      }
      if (request.method == 'DELETE') {
        deletes++;
        return http.Response('{}', 200);
      }
      writes++;
      return fail
          ? http.Response('{"message":"offline"}', 503)
          : http.Response(jsonEncode({'avatar': avatar}), 200);
    }));
    await open(tester, auth, const ChangeAvatarSheet());
    await tester.tap(find.byWidgetPredicate((w) =>
        w is Semantics &&
        w.properties.label == 'Pip' &&
        w.properties.selected != null));
    await tester.pump();
    await tester.tap(find.text('Save avatar'));
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Pip, selected'),
        findsOneWidget);
    expect(writes, 1);
    fail = false;
    await tester.ensureVisible(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(writes, 2);
    expect(auth.dbUser.avatar?.id, 1);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(auth.dbUser.avatar, isNull);
    expect(auth.dbUser.profileBadges, ['FOUNDER']);
  });
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(768, 1024)
  ]) {
    testWidgets(
        'editor actions remain reachable at $size with keyboard and large text',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 100)),
              child: child!),
          home: Scaffold(
              body: FlixieEditorSheet(
                  title: 'Edit profile',
                  dirty: false,
                  busy: false,
                  onSave: () {},
                  child:
                      const Text('A long field description that can wrap.')))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Save changes'), findsOneWidget);
    });
  }
}
