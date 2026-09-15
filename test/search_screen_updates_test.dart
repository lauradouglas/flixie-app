import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/presentation/pages/search_screen.dart';
import 'home_startup_recovery_test.dart' show Session;
import 'auth_recovery_test.dart' show profile;

void main() {
  testWidgets(
      'short mixed search preserves order, pages and keeps device history',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'device_recent_searches_v1': ['Dune']
    });
    final session = Session();
    final auth = AuthProvider(session, MovieService(),
        prefetchAfterAuth: false, profileLoader: (id) async => profile(id));
    final calls = <String>[];
    final oldResponse = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: auth, child: const MaterialApp(home: SearchScreen())));
      await tester.pumpAndSettle();
      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.text('Dune'), findsOneWidget);
      expect(find.text('Browse by'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Up');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Up show'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Up show')).dy,
          lessThan(tester.getTopLeft(find.text('Up movie')).dy));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Page two'), findsOneWidget);
      expect(calls, contains('Up:2'));
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Up'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('device_recent_searches_v1'), ['Up', 'Dune']);
      await tester.tap(find.byTooltip('Remove Dune from recent searches'));
      await tester.pumpAndSettle();
      expect(prefs.getStringList('device_recent_searches_v1'), ['Up']);
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(prefs.getStringList('device_recent_searches_v1'), isEmpty);
      await tester.enterText(find.byType(TextField), 'Older query');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byType(TextField), 'New query');
      oldResponse.complete(http.Response(
          jsonEncode({
            'page': 1,
            'results': [
              {'id': 99, 'title': 'Stale title'}
            ]
          }),
          200));
      await tester.pump();
      expect(find.text('Stale title'), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Stale title'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.contains('/search')) {
                if (request.url.queryParameters['value'] == 'Older query') {
                  return oldResponse.future;
                }
                final page = request.url.queryParameters['page'];
                calls.add('${request.url.queryParameters['value']}:$page');
                return http.Response(
                    jsonEncode({
                      'page': int.parse(page!),
                      'totalPages': 2,
                      'totalResults': 3,
                      'results': page == '1'
                          ? [
                              {
                                'id': 1,
                                'media_type': 'tv',
                                'name': 'Up show',
                                'popularity': 1
                              },
                              {
                                'id': 2,
                                'media_type': 'movie',
                                'title': 'Up movie',
                                'popularity': 100
                              },
                            ]
                          : [
                              {
                                'id': 3,
                                'media_type': 'movie',
                                'title': 'Page two'
                              }
                            ]
                    }),
                    200);
              }
              return http.Response('[]', 200);
            }));
    auth.dispose();
    await session.events.close();
  });
}
