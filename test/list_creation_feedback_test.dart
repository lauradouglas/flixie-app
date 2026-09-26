import 'dart:convert';
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
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth, child: const MaterialApp(home: MovieListsScreen())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New list').first);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'List name'), 'Weekend picks');
      await tester.ensureVisible(find.text('Create').last);
      await tester.tap(find.text('Create').last);
      await tester.pumpAndSettle();
      expect(created, true);
      expect(find.text('List created'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
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
