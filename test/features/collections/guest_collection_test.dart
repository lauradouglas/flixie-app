import 'package:flixie_app/features/collections/collection_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/collections/movie_collection_card.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';

class GuestAuth extends ChangeNotifier implements AuthProvider {
  @override
  User? get dbUser => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets(
      'guest collection 401 renders retry without refreshing an absent user',
      (tester) async {
    var refreshes = 0, requests = 0;
    ApiClient.setToken(null);
    ApiClient.setAuthTokenRefresher(() async {
      refreshes++;
      throw StateError('no current user');
    });
    final client = MockClient((request) async {
      requests++;
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response('Please sign in again to continue.', 401);
    });
    ApiClient.useClientForTesting(client);
    addTearDown(() {
      ApiClient.useClientForTesting(null);
      ApiClient.setAuthTokenRefresher(null);
      ApiClient.setToken(null);
      client.close();
    });
    await tester.pumpWidget(
        const MaterialApp(home: CollectionScreen(collectionId: 531241)));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load this collection.'), findsOneWidget);
    expect(refreshes, 0);
    expect(requests, 1);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(refreshes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'guests open catalogue freely and only track progress prompts signup',
      (tester) async {
    final reads = <String>[];
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      reads.add(request.url.path);
      return http.Response(
          jsonEncode({
            'name': 'Alien Collection',
            'overview': 'A journey through the Alien films.',
            'films': [
              {'id': 348, 'title': 'Alien', 'releaseDate': '1979-05-25'},
              {'id': 679, 'title': 'Aliens', 'releaseDate': '1986-07-18'},
            ]
          }),
          200);
    });
    ApiClient.useClientForTesting(client);
    final auth = GuestAuth();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
              body: MovieCollectionCard(
                  collection: {'id': 8091, 'name': 'Alien Collection'})))
    ]);
    addTearDown(() {
      ApiClient.useClientForTesting(null);
      client.close();
      router.dispose();
      auth.dispose();
      GuestAccess.clear();
    });
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth, child: MaterialApp.router(routerConfig: router)));
    await tester.tap(find.text('Alien Collection'));
    await tester.pumpAndSettle();
    expect(reads, ['/movies/collections/8091']);
    expect(find.text('A journey through the Alien films.'), findsOneWidget);
    expect(find.text('Alien'), findsOneWidget);
    expect(find.text('Aliens'), findsOneWidget);
    expect(find.text('Your progress'), findsNothing);
    expect(find.text('Not watched'), findsNothing);
    expect(find.text('Plan with friends'), findsNothing);
    expect(find.text('Create account'), findsNothing);
    await tester.ensureVisible(find.text('Track progress'));
    await tester.tap(find.text('Track progress'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Track your collection progress'), findsOneWidget);
    expect(reads, hasLength(1));
    expect(GuestAccess.isPublicPath('/collections/8091'), isTrue);
    expect(tester.takeException(), isNull);
  });
}
