import 'package:flixie_app/features/home/presentation/widgets/home_hero_card.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/features/home/presentation/models/home_section.dart';
import 'package:flixie_app/models/friend_media_interaction.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/widgets/trending_carousel.dart';
import 'package:flixie_app/models/movie_short.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'carousel fits tallest card and keeps height after swipe at scale $scale',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
            body: SingleChildScrollView(
                child: TrendingCarousel(
          movies: const [
            MovieShort(id: 348, name: 'Alien'),
            MovieShort(
                id: 2,
                name: 'The Odyssey and a very long fictional subtitle',
                overview:
                    'A journey across the seas with a synopsis long enough to fill all three lines on a small phone.',
                releaseDate: '2026-10-09'),
          ],
          onDetails: (_) {},
          onSave: (_) {},
          onTrailer: (_) {},
        ))),
      ));
      final measured = tester
          .widgetList<HomeHeroCard>(
              find.byType(HomeHeroCard, skipOffstage: false))
          .where((card) => find.byWidget(card).evaluate().isEmpty)
          .toList();
      expect(measured.length, 2);
      final heights = measured
          .map((card) =>
              tester.getSize(find.byWidget(card, skipOffstage: false)).height)
          .toList();
      expect(heights[1], greaterThan(heights[0]));
      final tallest = heights.reduce((a, b) => a > b ? a : b);
      expect(
          tester.getSize(find.byType(PageView)).height, closeTo(tallest, .01));
      await tester.drag(find.byType(PageView), const Offset(-280, 0));
      await tester.pumpAndSettle();
      expect(
          tester.getSize(find.byType(PageView)).height, closeTo(tallest, .01));
      expect(find.text('The Odyssey and a very long fictional subtitle'),
          findsOneWidget);
      final synopsis = find.text(
          'A journey across the seas with a synopsis long enough to fill all three lines on a small phone.');
      expect(tester.widget<Text>(synopsis).maxLines, 4);
      final detailsTop = tester
          .getTopLeft(find
              .ancestor(
                  of: find.byTooltip('Details').last,
                  matching: find.byType(Wrap))
              .first)
          .dy;
      expect(detailsTop - tester.getBottomLeft(synopsis).dy, closeTo(8, .01));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('phone media pill sits in content below the poster',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: TrendingCarousel(movies: const [
      MovieShort(id: 1399, name: 'Game of Thrones', mediaType: 'SHOW')
    ], onDetails: (_) {}, onSave: (_) {}, onTrailer: (_) {})))));
    await tester.pump();
    final top = tester.getTopLeft(find.byType(HomeHeroCard)).dy;
    expect(tester.getTopLeft(find.text('TV show')).dy,
        greaterThanOrEqualTo(top + 280));
    expect(tester.getTopLeft(find.text('Game of Thrones')).dy,
        greaterThan(tester.getBottomLeft(find.text('TV show')).dy));
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1024.0]) {
    testWidgets(
        'signed-in show trending friend row loads and updates at width $width',
        (t) async {
      await t.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final activity =
          HomeSection<List<FriendMediaInteraction>>(const [], loading: true);
      addTearDown(activity.dispose);
      final pages = <int>[];
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: TrendingCarousel(
        movies: const [
          MovieShort(id: 348, name: 'Game of Thrones', mediaType: 'SHOW')
        ],
        friendActivity: (_) => activity,
        onPageChanged: pages.add,
        onDetails: (_) {},
        onSave: (_) {},
        onTrailer: (_) {},
      )))));
      await t.pump();
      expect(pages, contains(0));
      activity.update(data: const [
        FriendMediaInteraction(
            userId: 'fictional',
            username: 'Robin',
            onWatchlist: true,
            favourited: true,
            profileBadges: ['fixture-border'])
      ], loading: false);
      await t.pump();
      final avatars =
          t.widgetList<ProfileAvatarView>(find.byType(ProfileAvatarView));
      expect(avatars, isNotEmpty);
      expect(avatars.every((a) => a.profileBadges.contains('fixture-border')),
          isTrue);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('guest trending keeps friend activity hidden', (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: TrendingCarousel(
                    movies: const [MovieShort(id: 348, name: 'Alien')],
                    onDetails: (_) {},
                    onSave: (_) {},
                    onTrailer: (_) {})))));
    expect(find.text('No friends have saved or favourited this yet'),
        findsNothing);
  });

  testWidgets(
      'signed-in bookmark shows saved state and blocks repeated pending writes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var saves = 0;
    Widget build(Set<int> pending) => MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: TrendingCarousel(
                    movies: const [MovieShort(id: 348, name: 'Alien')],
                    savedIds: const {348},
                    pendingIds: pending,
                    onSave: (_) => saves++,
                    onDetails: (_) {},
                    onTrailer: (_) {}))));
    await tester.pumpWidget(build({}));
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Remove from watchlist'));
    expect(saves, 1);
    await tester.pumpWidget(build({348}));
    final button = tester.widget<IconButton>(find.descendant(
        of: find.byTooltip('Remove from watchlist'),
        matching: find.byType(IconButton)));
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
