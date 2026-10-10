import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_list_detail/movie_list_poster_card.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import '../../../../patrol_test/support/movie_list_detail_fixture.dart';
import '../../../support/api_fixture.dart';

Future<ListDetailAuth> mount(WidgetTester tester, MovieListDetailFixture api,
    {String? ownerId, bool? canEdit, double textScale = 1}) async {
  final auth = ListDetailAuth();
  final router = movieListFixtureRouter(ownerId: ownerId, canEdit: canEdit);
  addTearDown(auth.dispose);
  addTearDown(router.dispose);
  useApiFixture(api.client);
  await tester
      .pumpWidget(movieListFixtureApp(auth, router, textScale: textScale));
  await tester.pumpAndSettle();
  return auth;
}

Future<void> search(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextField), value);
  await tester.pump(const Duration(milliseconds: 351));
  await tester.pumpAndSettle();
}

Future<void> members(WidgetTester tester) async {
  await tester.tap(find.byTooltip('List actions'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('View members'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'refresh after revoked access hides retained titles and edit controls',
      (tester) async {
    final api = MovieListDetailFixture();
    var denied = false;
    final auth = ListDetailAuth();
    final router = movieListFixtureRouter();
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    useApiFixture(MockClient((r) async {
      if (denied && r.url.path.contains('/fixture-list/')) {
        return api.json({'message': 'List not found'}, 404);
      }
      return api.handle(r);
    }));
    await tester.pumpWidget(movieListFixtureApp(auth, router));
    await tester.pumpAndSettle();
    expect(find.text('Alien'), findsOneWidget);
    denied = true;
    await tester.tap(find.byTooltip('List actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('This list is no longer available.'), findsOneWidget);
    expect(find.byType(MovieListPosterCard), findsNothing);
    expect(find.byTooltip('Add titles'), findsNothing);
  });
  testWidgets('two immediate add taps send one write and retain the picker',
      (tester) async {
    final api = MovieListDetailFixture();
    final gate = Completer<void>();
    var writes = 0;
    final auth = ListDetailAuth();
    final router = movieListFixtureRouter();
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    useApiFixture(MockClient((r) async {
      if (r.method == 'POST') {
        writes++;
        await gate.future;
      }
      return api.handle(r);
    }));
    await tester.pumpWidget(movieListFixtureApp(auth, router));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add titles'));
    await tester.pumpAndSettle();
    await search(tester, 'Spider');
    final button = find.byTooltip('Add Spider-Man');
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    expect(writes, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Added'), findsOneWidget);
    expect(writes, 1);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'title/contributor filters are local and badges survive projection',
      (tester) async {
    final api = MovieListDetailFixture();
    await mount(tester, api);
    final reads = api.calls.length;
    await tester.tap(find.byTooltip('Sort list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title'));
    await tester.pumpAndSettle();
    final cards = tester
        .widgetList<MovieListPosterCard>(find.byType(MovieListPosterCard))
        .toList();
    expect(cards.map((c) => c.entry.movie?.title ?? c.entry.show?.name),
        ['Alien', 'Alien: Earth', 'The Odyssey']);
    await tester.tap(find.byTooltip('Filter by contributor'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text('@list-friend')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<MovieListPosterCard>(find.byType(MovieListPosterCard))
            .every((c) => c.entry.addedBy!.id == 'list-friend'),
        isTrue);
    expect(api.calls.length, reads);
    expect(
        tester
            .widgetList<ProfileAvatarView>(find.byType(ProfileAvatarView))
            .every((a) => a.profileBadges.contains('EARLY_ADOPTER')),
        isTrue);
    expect(api.unexpected, isEmpty);
  });
  testWidgets(
      'movie/show with overlapping IDs add independently and picker stays open',
      (tester) async {
    final api = MovieListDetailFixture();
    await mount(tester, api);
    await tester.tap(find.byTooltip('Add titles'));
    await tester.pumpAndSettle();
    await search(tester, 'Spider');
    await tester.tap(find.byTooltip('Add Spider-Man'));
    await tester.pumpAndSettle();
    expect(find.text('Added'), findsOneWidget);
    await tester.tap(find.byTooltip('Add Obsession TV'));
    await tester.pumpAndSettle();
    expect(find.text('Added'), findsNWidgets(2));
    expect(api.entries.where((e) => e['movieId'] == 3), hasLength(1));
    expect(api.entries.where((e) => e['showId'] == 3), hasLength(1));
    expect(api.writes, hasLength(2));
    expect(api.unexpected, isEmpty);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(api.calls.where((c) => c.endsWith('/items') && c.startsWith('GET')),
        hasLength(2)); // show add refresh only
  });
  testWidgets(
      'cancel then confirm removal changes only the selected media type',
      (tester) async {
    final api = MovieListDetailFixture();
    await mount(tester, api);
    final card = find.byType(MovieListPosterCard).first;
    final action = find.descendant(
        of: card, matching: find.byTooltip('List item actions'));
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.writes, isEmpty);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(api.entries.any((e) => e['movieId'] == 1), isFalse);
    expect(api.entries.any((e) => e['showId'] == 1), isTrue);
    expect(
        api.writes, ['DELETE /users/list-owner/lists/fixture-list/movies/1']);
  });
  testWidgets(
      'member writes refresh metadata and dismiss the root member sheet only',
      (tester) async {
    final api = MovieListDetailFixture();
    await mount(tester, api);
    await members(tester);
    await tester.tap(find.byTooltip('Remove member'));
    await tester.pumpAndSettle();
    expect(api.members, ['list-owner']);
    expect(find.text('Fixture collection'), findsOneWidget);
    expect(find.text('Lists destination'), findsNothing);
    expect(find.text('2 members'), findsNothing);
    expect(api.unexpected, isEmpty);
  });
  testWidgets('failed member read shows feedback and leaves sheet usable',
      (tester) async {
    final api = MovieListDetailFixture();
    final auth = ListDetailAuth();
    final router = movieListFixtureRouter();
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    useApiFixture(MockClient((request) async =>
        request.url.path.startsWith('/friends/')
            ? api.json({'message': 'Offline'}, 500)
            : await api.handle(request)));
    await tester.pumpWidget(movieListFixtureApp(auth, router));
    await tester.pumpAndSettle();
    await members(tester);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to add a member.'), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget);
    expect(api.writes, isEmpty);
  });
  testWidgets(
      'account switch removes the old picker and rejects late search publication',
      (tester) async {
    final api = MovieListDetailFixture();
    final gate = Completer<http.Response>();
    final auth = ListDetailAuth();
    final router = movieListFixtureRouter();
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    useApiFixture(MockClient((request) async => request.url.path == '/search'
        ? await gate.future
        : await api.handle(request)));
    await tester.pumpWidget(movieListFixtureApp(auth, router));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add titles'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Spider');
    await tester.pump(const Duration(milliseconds: 351));
    auth.switchViewer('new-viewer');
    await tester.pumpAndSettle();
    gate.complete(api.json({
      'results': [
        {'id': 3, 'title': 'Spider-Man'}
      ]
    }));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(api.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('an older failed search cannot clear newer results',
      (tester) async {
    final api = MovieListDetailFixture();
    final old = Completer<http.Response>();
    final auth = ListDetailAuth();
    final router = movieListFixtureRouter();
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    useApiFixture(MockClient((r) async =>
        r.url.path == '/search' && r.url.queryParameters['value'] == 'Old'
            ? old.future
            : api.handle(r)));
    await tester.pumpWidget(movieListFixtureApp(auth, router));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add titles'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Old');
    await tester.pump(const Duration(milliseconds: 351));
    await search(tester, 'Spider');
    old.complete(api.json({'message': 'Old failure'}, 500));
    await tester.pumpAndSettle();
    expect(find.text('Spider-Man'), findsOneWidget);
    expect(find.text('Unable to search titles right now.'), findsNothing);
  });
  testWidgets(
      'fresh membership denies editing despite the optimistic route override',
      (tester) async {
    final api = MovieListDetailFixture()
      ..canEdit = false
      ..owner = false;
    await mount(tester, api, canEdit: true);
    expect(find.byTooltip('Add titles'), findsNothing);
    expect(find.byTooltip('List item actions'), findsNothing);
    await tester.tap(find.byTooltip('List actions'));
    await tester.pumpAndSettle();
    expect(find.text('Delete list'), findsNothing);
    expect(find.text('Leave list'), findsOneWidget);
  });
  for (final size in [
    const Size(320, 740),
    const Size(844, 390),
    const Size(768, 1024)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('list and member sheet fit $size at text scale $scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = MovieListDetailFixture();
        await mount(tester, api, textScale: scale);
        expect(tester.takeException(), isNull);
        await members(tester);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.text('2 members')), rootNavigator: true).pop();
        await tester.pumpAndSettle();
        tester.view.viewInsets = FakeViewPadding(bottom: size.height < 500 ? 180 : 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.tap(find.byTooltip('Add titles'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
