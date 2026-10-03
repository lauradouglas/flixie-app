import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/presentation/pages/profile_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'support/watchlist_auth.dart';

class _Auth extends TestAuth {
  @override
  int get unreadNotificationCount => 0;
}

void main() {
  testWidgets(
      'Profile shows a combined viewing once and keeps the Ratings filter usable',
      (tester) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const ProfileScreen())
    ]);
    addTearDown(router.dispose);
    final filters = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth, child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Activity').first, 250,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Activity').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Alien'), 150,
          scrollable: find.byType(Scrollable).first);
      expect(find.byType(ActivityTile), findsOneWidget);
      expect(find.text('Watched and rated'), findsOneWidget);
      expect(find.text('★ 9/10'), findsOneWidget);
      expect(find.text('Rated'), findsNothing);
      await Scrollable.ensureVisible(tester.element(find.text('Ratings')),
          alignment: 0.3);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ratings'));
      await tester.pumpAndSettle();
      expect(filters.last, 'ratings');
      expect(find.byType(ActivityTile), findsOneWidget);
      expect(find.text('Rated'), findsOneWidget);
      expect(find.text('★ 9/10'), findsOneWidget);
    },
        () => MockClient((request) async {
              Object data = [];
              if (request.url.path.endsWith('/activity')) {
                final filter = request.url.queryParameters['filter'] ?? 'all';
                filters.add(filter);
                data = {
                  'items': [
                    {
                      'id': filter == 'ratings' ? 'rating-1' : 'watch-1',
                      'watchEntryId': 'watch-1',
                      'userId': 'viewer',
                      'username': 'Me',
                      'type': filter == 'ratings'
                          ? 'movie_rating'
                          : 'watched_movie',
                      'watchLogged': filter != 'ratings',
                      'movieId': 348,
                      'rating': 9,
                      'createdAt': '2026-10-02T12:00:00Z',
                      'watchedAt': '2026-10-02T12:00:00Z',
                      'movie': {'id': 348, 'title': 'Alien'},
                    }
                  ],
                  'nextCursor': null
                };
              }
              if (request.url.path.startsWith('/friends/')) {
                data = {
                  'friendships': [],
                  'requestedFriends': [],
                  'pendingFriends': []
                };
              }
              return http.Response(jsonEncode(data), 200);
            }));
  });
}
