import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_friends_section.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';

void main() {
  patrolTest(
      'movie friends sheet filters search and opens the selected profile',
      ($) async {
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
                  body: MovieFriendsSection(
                      movieId: 1,
                      signedIn: true,
                      loading: false,
                      summaryLoaded: true,
                      hasSummary: true,
                      hasError: false,
                      onReload: () {},
                      activities: const [
                    MovieFriendActivity(
                        userId: 'alice',
                        username: 'Alice',
                        onWatchlist: false,
                        watched: true,
                        favorited: true,
                        rating: 9,
                        profileBadges: ['FOUNDER']),
                    MovieFriendActivity(
                        userId: 'bob',
                        username: 'Bob',
                        onWatchlist: true,
                        watched: false,
                        favorited: false,
                        profileBadges: ['EARLY_ADOPTER']),
                  ]))),
      GoRoute(
          path: '/friends/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Profile ${state.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(
        MaterialApp.router(routerConfig: router, theme: AppTheme.darkTheme));
    await $('View all').tap();
    await $(TextField).enterText('bob');
    final sheet = find.byType(BottomSheet);
    final tabs = find.descendant(
        of: sheet,
        matching: find.byWidgetPredicate((widget) =>
            widget is ListView && widget.scrollDirection == Axis.horizontal));
    await $('Watchlist  1')
        .scrollTo(view: tabs, scrollDirection: AxisDirection.right, step: 120)
        .tap();
    final row = find.descendant(of: sheet, matching: find.text('Bob'));
    await $(row).waitUntilVisible();
    expect(
        find.descendant(of: sheet, matching: find.text('Alice')), findsNothing);
    await $(row).tap();
    await $('Profile bob').waitUntilVisible();
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $('Profile bob').waitUntilVisible();
  });
}
