import 'package:flutter/material.dart';
import 'package:flixie_app/features/home/presentation/models/home_section.dart';
import 'package:flixie_app/models/friend_media_interaction.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/widgets/trending_carousel.dart';
import 'package:flixie_app/models/movie_short.dart';

void main() {
  for (final width in [390.0, 1024.0]) {
    testWidgets(
        'signed-in trending friend row loads and updates at width $width',
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
        movies: const [MovieShort(id: 348, name: 'Alien')],
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
