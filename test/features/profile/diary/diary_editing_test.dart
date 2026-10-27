import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/data/diary_entry_service.dart';
import 'package:flixie_app/features/profile/presentation/controllers/profile_diary_controller.dart';
import 'package:flixie_app/features/profile/presentation/diary/diary_entry_flow.dart';
import 'package:flixie_app/features/profile/presentation/diary/diary_film_search_sheet.dart';
import 'package:flixie_app/features/profile/presentation/pages/profile_diary_screen.dart';
import 'package:flixie_app/features/social/data/starred_people.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import '../profile_controller_test.dart' show ProfileAuth;
import 'diary_test.dart' show DiaryData, fixtures;

class EntryData extends DiaryEntryService {
  final updates = <UpdateMovieWatchRequest>[];
  LogMovieWatchRequest? logged;
  bool fail = true;
  @override
  Future<MovieWatchEntry> log(
      String userId, LogMovieWatchRequest request) async {
    logged = request;
    return MovieWatchEntry.fromJson({
      ...fixtures.first.toJson(),
      'notes': request.notes,
      'watchedAt': request.watchedAt
    });
  }

  @override
  Future<List<Friendship>> friends(String userId) async => const [
        Friendship(
            id: 'jamie-friend',
            createdAt: '',
            updatedAt: '',
            friend: FriendshipUser(
                id: 'jamie', username: 'Jamie', profileBadges: ['FOUNDER'])),
      ];
  @override
  Future<MovieWatchEntry> update(
      String userId, String entryId, UpdateMovieWatchRequest request) async {
    updates.add(request);
    if (fail) throw StateError('offline');
    return MovieWatchEntry.fromJson(
        {...fixtures.first.toJson(), 'notes': request.notes});
  }

  @override
  Future<List<MovieShort>> search(String query) async =>
      const [MovieShort(id: 348, name: 'Alien', releaseDate: '1979-05-25')];
}

void main() {
  testWidgets(
      'a chosen film saves a new diary entry with its selected watch date',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = ProfileAuth(), service = EntryData();
    MovieWatchEntry? saved;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async => saved = await editDiaryMemory(
                        context,
                        auth: auth,
                        service: service,
                        movie: const MovieShort(
                            id: 348, name: 'Alien', releaseDate: '1979-05-25'),
                        day: DateTime(2026, 1, 12)),
                    child: const Text('Log fixture'))))));
    await tester.tap(find.text('Log fixture'));
    await tester.pumpAndSettle();
    final note = find.widgetWithText(TextField, 'Diary note (optional)');
    await tester.ensureVisible(note);
    await tester.enterText(note, 'A new diary memory.');
    await tester.tap(find.text('Save watch'));
    await tester.pumpAndSettle();
    expect(service.logged?.movieId, 348);
    expect(service.logged?.draftId, isNotEmpty);
    expect(DateTime.parse(service.logged!.watchedAt!).toLocal().day, 12);
    expect(saved?.notes, 'A new diary memory.');
    auth.dispose();
  });
  for (final spec in [
    (size: const Size(844, 390), keyboard: 216.0),
    (size: const Size(390, 844), keyboard: 300.0),
  ]) {
    testWidgets('film search remains usable above the keyboard ${spec.size}',
        (tester) async {
      tester.view.physicalSize = spec.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showModalBottomSheet<MovieShort>(
                          context: context,
                          useRootNavigator: true,
                          useSafeArea: true,
                          isScrollControlled: true,
                          builder: (_) =>
                              DiaryFilmSearchSheet(service: EntryData())),
                      child: const Text('Search'))))));
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding(bottom: spec.keyboard);
      await tester.pumpAndSettle();
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'editing a memory adds a friend and retains the note and draft on retry',
      (tester) async {
    await diaryMemoryJourney(tester);
  });

  testWidgets(
      'day selection filters watches and the log action keeps its icon beside its label',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = ProfileAuth();
    final c = ProfileDiaryController(auth: auth, service: DiaryData());
    await tester.pumpWidget(MaterialApp(
        home:
            ProfileDiaryScreen(controller: c, today: DateTime(2026, 10, 17))));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Log a film');
    final icon =
        find.descendant(of: button, matching: find.byIcon(Icons.add_rounded));
    final label = find.text('Log a film');
    expect((tester.getCenter(icon).dy - tester.getCenter(label).dy).abs(),
        lessThan(2));
    await tester.tap(find.byKey(ValueKey(
        'diary-week-day-${DateTime(2026, 10, 13).toIso8601String()}')));
    await tester.pumpAndSettle();
    expect(find.text('Alien'), findsNothing);
    expect(find.text('A quiet day.'), findsOneWidget);
    await tester.tap(find.text('Show whole week'));
    await tester.pumpAndSettle();
    expect(find.text('Alien'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    auth.dispose();
  });

  testWidgets('film search returns the selected film for the log flow',
      (tester) async {
    MovieShort? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      selected = await showModalBottomSheet<MovieShort>(
                          context: context,
                          useRootNavigator: true,
                          useSafeArea: true,
                          isScrollControlled: true,
                          builder: (_) =>
                              DiaryFilmSearchSheet(service: EntryData()));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alien');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Alien'));
    await tester.pumpAndSettle();
    expect(selected?.id, 348);
  });
}

Future<void> diaryMemoryJourney(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  StarredPeople.instance.selectAccount('fixture');
  StarredPeople.instance.loaded = true;
  addTearDown(() => StarredPeople.instance.selectAccount(null));
  final auth = ProfileAuth(), service = EntryData();
  MovieWatchEntry? saved;
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                  onPressed: () async => saved = await editDiaryMemory(context,
                      auth: auth, service: service, entry: fixtures.first),
                  child: const Text('Edit fixture'))))));
  await tester.tap(find.text('Edit fixture'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add people'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Jamie'));
  await tester.pump();
  await tester.tap(find.text('Done · 2 selected'));
  await tester.pumpAndSettle();
  final note = find.widgetWithText(TextField, 'Diary note (optional)');
  await tester.ensureVisible(note);
  await tester.enterText(note, 'Cinema night with Jamie and Sophie.');
  await tester.tap(find.text('Save changes'));
  await tester.pumpAndSettle();
  expect(find.textContaining('Your details are still here'), findsOneWidget);
  expect(service.updates.single.companionIds, ['sophie', 'jamie']);
  service.fail = false;
  await tester.tap(find.text('Save changes'));
  await tester.pumpAndSettle();
  expect(service.updates.last.notes, 'Cinema night with Jamie and Sophie.');
  expect(service.updates.last.draftId, service.updates.first.draftId);
  expect(saved?.notes, 'Cinema night with Jamie and Sophie.');
  auth.dispose();
}
