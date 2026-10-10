import 'package:flixie_app/core/utils/skeleton.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/pages/show_detail_screen.dart';
import 'support/watchlist_auth.dart';

void main() {
  testWidgets(
      'card preview then summary render before full show or optional sections',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = TestAuth();
    final summary = Completer<http.Response>();
    final full = Completer<http.Response>();
    final credits = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.url.path == '/shows/id/101') {
        if (request.url.queryParameters['summary'] != 'true') {
          expect(request.url.queryParameters['includeFriendSummary'], 'false');
          expect(request.url.queryParameters['includeTrailers'], 'false');
        }
        return request.url.queryParameters['summary'] == 'true'
            ? summary.future
            : full.future;
      }
      if (request.url.path.endsWith('/credits')) return credits.future;
      if (request.url.path.contains('friend')) return http.Response('{}', 200);
      if (request.url.path.contains('rating')) {
        return http.Response('null', 200);
      }
      return http.Response('[]', 200);
    });
    ApiClient.useClientForTesting(client);
    addTearDown(() {
      ApiClient.useClientForTesting(null);
      client.close();
      auth.dispose();
    });
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(
            home:
                ShowDetailScreen(showId: '101', initialTitle: 'Card title'))));
    expect(find.text('Card title'), findsOneWidget);
    expect(find.byType(MediaDetailPreview), findsOneWidget);
    await tester.pump();
    summary.complete(http.Response(
        jsonEncode({
          'id': 101,
          'name': 'Fixture show',
          'overview': 'A story available immediately',
          'numberOfEpisodes': 8
        }),
        200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Fixture show'), findsWidgets);
    expect(find.byType(MediaDetailPreview), findsNothing);
    expect(full.isCompleted, false);
    expect(credits.isCompleted, false);
    credits.complete(http.Response('{"message":"Unavailable"}', 503));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Fixture show'), findsWidgets);
    expect(find.text('Some details couldn’t load.'), findsOneWidget);
    full.complete(http.Response(
        jsonEncode({
          'id': 101,
          'name': 'Complete show',
          'overview': 'All details arrived',
          'seasons': []
        }),
        200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Complete show'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('late public summary cannot replace complete show data',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = TestAuth();
    final summary = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.url.path == '/shows/id/102') {
        if (request.url.queryParameters['summary'] == 'true') {
          return summary.future;
        }
        return http.Response(
            jsonEncode({'id': 102, 'name': 'Complete title'}), 200);
      }
      if (request.url.path.contains('friend')) return http.Response('{}', 200);
      if (request.url.path.contains('rating')) {
        return http.Response('null', 200);
      }
      return http.Response('[]', 200);
    });
    ApiClient.useClientForTesting(client);
    addTearDown(() {
      ApiClient.useClientForTesting(null);
      client.close();
      auth.dispose();
    });
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: ShowDetailScreen(showId: '102'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Complete title'), findsWidgets);
    summary.complete(
        http.Response(jsonEncode({'id': 102, 'name': 'Older summary'}), 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Complete title'), findsWidgets);
    expect(find.text('Older summary'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'refresh retains complete show while summary and full response arrive',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = TestAuth();
    var refreshing = false;
    final fullRefresh = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.url.path == '/shows/id/103') {
        if (refreshing && request.url.queryParameters['summary'] != 'true') {
          return fullRefresh.future;
        }
        return http.Response(
            jsonEncode({
              'id': 103,
              'name': refreshing ? 'Basic summary' : 'Complete show',
              'overview': 'Already available',
              'seasons': []
            }),
            200);
      }
      if (request.url.path.contains('friend')) return http.Response('{}', 200);
      if (request.url.path.contains('rating')) {
        return http.Response('null', 200);
      }
      return http.Response('[]', 200);
    });
    ApiClient.useClientForTesting(client);
    addTearDown(() {
      ApiClient.useClientForTesting(null);
      client.close();
      auth.dispose();
    });
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: ShowDetailScreen(showId: '103'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Complete show'), findsWidgets);
    refreshing = true;
    final pending = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Complete show'), findsWidgets);
    expect(find.text('Basic summary'), findsNothing);
    expect(find.byType(ContentPlaceholder), findsNothing);
    fullRefresh.complete(http.Response(
        jsonEncode({'id': 103, 'name': 'Updated full show', 'seasons': []}),
        200));
    await pending;
    await tester.pump();
    expect(find.text('Updated full show'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
