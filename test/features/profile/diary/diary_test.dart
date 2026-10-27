import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/profile/data/profile_data_service.dart';
import 'package:flixie_app/features/profile/presentation/controllers/profile_diary_controller.dart';
import 'package:flixie_app/features/profile/presentation/diary/diary_selection.dart';
import 'package:flixie_app/features/profile/presentation/diary/diary_watch_entry.dart';
import 'package:flixie_app/features/profile/presentation/pages/profile_diary_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/models/friendship.dart';
import '../profile_controller_test.dart' show ProfileAuth;

MovieWatchEntry watch(String id, String? date,
        {int movie = 348, bool cinema = false, bool removed = false}) =>
    MovieWatchEntry(
        id: id,
        userId: 'viewer',
        movieId: movie,
        watchedAt: date,
        watchedAtCinema: cinema,
        removed: removed,
        movie: WatchlistMovieDetails(
            id: movie, title: movie == 348 ? 'Alien' : 'Interstellar'),
        rating: 9,
        notes: 'A lovely movie night.',
        companions: const [
          FriendshipUser(
              id: 'sophie',
              username: 'Sophie',
              profileBadges: ['EARLY_ADOPTER'])
        ],
        reviewBody: 'SPOILER MUST STAY HIDDEN',
        reviewContainsSpoilers: true);
final fixtures = [
  watch('first', '2026-10-12T18:00:00Z', cinema: true),
  watch('again', '2026-10-12T20:00:00Z'),
  watch('next', '2026-10-23T18:00:00Z', movie: 157336),
  watch('unknown', null)
];

class DiaryData extends ProfileDataService {
  int calls = 0;
  bool fail = false;
  final pending = <String, Completer<List<MovieWatchEntry>>>{};
  @override
  Future<List<MovieWatchEntry>> movieWatches(String userId) async {
    calls++;
    if (fail) throw Exception('offline');
    if (pending[userId] != null) return pending[userId]!.future;
    return fixtures;
  }
}

