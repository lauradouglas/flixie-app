import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_lists/movie_list_grid_card.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import '../../../support/api_fixture.dart';
import 'editor_edit_test.dart' show openEditor;

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(844, 390),
    const Size(1024, 1366)
  ]) {
    testWidgets('list editor keeps Save reachable at $size and double text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      useApiFixture(MockClient((_) async => http.Response('[]', 200)));
      await openEditor(tester, ListScope.group);
      expect(find.text('Save').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  testWidgets(
      'collaborator avatars keep each own badge without a generic overlay ring',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MovieListGridCard(
                list: const MovieList(
                    id: 'fixture',
                    name: 'Alien',
                    removed: false,
                    scope: ListScope.friends,
                    collaborators: [
                      MovieListCollaborator(
                          id: 'one',
                          username: 'One',
                          profileBadges: ['FOUNDER']),
                      MovieListCollaborator(
                          id: 'two',
                          username: 'Two',
                          profileBadges: ['VERIFIED']),
                    ]),
                onOpen: () {},
                onMenu: (_) {}))));
    expect(
        tester
            .widgetList<ProfileAvatarView>(find.byType(ProfileAvatarView))
            .map((w) => w.profileBadges),
        [
          ['FOUNDER'],
          ['VERIFIED']
        ]);
    expect(
        find.byWidgetPredicate(
            (w) => w is Container && w.foregroundDecoration != null),
        findsNothing);
    expect(tester.takeException(), isNull);
  });
}
