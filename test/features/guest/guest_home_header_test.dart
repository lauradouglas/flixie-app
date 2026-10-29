import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/guest/presentation/guest_home_screen.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/watchlist/data/guest_watchlist_store.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import 'package:flixie_app/features/home/data/home_data_service.dart';
import '../../support/api_fixture.dart';

void main() {
  testWidgets(
      'header signup preserves a local pick and Home requests film trending',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final paths = <String>[];
    useApiFixture(MockClient((r) async {
      paths.add(r.url.path);
      return http.Response(
          jsonEncode(r.url.path == '/guest/home'
              ? {'communities': []}
              : r.url.path.startsWith('/trending/')
                  ? [
                      {'id': 348, 'title': 'Alien', 'mediaType': 'MOVIE'},
                      {'id': 1396, 'name': 'Breaking Bad', 'mediaType': 'SHOW'}
                    ]
                  : []),
          200);
    }));
    await GuestWatchlistStore.instance
        .toggle(const SetupTitle(348, 'Alien', null));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const GuestHomeScreen()),
      GoRoute(
          path: '/auth/signup',
          builder: (_, __) => const Scaffold(body: Text('Account setup'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Join free').hitTestable(), findsOneWidget);
    expect(find.text('Sign in').hitTestable(), findsOneWidget);
    expect(find.text('Your watchlist · 1 pick'), findsOneWidget);
    expect(find.text('Saved on this device'), findsOneWidget);
    expect(paths, contains('/trending/movie/day'));
    expect(
        paths.any((p) =>
            p.contains('/trending/all/') || p.contains('/trending/show/')),
        isFalse);
    await tester.tap(find.text('Join free'));
    await tester.pumpAndSettle();
    expect(find.text('Account setup'), findsOneWidget);
    expect(GuestAccess.action, 'guest-watchlist');
    expect(await GuestWatchlistStore.instance.read(), hasLength(1));
    GuestAccess.clear();
    paths.clear();
    final films = await const HomeDataService().trending(refresh: true);
    expect(films.map((film) => film.id), [348]);
    expect(films.any((film) => film.isShow), isFalse);
    expect(paths, ['/trending/movie/day']);
  });
}
