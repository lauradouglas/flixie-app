import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/data/genre_community_service.dart';
import 'package:flixie_app/features/social/presentation/pages/genre_communities_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/genre_community_feed_screen.dart';
import 'package:flixie_app/features/social/presentation/widgets/segmented_toggle.dart';

ActivityListItem genrePost(String id, {bool spoiler = false}) =>
    ActivityListItem.fromJson({
      'id': id,
      'userId': 'member',
      'username': 'Horror member',
      'type': 'movie-review',
      'movieId': 348,
      'movie': {'title': 'Alien'},
      'rating': 4,
      'title': 'A thoughtful take $id',
      'body': 'A secret ending',
      'containsSpoilers': spoiler,
      'profileBadges': ['EARLY_ADOPTER'],
    });

class FakeGenres extends GenreCommunityService {
  bool joined = false, fail = false;
  int calls = 0;
  Completer<GenreCommunityPage>? pendingLatest;
  final cursors = <String?>[];
  GenreCommunity get horror =>
      GenreCommunity(id: 27, name: 'Horror', joined: joined);
  @override
  Future<List<GenreCommunity>> list() async => [
        horror,
        const GenreCommunity(id: 878, name: 'Science Fiction', joined: false)
      ];
  @override
  Future<void> setJoined(int id, bool value) async {
    if (fail) throw Exception('offline');
    joined = value;
  }

  @override
  Future<GenreCommunityPage> feed(int id,
      {String sort = 'latest', String? cursor}) async {
    calls++;
    cursors.add(cursor);
    if (pendingLatest != null && sort == 'latest') return pendingLatest!.future;
    if (fail) throw Exception('offline');
    return GenreCommunityPage(
        community: horror,
        items: [genrePost(cursor != null ? 'second' : sort, spoiler: true)],
        nextCursor: cursor == null ? 'next' : null,
        ratings: {348: const GenreMemberRating(6, 2)});
  }
}

class FakeAnime extends FakeGenres {
  @override
  Future<GenreCommunityPage> feed(int id,
          {String sort = 'latest', String? cursor}) async =>
      GenreCommunityPage.fromJson({
        'community': {'id': -1, 'name': 'Anime', 'joined': joined},
        'items': [
          for (final kind in ['movie', 'show'])
            {
              'id': 'same-id',
              'userId': 'member',
              'username': 'Anime fan',
              'type': '$kind-review',
              '${kind}Id': 129,
              kind: {
                'title': kind == 'movie' ? 'Spirited Away' : 'Anime series'
              },
              'rating': 4,
              'title': 'A member review',
              'body': 'Review',
              'containsSpoilers': false,
              'profileBadges': ['EARLY_ADOPTER'],
            }
        ],
        'nextCursor': null,
        'ratings': [
          {'movieId': 129, 'average': 7.0, 'count': 2},
          {'showId': 129, 'average': 4.0, 'count': 1}
        ],
      });
}