void main() {
  test(
      'calendar grouping retains same-day rewatches and separates unknown dates',
      () {
    final data = DiarySelection([
      ...fixtures,
      fixtures.first,
      watch('removed', '2026-10-12T12:00:00Z', removed: true)
    ]);
    expect(
        data.week(DateTime(2026, 10, 12)).map((e) => e.id), ['first', 'again']);
    expect(data.days[DateTime(2026, 10, 12)]!.length, 2);
    expect(data.rewatches, {'again'});
    expect(data.undated.single.id, 'unknown');
    expect(data.week(DateTime(2026, 10, 19)).single.movieId, 157336);
    expect(diaryMonday(DateTime(2026, 11, 1)), DateTime(2026, 10, 26));
    expect(diaryDaysBetween(DateTime(2026, 11, 2), DateTime(2026, 10, 26)), 7);
  });
  test(
      'group companions are read-only context and keep individual badge borders',
      () {
    final entry = MovieWatchEntry.fromJson({
      'id': 'group',
      'userId': 'viewer',
      'movieId': 348,
      'removed': false,
      'groupPlanResponses': [
        {
          'request': {
            'responses': [
              {
                'responder': {'id': 'viewer', 'username': 'Me'}
              },
              {
                'responder': {
                  'id': 'robin',
                  'username': 'Robin',
                  'profileBadges': [
                    {'badge': 'FOUNDER'}
                  ]
                }
              }
            ]
          }
        }
      ]
    });
    expect(entry.allCompanions, isEmpty);
    expect(entry.groupCompanions.single.id, 'robin');
    expect(
        MovieWatchEntry.fromJson(entry.toJson())
            .groupCompanions
            .single
            .profileBadges,
        ['FOUNDER']);
  });
  test('logout clears diary and a late account response cannot restore it',
      () async {
    final auth = ProfileAuth(), service = DiaryData();
    service.pending['viewer'] = Completer();
    final c = ProfileDiaryController(auth: auth, service: service);
    final task = c.load();
    auth.select(null);
    service.pending['viewer']!.complete(fixtures);
    await task;
    expect(c.selection.days, isEmpty);
    expect(c.loaded, isFalse);
    c.dispose();
    auth.dispose();
  });
  test(
      'account switch and refresh errors preserve only the current viewer data',
      () async {
    final auth = ProfileAuth(), service = DiaryData();
    final c = ProfileDiaryController(auth: auth, service: service);
    await c.load();
    expect(c.selection.days, isNotEmpty);
    service.fail = true;
    await c.load(refresh: true);
    expect(c.failed, isTrue);
    expect(c.selection.days, isNotEmpty);
    auth.select('other');
    await Future<void>.delayed(Duration.zero);
    expect(c.selection.days, isEmpty);
    expect(c.failed, isTrue);
    c.dispose();
    auth.dispose();
  });
  testWidgets(
      'failed initial diary load can be retried without losing the route',
      (tester) async {
    final auth = ProfileAuth(), service = DiaryData()..fail = true;
    final c = ProfileDiaryController(auth: auth, service: service);
    await tester.pumpWidget(MaterialApp(
        home:
            ProfileDiaryScreen(controller: c, today: DateTime(2026, 10, 17))));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load your film diary.'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Alien'), findsNWidgets(2));
    expect(service.calls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    auth.dispose();
  });
  testWidgets('long companion names and movie titles wrap at doubled text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const entry = MovieWatchEntry(
      id: 'long',
      userId: 'viewer',
      movieId: 348,
      removed: false,
      movie: WatchlistMovieDetails(
          id: 348, title: 'A very long movie title for a memorable evening'),
      companions: [
        FriendshipUser(
            id: 'friend',
            username: 'averylongmoviefriend',
            profileBadges: ['FOUNDER'])
      ],
    );
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Scaffold(
          body: SingleChildScrollView(child: DiaryWatchEntry(entry: entry)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('averylongmoviefriend'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final view in [
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(360, 780), scale: 1.6),
    (size: const Size(820, 1000), scale: 1.0),
    (size: const Size(844, 390), scale: 1.0)
  ]) {
    testWidgets(
        'calendar jump, swipe, undated watches and badge borders ${view.size}',
        (tester) async {
      tester.view.physicalSize = view.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.binding.setSurfaceSize(view.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = ProfileAuth(), service = DiaryData();
      final c = ProfileDiaryController(auth: auth, service: service);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(view.scale)),
              child: child!),
          home: ProfileDiaryScreen(
              controller: c, today: DateTime(2026, 10, 17))));
      await tester.pumpAndSettle();
      expect(find.text('SPOILER MUST STAY HIDDEN'), findsNothing);
      expect(find.text('Cinema'), findsOneWidget);
      expect(
          tester
              .widgetList<ProfileAvatarView>(find.byType(ProfileAvatarView))
              .every((v) => v.profileBadges.contains('EARLY_ADOPTER')),
          isTrue);
      await tester.tap(find.byIcon(Icons.calendar_month_outlined).first);
      await tester.pumpAndSettle();
      expect(find.text('Find a memory'), findsOneWidget);
      await tester
          .ensureVisible(find.byKey(const ValueKey('diary-day-2026-10-23')));
      await tester.tap(find.byKey(const ValueKey('diary-day-2026-10-23')));
      await tester.pumpAndSettle();
      expect(find.text('Interstellar'), findsOneWidget);
      await tester.tap(find.text('Show this week'));
      await tester.pumpAndSettle();
      expect(find.text('Interstellar'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous week').first);
      await tester.pumpAndSettle();
      expect(find.text('Alien'), findsNWidgets(2));
      await tester.tap(find.text('Without a date (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Watches without a date'), findsOneWidget);
      auth.select(null);
      await tester.pumpAndSettle();
      expect(find.text('Alien'), findsNothing);
      expect(find.text('Sophie'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
      auth.dispose();
    });
  }
}
