import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/widgets/watchlist_widget_sync.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watchlist_movie.dart';

User fixture(String id, List<WatchlistMovie> movies, {List<dynamic>? shows}) =>
    User(
        id: id,
        username: 'fixture',
        email: 'fixture@example.test',
        iconColorId: 1,
        completedSetup: true,
        darkMode: true,
        movieWatchlist: movies,
        showWatchlist: shows);
WatchlistMovie movie(int id, int day, {bool removed = false}) => WatchlistMovie(
    id: '$id',
    userId: 'fixture',
    movieId: id,
    removed: removed,
    createdAt: '2026-10-${day.toString().padLeft(2, '0')}',
    movie: WatchlistMovieDetails(
        id: id,
        title: [
          'The Odyssey',
          'Alien',
          'Spider-Man',
          'Obsession',
          'Interstellar',
          'Digger'
        ][(id - 1) % 6],
        posterPath: '/$id.jpg'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('wide widget selects four most recent active saves, including shows',
      () {
    final items = watchlistWidgetItems(fixture('a', [
      movie(1, 1),
      movie(2, 2),
      movie(3, 3),
      movie(4, 4),
      movie(5, 5),
      movie(6, 9, removed: true)
    ], shows: [
      {
        'showId': 8,
        'createdAt': '2026-10-08',
        'show': {'name': 'Alien series'}
      },
      {'showId': 9, 'watched': true, 'createdAt': '2026-10-09'},
    ]));
    expect(
        items.map((e) => e['id']), ['show-8', 'movie-5', 'movie-4', 'movie-3']);
    expect(items.first['title'], 'Alien series');
    expect(items.first['poster'], isNull);
    expect(watchlistWidgetItems(null), isEmpty);
  });
  test('removing and adding saves changes the actual widget snapshot', () {
    final before = fixture('a', [movie(1, 1), movie(2, 2)]);
    final after =
        fixture('a', [movie(1, 1), movie(2, 2, removed: true), movie(3, 3)]);
    expect(watchlistWidgetItems(before).first['id'], 'movie-2');
    expect(watchlistWidgetItems(after).map((e) => e['id']),
        ['movie-3', 'movie-1']);
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test(
        '${platform.name} sync deduplicates unchanged data, publishes new accounts and clears logout',
        () async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final calls = <Map<dynamic, dynamic>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(WatchlistWidgetSync.channel, (call) async {
        calls.add(call.arguments as Map);
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(WatchlistWidgetSync.channel, null));
      final sync = WatchlistWidgetSync();
      sync.sync(fixture('a', [movie(1, 1)]));
      sync.sync(fixture('a', [movie(1, 1)]));
      sync.sync(fixture('b', [movie(2, 2)]));
      sync.sync(null);
      await Future<void>.delayed(Duration.zero);
      expect(calls.length, 3);
      expect(calls[1]['account'], 'b');
      expect(calls.last, {'account': null, 'items': []});
    });
  }
}
