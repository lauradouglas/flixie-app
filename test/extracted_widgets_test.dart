// Tests for widgets extracted during the architecture refactor.
// These cover the key reusable components that were split out from large screen
// files, providing regression protection for the extraction.

import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/screens/movie_detail/action_button.dart';
import 'package:flixie_app/screens/movie_detail/film_info_card.dart';
import 'package:flixie_app/screens/profile/friend_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  // ── FriendAvatar ───────────────────────────────────────────────────────────

  group('FriendAvatar', () {
    testWidgets('renders username initial when no initials field',
        (tester) async {
      const user = FriendshipUser(id: '1', username: 'alice');
      await tester.pumpWidget(_wrap(const FriendAvatar(user: user)));

      expect(find.text('A'), findsOneWidget);
      expect(find.text('alice'), findsOneWidget);
    });

    testWidgets('uses initials field when provided', (tester) async {
      const user = FriendshipUser(id: '2', username: 'bob', initials: 'BK');
      await tester.pumpWidget(_wrap(const FriendAvatar(user: user)));

      expect(find.text('BK'), findsOneWidget);
    });

    testWidgets('renders ? for empty username with no initials', (tester) async {
      const user = FriendshipUser(id: '3', username: '');
      await tester.pumpWidget(_wrap(const FriendAvatar(user: user)));

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('applies custom hex icon color', (tester) async {
      const user = FriendshipUser(
        id: '4',
        username: 'cleo',
        iconColor: {'hexCode': '#FF0000'},
      );
      // Just verify widget renders without error — colour logic covered by unit test
      await tester.pumpWidget(_wrap(const FriendAvatar(user: user)));
      expect(find.text('C'), findsOneWidget);
    });
  });

  // ── FilmInfoCard ──────────────────────────────────────────────────────────

  group('FilmInfoCard', () {
    const _movie = Movie(id: 1, title: 'Test Movie');

    testWidgets('renders nothing when all fields empty', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FilmInfoCard(
            director: null,
            writers: [],
            producers: [],
            movie: _movie,
          ),
        ),
      );
      // The card should not render any content rows
      expect(find.text('DIRECTOR'), findsNothing);
    });

    testWidgets('renders director row when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FilmInfoCard(
            director: 'Christopher Nolan',
            writers: [],
            producers: [],
            movie: _movie,
          ),
        ),
      );
      expect(find.text('DIRECTOR'), findsOneWidget);
      expect(find.text('Christopher Nolan'), findsOneWidget);
    });

    testWidgets('renders singular Writer label for one writer', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FilmInfoCard(
            director: null,
            writers: ['Jane Doe'],
            producers: [],
            movie: _movie,
          ),
        ),
      );
      expect(find.text('WRITER'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
    });

    testWidgets('renders plural Writers label for multiple writers',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FilmInfoCard(
            director: null,
            writers: ['Jane Doe', 'John Smith'],
            producers: [],
            movie: _movie,
          ),
        ),
      );
      expect(find.text('WRITERS'), findsOneWidget);
    });

    testWidgets('renders budget when present', (tester) async {
      const movieWithBudget = Movie(id: 2, title: 'Big Budget', budget: 150000000);
      await tester.pumpWidget(
        _wrap(
          const FilmInfoCard(
            director: null,
            writers: [],
            producers: [],
            movie: movieWithBudget,
          ),
        ),
      );
      expect(find.text('BUDGET'), findsOneWidget);
      expect(find.text('\$150M'), findsOneWidget);
    });

    testWidgets('renders collection when present', (tester) async {
      const movieWithCollection = Movie(
        id: 3,
        title: 'Avengers',
        collection: {'name': 'Avengers Collection'},
      );
      await tester.pumpWidget(
        _wrap(
          const FilmInfoCard(
            director: null,
            writers: [],
            producers: [],
            movie: movieWithCollection,
          ),
        ),
      );
      expect(find.text('COLLECTION'), findsOneWidget);
      expect(find.text('Avengers Collection'), findsOneWidget);
    });
  });

  // ── MovieActionButton ─────────────────────────────────────────────────────

  group('MovieActionButton', () {
    testWidgets('renders label and icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Row(
            children: [
              Expanded(
                child: MovieActionButton(
                  icon: Icons.bookmark_outline,
                  label: 'Watchlist',
                  isActive: false,
                  color: Colors.amber,
                  isLoading: false,
                  bounceKey: 0,
                  onPressed: null,
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Watchlist'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator when loading', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Row(
            children: [
              Expanded(
                child: MovieActionButton(
                  icon: Icons.check_circle_outline,
                  label: 'Watched',
                  isActive: false,
                  color: Colors.green,
                  isLoading: true,
                  bounceKey: 0,
                  onPressed: null,
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped and not loading', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          Row(
            children: [
              Expanded(
                child: MovieActionButton(
                  icon: Icons.favorite_outline,
                  label: 'Favourite',
                  isActive: false,
                  color: Colors.red,
                  isLoading: false,
                  bounceKey: 0,
                  onPressed: () => tapped = true,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(OutlinedButton));
      expect(tapped, isTrue);
    });
  });
}
