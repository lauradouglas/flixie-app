import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_library_totals.dart';

void main() {
  patrolTest('profile totals reuse existing destinations', ($) async {
    final user = User.fromJson({
      'id': 'isolated-fixture',
      'username': 'Fixture',
      'watchedMovies': [
        {
          'id': 'w',
          'movieId': 1,
          'movie': {'title': 'Watched film'}
        }
      ],
      'watchedShows': [
        {
          'showId': 2,
          'show': {'name': 'Watched show'}
        }
      ],
      'movieWatchlist': [
        {
          'id': 'l',
          'movieId': 3,
          'movie': {'title': 'Saved film'}
        }
      ],
      'showWatchlist': [
        {
          'showId': 4,
          'show': {'name': 'Saved show'}
        }
      ],
      'favoriteMovies': [
        {
          'id': 'f',
          'userId': 'isolated-fixture',
          'movieId': 5,
          'movie': {'title': 'Favourite film'}
        }
      ],
      'favoriteShows': [
        {
          'showId': 6,
          'show': {'name': 'Favourite show'}
        }
      ],
    });
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
              body: SafeArea(child: ProfileLibraryTotals(user: user)))),
      for (final path in ['/watchlist', '/watch-history'])
        GoRoute(
            path: path,
            builder: (_, __) =>
                Scaffold(body: SafeArea(child: Text('Destination $path')))),
    ]);
    await $.pumpWidgetAndSettle(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
    for (final (key, path) in [
      ('watched', '/watch-history'),
      ('watchlist', '/watchlist'),
    ]) {
      await $(find.byKey(ValueKey('profile-total-$key'))).tap();
      await $('Destination $path').waitUntilVisible();
      expect(find.byType(BottomSheet), findsNothing);
      router.go('/');
      await $.pumpAndSettle();
    }
    await $(find.byKey(const ValueKey('profile-total-favourites'))).tap();
    await $('Favourite movies').waitUntilVisible();
    await $('Favourite film').waitUntilVisible();
    expect(find.byType(TabBar), findsNothing);
    await $(find.byTooltip('Close')).tap();
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $(find.byKey(const ValueKey('profile-total-watched')))
        .waitUntilVisible();
  });
}
