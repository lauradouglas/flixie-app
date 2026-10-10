import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_friends_section.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';

const friends = [
  MovieFriendActivity(
      userId: 'alice',
      username: 'Alice',
      onWatchlist: false,
      watched: true,
      favorited: true,
      rating: 9,
      recommended: true,
      profileBadges: ['FOUNDER']),
  MovieFriendActivity(
      userId: 'bob',
      username: 'Bob',
      onWatchlist: true,
      watched: false,
      favorited: false,
      profileBadges: ['EARLY_ADOPTER']),
];

Widget section() => MovieFriendsSection(
    movieId: 1,
    activities: friends,
    signedIn: true,
    loading: false,
    summaryLoaded: true,
    hasSummary: true,
    hasError: false,
    onReload: () {});
void main() {
  testWidgets('friend search and filters preserve each avatar badge',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme, home: Scaffold(body: section())));
    final badges = tester
        .widgetList<ProfileAvatarView>(find.byType(ProfileAvatarView))
        .map((avatar) => avatar.profileBadges)
        .toList();
    expect(
        badges,
        containsAll([
          ['FOUNDER'],
          ['EARLY_ADOPTER']
        ]));
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bob');
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(
        find.descendant(of: sheet, matching: find.text('Bob')), findsOneWidget);
    expect(
        find.descendant(of: sheet, matching: find.text('Alice')), findsNothing);
    await tester.tap(find.text('Rated  1'));
    await tester.pumpAndSettle();
    expect(find.text('No matching friends'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.descendant(of: sheet, matching: find.text('Alice')),
        findsOneWidget);
    expect(
        find.descendant(of: sheet, matching: find.text('Bob')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('a friend row opens that friend profile', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => Scaffold(body: section())),
      GoRoute(
          path: '/friends/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Profile ${state.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: AppTheme.darkTheme));
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    expect(find.text('Profile alice'), findsOneWidget);
  });
}
