import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/features/movies/presentation/pages/search_screen.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  List<MovieShort> get cachedTrending => [];
  @override
  int get unreadNotificationCount => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

http.Response response(Object data) => http.Response(jsonEncode(data), 200,
    headers: {'content-type': 'application/json'});
void main() {
  testWidgets(
      'debounce, submission, newer searches and clearing retain stale-response protection',
      (tester) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    final pending = <String, Completer<http.Response>>{};
    final calls = <String>[];
    void complete(String query) {
      for (final type in ['all']) {
        pending['$query/$type']!.complete(response({
          'page': 1,
          'totalPages': 1,
          'totalResults': 1,
          'results': type == 'tv'
              ? []
              : [
                  {
                    'id': query.hashCode.abs(),
                    'media_type': 'movie',
                    'title': '$query result'
                  }
                ]
        }));
      }
    }

    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth, child: const MaterialApp(home: SearchScreen())));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 399));
      expect(calls, isEmpty);
      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.pump(const Duration(milliseconds: 399));
      expect(calls, isEmpty);
      await tester.enterText(find.byType(TextField), 'beta');
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls.toSet(), {'beta/all'});
      await tester.enterText(find.byType(TextField), 'gamma');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(calls.length, 2);
      complete('gamma');
      await tester.pumpAndSettle();
      expect(find.text('gamma result', findRichText: true), findsWidgets);
      complete('beta');
      await tester.pumpAndSettle();
      expect(find.text('beta result', findRichText: true), findsNothing);
      expect(find.text('gamma result', findRichText: true), findsWidgets);
      expect(calls.length, 2, reason: 'submission cancels its debounce');
      await tester.enterText(find.byType(TextField), 'delta');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      complete('delta');
      await tester.pumpAndSettle();
      expect(find.text('delta result', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.contains('/trending/')) return response([]);
              final key =
                  '${request.url.queryParameters['value']}/${request.url.queryParameters['type']}';
              calls.add(key);
              final future = Completer<http.Response>();
              pending[key] = future;
              return await future.future;
            }));
  });
}
