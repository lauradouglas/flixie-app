import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_library_totals.dart';

final libraryUser = User.fromJson({
  'id': 'fixture',
  'username': 'Fixture',
  'watchedMovies': [
    {
      'id': 'w',
      'movieId': 1,
      'movie': {'title': 'Watched movie'}
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
      'movie': {'title': 'Saved movie'}
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
      'userId': 'fixture',
      'movieId': 5,
      'movie': {'title': 'Favourite movie'}
    },
    {'id': 'removed', 'userId': 'fixture', 'movieId': 99, 'removed': true}
  ],
  'favoriteShows': [
    {
      'showId': 6,
      'show': {'name': 'Favourite show'}
    }
  ],
});

void main() {
  for (final (category, route) in [
    ('watched', '/watch-history'),
    ('watchlist', '/watchlist'),
  ]) {
    testWidgets('$category opens the existing destination', (tester) async {
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) =>
                Scaffold(body: ProfileLibraryTotals(user: libraryUser))),
        GoRoute(
            path: route,
            builder: (_, __) => Scaffold(body: Text('Destination $route'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(
          MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
      await tester.tap(find.byKey(ValueKey('profile-total-$category')));
      await tester.pumpAndSettle();
      expect(find.text('Destination $route'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });
  }
  testWidgets('movie selection opens detail and closes the sheet',
      (tester) async {
    await tester.pumpWidget(MaterialApp.router(
        theme: AppTheme.darkTheme,
        routerConfig: GoRouter(routes: [
          GoRoute(
              path: '/',
              builder: (_, __) =>
                  Scaffold(body: ProfileLibraryTotals(user: libraryUser))),
          GoRoute(
              path: '/movies/:id',
              builder: (_, state) => Scaffold(
                  body: Text('Movie detail ${state.pathParameters['id']}'))),
        ])));
    await tester.tap(find.byKey(const ValueKey('profile-total-favourites')));
    await tester.pumpAndSettle();
    expect(find.text('Favourite movies'), findsOneWidget);
    expect(find.text('1 of 10 favourites'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    await tester.tap(find.text('Favourite movie'));
    await tester.pumpAndSettle();
    expect(find.text('Movie detail 5'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });
  testWidgets(
      'empty libraries stay usable on small landscape and tablet screens',
      (tester) async {
    final user = User.fromJson({'id': 'empty', 'username': 'Empty'});
    for (final size in [
      const Size(320, 568),
      const Size(640, 320),
      const Size(1024, 1366)
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Scaffold(body: ProfileLibraryTotals(user: user))));
      await tester.tap(find.byKey(const ValueKey('profile-total-favourites')));
      await tester.pumpAndSettle();
      expect(find.text('Favourite movies'), findsOneWidget);
      expect(find.text('0 of 10 favourites'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
  testWidgets('totals reflow at narrow widths and large text in both themes',
      (tester) async {
    for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 640), textScaler: TextScaler.linear(2)),
            child: Scaffold(body: ProfileLibraryTotals(user: libraryUser)),
          )));
      expect(find.text('2'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
