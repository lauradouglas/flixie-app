import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_list_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_lists_screen.dart';
import 'support/watchlist_auth.dart';

void main() {
  testWidgets('creating a list shows success feedback rather than an error',
      (tester) async {
    final auth = TestAuth();
    addTearDown(auth.dispose);
    var created = false;
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const MovieListsScreen()),
      GoRoute(
          path: '/movie-lists/:id',
          builder: (_, state) {
            expect(state.uri.queryParameters['add'], 'true');
            return MovieListDetailScreen(
              listId: state.pathParameters['id']!,
              listName: state.uri.queryParameters['name']!,
              addOnOpen: true,
            );
          }),
    ]);
    addTearDown(router.dispose);
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth, child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New list').first);
      await tester.pumpAndSettle();
      expect(find.text('Who can see it?'), findsOneWidget);
      expect(find.text('Who’s making it?'), findsOneWidget);
      await tester.tap(find.text('Public'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'List name'), 'Weekend picks');
      await tester.ensureVisible(find.text('Create').last);
      await tester.tap(find.text('Create').last);
      await tester.pumpAndSettle();
      expect(created, true);
      await tester.enterText(
          find.widgetWithText(TextField, 'Search movies or shows'), 'Alien');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InkWell, 'Alien'), findsOneWidget);
      expect(find.text('Alien: Earth'), findsOneWidget);
      expect(find.text('Add to Weekend picks'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Search movies or shows'),
          findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/search')) {
                expect(request.url.queryParameters['type'], 'all');
                return http.Response(
                    jsonEncode({
                      'results': [
                        {'id': 348, 'name': 'Alien', 'media_type': 'movie'},
                        {'id': 348, 'name': 'Alien: Earth', 'media_type': 'tv'},
                      ]
                    }),
                    200);
              }
              if (request.method == 'POST') {
                expect(jsonDecode(request.body)['visibility'], 'PUBLIC');
                created = true;
                return http.Response(
                    jsonEncode({
                      'id': 'new',
                      'userId': 'viewer',
                      'name': 'Weekend picks',
                      'removed': false
                    }),
                    201);
              }
              if (request.url.path.endsWith('/lists'))
                return http.Response(
                    jsonEncode([
                      {
                        'id': 'existing',
                        'userId': 'viewer',
                        'name': 'Existing list',
                        'removed': false
                      }
                    ]),
                    200);
              if (request.url.path.contains('friends'))
                return http.Response(
                    jsonEncode({
                      'friendships': [],
                      'pendingFriends': [],
                      'requestedFriends': []
                    }),
                    200);
              return http.Response('[]', 200);
            }));
  });
}