void main() {
  testWidgets(
      'Anime mixes films and series without ID collisions and joins independently',
      (tester) async {
    final service = FakeAnime();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: GenreCommunityFeedScreen(genreId: -1, service: service)));
    await tester.pumpAndSettle();
    expect(find.text('Spirited Away · Film'), findsOneWidget);
    expect(find.text('Anime series · Series'), findsOneWidget);
    expect(find.textContaining('7.0/10 · 2 members'), findsOneWidget);
    expect(find.textContaining('4.0/10 · 1 member'), findsOneWidget);
    await tester.tap(find.text('Join community'));
    await tester.pumpAndSettle();
    expect(service.joined, isTrue);
  });
  testWidgets(
      'join and leave persist; joined filter and search use loaded directory',
      (tester) async {
    final service = FakeGenres();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: GenreCommunitiesView(service: service))));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Join').first);
    await tester.pumpAndSettle();
    expect(service.joined, isTrue);
    expect(find.text('Leave'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Joined'));
    await tester.pumpAndSettle();
    expect(find.text('Science Fiction'), findsNothing);
    service.fail = true;
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Leave'), findsOneWidget);
    expect(service.joined, isTrue);
    service.fail = false;
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No joined communities'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'All communities'));
    await tester.enterText(find.byType(TextField), 'science');
    await tester.pumpAndSettle();
    expect(find.text('Science Fiction'), findsOneWidget);
    expect(find.text('Horror'), findsNothing);
  });
  testWidgets(
      'feed opens original post, joins, paginates and retains rows on errors',
      (tester) async {
    final service = FakeGenres();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) =>
              GenreCommunityFeedScreen(genreId: 27, service: service)),
      GoRoute(
          path: '/community/posts/:owner/:type/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Opened ${state.pathParameters['id']}')))
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('4/10'), findsOneWidget);
    expect(find.textContaining('6.0/10 · 2 members'), findsOneWidget);
    expect(find.text('A secret ending'), findsNothing);
    expect(find.text('Review contains spoilers'), findsOneWidget);
    expect(
        tester
            .widget<ProfileAvatarView>(find.byType(ProfileAvatarView))
            .profileBadges,
        ['EARLY_ADOPTER']);
    await tester.tap(find.text('Join community'));
    await tester.pumpAndSettle();
    expect(find.text('Leave community'), findsOneWidget);
    service.fail = true;
    await tester.ensureVisible(find.text('Load more reviews'));
    await tester.tap(find.text('Load more reviews'));
    await tester.pumpAndSettle();
    expect(find.text('Alien · Film'), findsOneWidget);
    expect(find.text('Couldn’t load reviews. Try again.'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Couldn’t load reviews. Try again.'));
    await tester.pumpAndSettle();
    expect(find.text('Alien · Film'), findsNWidgets(2));
    expect(service.cursors.last, 'next');
    await tester.ensureVisible(find.text('Alien · Film').first);
    await tester.tap(find.text('Alien · Film').first);
    await tester.pumpAndSettle();
    expect(find.text('Opened latest'), findsOneWidget);
  });
  testWidgets('stale latest response cannot overwrite popular selection',
      (tester) async {
    final service = FakeGenres()
      ..pendingLatest = Completer<GenreCommunityPage>();
    await tester.pumpWidget(MaterialApp(
        home: GenreCommunityFeedScreen(genreId: 27, service: service)));
    await tester.pump();
    await tester.tap(find.text('Popular'));
    await tester.pumpAndSettle();
    service.pendingLatest!.complete(GenreCommunityPage(
        community: service.horror, items: [genrePost('stale')]));
    await tester.pumpAndSettle();
    expect(find.text('A thoughtful take stale'), findsNothing);
    expect(find.byType(GenreReviewCard), findsOneWidget);
  });
  for (final size in [
    const Size(320, 850),
    const Size(430, 900),
    const Size(900, 600)
  ]) {
    testWidgets('responsive genre directory and privacy at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final privacy = MovieRatingPrivacy()
        ..userId = 'viewer'
        ..loaded = true
        ..enabled = true;
      addTearDown(privacy.dispose);
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: privacy,
          child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                  body: MediaQuery(
                      data: MediaQueryData(
                          size: size, textScaler: const TextScaler.linear(2)),
                      child: SingleChildScrollView(
                          child: Column(children: [
                        SocialSegmentedToggle(
                            selectedIndex: 4,
                            labels: const [
                              'People',
                              'Activity',
                              'Chats',
                              'Groups',
                              'Communities'
                            ],
                            onChanged: (_) {}),
                        GenreReviewCard(
                            item: genrePost('scale'),
                            genreName: 'Horror',
                            rating: const GenreMemberRating(6, 2)),
                      ])))))));
      expect(find.text('Rated'), findsOneWidget);
      expect(find.textContaining('/10'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
                  data: MediaQueryData(
                      size: size, textScaler: const TextScaler.linear(2)),
                  child: GenreCommunitiesView(service: FakeGenres())))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
