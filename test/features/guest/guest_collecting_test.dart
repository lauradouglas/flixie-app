import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/guest/presentation/guest_home_screen.dart';
import 'package:flixie_app/features/watchlist/data/guest_watchlist_store.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/guest_watchlist_page.dart';
import 'guest_router_test.dart' show GuestAuth;
import '../../support/api_fixture.dart';

Future<void> guestCollectingJourney(WidgetTester tester,
    {Future<void> Function(String)? capture, String? artworkHost}) async {
  SharedPreferences.setMockInitialValues({});
  GuestAccess.clear();
  final auth = GuestAuth();
  final requests = <String>[];
  useApiFixture(MockClient((r) async {
    requests.add(r.method);
    return http.Response(
        jsonEncode(r.url.path == '/guest/home'
            ? {'communities': []}
            : artworkHost == null
                ? []
                : [
                    {
                      'id': 348,
                      'name': 'Alien',
                      'title': 'Alien',
                      'mediaType': 'MOVIE',
                      'posterPath': '$artworkHost/assets/alien.jpg',
                      'poster': '$artworkHost/assets/alien.jpg',
                      'releaseDate': '1979-05-25'
                    },
                    {
                      'id': 1396,
                      'name': 'Breaking Bad',
                      'title': 'Breaking Bad',
                      'mediaType': 'SHOW',
                      'posterPath': '$artworkHost/assets/breaking-bad.jpg',
                      'poster': '$artworkHost/assets/breaking-bad.jpg'
                    }
                  ]),
        200);
  }));
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const GuestHomeScreen()),
    GoRoute(
        path: '/guest-watchlist',
        builder: (_, __) => const GuestWatchlistPage()),
    GoRoute(
        path: '/search',
        builder: (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Catalogue fixture')),
            body: ListView(children: [
              for (final entry in [
                ('movies', 348, 'Alien'),
                ('shows', 348, 'Alien: Earth'),
                ('movies', 157336, 'Interstellar'),
                ('movies', 557, 'Spider-Man')
              ])
                ListTile(
                    title: Text(entry.$3),
                    onTap: () => context.push('/${entry.$1}/${entry.$2}'),
                    trailing: IconButton(
                        tooltip: 'Save ${entry.$3}',
                        icon: const Icon(Icons.bookmark_add_outlined),
                        onPressed: () => GuestAccess.require(context,
                            path: '/${entry.$1}/${entry.$2}',
                            intent: 'watchlist',
                            mediaTitle: entry.$3,
                            mediaPoster: artworkHost == null
                                ? null
                                : '$artworkHost/assets/${entry.$3 == 'Interstellar' ? 'interstellar' : entry.$3 == 'Spider-Man' ? 'spider-man' : 'alien'}.jpg'))),
            ]))),
    GoRoute(
        path: '/movies/:id',
        builder: (_, __) => Scaffold(
            appBar: AppBar(), body: const Text('Film details fixture'))),
    GoRoute(
        path: '/shows/:id',
        builder: (_, __) => Scaffold(
            appBar: AppBar(), body: const Text('Show details fixture'))),
  ]);
  addTearDown(auth.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child:
          MaterialApp.router(routerConfig: router, theme: AppTheme.darkTheme)));
  await tester.pumpAndSettle();
  expect(
      find.text(
          'Find films and shows. Save your next watch.\nNo account needed.'),
      findsOneWidget);
  await capture?.call('home');
  await tester.tap(find.text('Search films, shows and people'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Alien'));
  await tester.pumpAndSettle();
  expect(find.text('Film details fixture'), findsOneWidget);
  router.pop();
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Save Alien'));
  await tester.pumpAndSettle();
  expect(find.text('Added to your watchlist'), findsOneWidget);
  await tester.tap(find.text('Keep browsing'));
  await tester.pumpAndSettle();
  for (final title in ['Alien: Earth', 'Interstellar', 'Spider-Man']) {
    await tester.tap(find.byTooltip('Save $title'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(GuestAccess.awaitingAccount, isFalse);
  }
  expect(await GuestWatchlistStore.instance.read(), hasLength(4));
  await tester.tap(find.text('View watchlist'));
  await tester.pumpAndSettle();
  expect(find.text('Already feels like you.'), findsOneWidget);
  await tester.scrollUntilVisible(find.text('TV show'), 160);
  expect(find.text('TV show'), findsOneWidget);
  await capture?.call('watchlist');
  await tester.scrollUntilVisible(
      find.text('Create account & keep my picks'), -160);
  expect(find.text('Create account & keep my picks'), findsOneWidget);
  await tester.scrollUntilVisible(find.text('Alien: Earth').hitTestable(), 160);
  await tester.tap(find.text('Alien: Earth'));
  await tester.pumpAndSettle();
  expect(find.text('Show details fixture'), findsOneWidget);
  expect(requests.every((method) => method == 'GET'), isTrue);
  expect(tester.takeException(), isNull);
  if (capture != null) {
    router.go('/');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dear film diary,'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await capture('diary');
  }
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets(
      'guests inspect films/shows and collect more than two without signup',
      guestCollectingJourney);
  testWidgets(
      'community failure leaves trending, cinema and browsing available',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    var communityReads = 0, trendingReads = 0;
    useApiFixture(MockClient((r) async {
      if (r.url.path == '/guest/home') {
        communityReads++;
        return http.Response('{"message":"Unavailable"}', 503);
      }
      trendingReads++;
      return http.Response('[]', 200);
    }));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const GuestHomeScreen())
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: AppTheme.darkTheme));
    await tester.pumpAndSettle();
    expect(find.text('More titles will appear here soon.'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Couldn’t load communities. Retry'), 500,
        scrollable: find.byType(Scrollable).first);
    final catalogueReads = trendingReads;
    await tester.tap(find.text('Couldn’t load communities. Retry'));
    await tester.pumpAndSettle();
    expect(communityReads, 2);
    expect(trendingReads, catalogueReads);
    await tester.scrollUntilVisible(find.text('Create free account'), -300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Create free account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
