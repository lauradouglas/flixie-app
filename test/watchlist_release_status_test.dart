import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/features/watchlist/domain/release_status.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import 'watchlist_screen_states_test.dart' show ScreenAuth, handle;

class ReleaseAuth extends ScreenAuth {
  @override
  User get dbUser => super.dbUser.copyWith(movieWatchlist: [
        for (final (id, title, date) in [
          (1, 'Released film', '2020-01-01'),
          (2, 'Future film', '2099-12-31'),
          (4, 'Undated film', null),
        ])
          WatchlistMovie(
              id: '$id',
              userId: 'viewer',
              movieId: id,
              movie: WatchlistMovieDetails(
                  id: id, title: title, releaseDate: date)),
      ], showWatchlist: [
        {
          'showId': 3,
          'show': {
            'id': 3,
            'title': 'Future show',
            'firstAirDate': '2099-12-31',
            'numberOfSeasons': 1
          }
        }
      ]);
}

class OrderedReleaseAuth extends ReleaseAuth {
  @override
  User get dbUser => super.dbUser.copyWith(movieWatchlist: [
        for (final (id, title, date) in [
          (1, 'Latest movie', '2099-12-31'),
          (2, 'Soonest movie', '2099-01-01'),
          (4, 'Middle movie', '2099-06-01'),
        ])
          WatchlistMovie(
              id: '$id',
              userId: 'viewer',
              movieId: id,
              movie: WatchlistMovieDetails(
                  id: id, title: title, releaseDate: date)),
      ], showWatchlist: [
        {
          'showId': 3,
          'show': {
            'id': 3,
            'title': 'Soonest show',
            'firstAirDate': '2098-12-01',
            'numberOfSeasons': 1
          }
        },
      ]);
}

void main() {
  testWidgets(
      'coming soon sorts by release date across media and movie-only views',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = OrderedReleaseAuth();
    addTearDown(auth.dispose);
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: AppTheme.darkTheme, home: const WatchlistScreen())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coming soon').first);
      await tester.pumpAndSettle();
      List<String> titles() => tester
          .widgetList<WatchlistMovieRow>(find.byType(WatchlistMovieRow))
          .map((row) => row.watchlistItem.movie!.title)
          .toList();
      expect(titles(),
          ['Soonest show', 'Soonest movie', 'Middle movie', 'Latest movie']);
      expect(find.text('Soonest first · 4'), findsOneWidget);
      await tester.tap(find.text('Movies'));
      await tester.pumpAndSettle();
      expect(titles(), ['Soonest movie', 'Middle movie', 'Latest movie']);
      await tester.tap(find.text('All releases'));
      await tester.pumpAndSettle();
      expect(titles(), ['Latest movie', 'Soonest movie', 'Middle movie']);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) async => handle(request)));
  });

  test('release status uses calendar days and keeps unknown dates separate',
      () {
    final today = DateTime(2026, 9, 19, 15);
    expect(releaseStatus('2026-09-19', now: today), ReleaseStatus.outNow);
    expect(releaseStatus('2026-09-18', now: today), ReleaseStatus.outNow);
    expect(releaseStatus('2026-09-20', now: today), ReleaseStatus.comingSoon);
    for (final value in [null, '', '2027', 'bad', '2026-02-30']) {
      expect(releaseStatus(value, now: today), ReleaseStatus.unknown);
    }
  });

  testWidgets(
      'release filters include movies and shows and reset without losing titles',
      (tester) async {
    final auth = ReleaseAuth();
    addTearDown(auth.dispose);
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: AppTheme.darkTheme, home: const WatchlistScreen())));
      await tester.pumpAndSettle();
      Future<void> choose(String label) async {
        final target = find.text(label).first;
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await choose('Out now');
      expect(find.text('Released film'), findsOneWidget);
      expect(find.text('Future film'), findsNothing);
      expect(find.text('Undated film'), findsNothing);
      await choose('Coming soon');
      expect(find.text('Released film'), findsNothing);
      expect(find.text('Future film'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Future show'), 180,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('Future show'), findsOneWidget);
      expect(find.text('Releases 31 Dec 2099'), findsWidgets);
      await choose('All releases');
      await tester.scrollUntilVisible(find.text('Undated film'), 180,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('Undated film'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) async => handle(request)));
  });

  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(844, 390),
    const Size(1024, 768)
  ]) {
    testWidgets('upcoming card wraps at $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = ReleaseAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
              data: MediaQueryData(
                  size: size, textScaler: const TextScaler.linear(2)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: WatchlistMovieRow(
                watchlistItem: auth.dbUser.movieWatchlist![1],
                isWatched: false,
                onTap: () {},
                onMarkAsWatched: () {},
                onRemove: () {},
              ))))));
      await tester.pumpAndSettle();
      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text('Releases 31 Dec 2099'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
