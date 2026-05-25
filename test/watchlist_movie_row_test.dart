import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/screens/watchlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

WatchlistMovie _sampleWatchlistMovie() {
  return const WatchlistMovie(
    id: 'watchlist-1',
    userId: 'me',
    movieId: 42,
    createdAt: '2026-05-25T10:15:00.000Z',
    movie: WatchlistMovieDetails(
      id: 42,
      title: 'Interstellar',
      releaseDate: '2026-01-01',
      runtime: 132,
      voteAverage: 8.7,
    ),
  );
}

Finder _textContaining(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && (widget.data?.contains(text) ?? false),
  );
}

void main() {
  group('WatchlistMovieRow', () {
    testWidgets('shows Added date and removes Added by friend label',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          WatchlistMovieRow(
            watchlistItem: _sampleWatchlistMovie(),
            isWatched: false,
            onTap: () {},
            onMarkAsWatched: () {},
            onRemove: () {},
          ),
        ),
      );

      expect(_textContaining('Added 25 May 2026'), findsOneWidget);
      expect(_textContaining('Added by'), findsNothing);
    });

    testWidgets('bookmark toggle removes movie from watchlist', (tester) async {
      var removed = false;

      await tester.pumpWidget(
        _wrap(
          WatchlistMovieRow(
            watchlistItem: _sampleWatchlistMovie(),
            isWatched: false,
            onTap: () {},
            onMarkAsWatched: () {},
            onRemove: () => removed = true,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Remove from watchlist'));
      await tester.pump();

      expect(removed, isTrue);
    });

    testWidgets('overflow menu includes expanded quick actions', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WatchlistMovieRow(
            watchlistItem: _sampleWatchlistMovie(),
            isWatched: false,
            onTap: () {},
            onMarkAsWatched: () {},
            onRemove: () {},
          ),
        ),
      );

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      expect(find.text('Mark as Watched'), findsOneWidget);
      expect(find.text('Add to favourites'), findsOneWidget);
      expect(find.text('Add to list'), findsOneWidget);
      expect(find.text('Invite friends'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });
  });
}
