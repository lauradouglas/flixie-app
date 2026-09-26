import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_social_opinions.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/social/data/community_service.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';

const friend = MovieFriendActivity(
    userId: 'friend',
    username: 'LauraD',
    watched: true,
    watchCount: 4,
    rating: 10,
    recommended: true,
    favorited: true,
    onWatchlist: true,
    profileBadges: ['FOUNDER']);
ActivityListItem post(String id, {bool spoiler = false, int movieId = 42}) =>
    ActivityListItem.fromJson({
      'id': id,
      'userId': 'following-$id',
      'username': 'Nina $id',
      'type': 'movie-review',
      'movieId': movieId,
      'rating': 9,
      'recommended': true,
      'favorited': id == '1',
      'title': 'A public opinion',
      'body': 'Secret ending',
      'containsSpoilers': spoiler,
      'profileBadges': ['FOUNDER'],
    });
void main() {
  for (final size in [
    const Size(320, 900),
    const Size(430, 900),
    const Size(900, 600)
  ]) {
    testWidgets('friend row wraps at $size and opens profile', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
              body: MediaQuery(
            data: MediaQueryData(
                size: size, textScaler: const TextScaler.linear(2)),
            child: SingleChildScrollView(
                child: MovieFriendOpinionRow(
                    activity: friend, movieId: 42, onTap: () => opened = true)),
          ))));
      expect(find.text('10/10'), findsOneWidget);
      expect(find.text('×4'), findsOneWidget);
      expect(find.byTooltip('Watched 4 times'), findsOneWidget);
      expect(find.text('Watched 4 times'), findsNothing);
      expect(tester.widget<Icon>(find.byIcon(Icons.visibility_outlined)).color,
          const Color(0xFF70A7FF));
      expect(find.text('Recommended'), findsNothing);
      expect(find.byTooltip('Recommended'), findsOneWidget);
      expect(find.text('Favourite'), findsNothing);
      expect(find.byTooltip('Favourite'), findsOneWidget);
      expect(tester.getCenter(find.byIcon(Icons.visibility_outlined)).dy,
          tester.getCenter(find.byIcon(Icons.favorite_rounded)).dy);
      expect(tester.getCenter(find.byIcon(Icons.visibility_outlined)).dy,
          tester.getCenter(find.byIcon(Icons.bookmark_rounded)).dy);
      expect(
          tester
              .widget<ProfileAvatarView>(find.byType(ProfileAvatarView))
              .profileBadges,
          ['FOUNDER']);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('LauraD'));
      expect(opened, isTrue);
    });
  }
  testWidgets('rate-first preference hides individual and average scores',
      (tester) async {
    final privacy = MovieRatingPrivacy()
      ..userId = 'me'
      ..loaded = true
      ..enabled = true;
    addTearDown(privacy.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: privacy,
        child: MaterialApp(
            home: Scaffold(
                body: Column(children: [
          const MovieFriendsRatingSummary(activities: [friend], movieId: 42),
          MovieFriendOpinionRow(activity: friend, movieId: 42, onTap: () {}),
        ])))));
    expect(find.text('Rated'), findsOneWidget);
    expect(find.textContaining('/10'), findsNothing);
    expect(find.text('1 friend rated this'), findsOneWidget);
  });
  testWidgets(
      'following retries, expands, paginates and opens spoiler-safe review',
      (tester) async {
    var calls = 0;
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
              body: SingleChildScrollView(
                  child: MovieFollowingOpinions(
                      movieId: 42,
                      viewerId: 'me',
                      load: (cursor) async {
                        calls++;
                        if (calls == 1) throw Exception('offline');
                        if (cursor == 'next') {
                          return CommunityPage([post('5')], null);
                        }
                        return CommunityPage([
                          post('1', spoiler: true),
                          post('2'),
                          post('3'),
                          post('4'),
                          post('other', movieId: 99)
                        ], 'next');
                      })))),
      GoRoute(
          path: '/community/posts/:owner/:type/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Opened ${state.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Couldn’t load followed reviews · Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Review contains spoilers'), findsOneWidget);
    expect(find.byTooltip('Favourite'), findsOneWidget);
    expect(find.byTooltip('Recommended'), findsNWidgets(3));
    expect(post('1').copyWith().favorited, isTrue);
    expect(find.text('Secret ending'), findsNothing);
    expect(find.text('Nina other'), findsNothing);
    expect(find.text('Nina 4'), findsNothing);
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Load more reviews'));
    await tester.tap(find.text('Load more reviews'));
    await tester.pumpAndSettle();
    expect(find.text('Nina 5'), findsOneWidget);
    await tester.ensureVisible(find.text('Nina 1'));
    await tester.tap(find.text('Nina 1'));
    await tester.pumpAndSettle();
    expect(find.text('Opened 1'), findsOneWidget);
  });
}
