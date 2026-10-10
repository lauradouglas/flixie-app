import 'package:flixie_app/features/home/presentation/widgets/home_hero_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/features/guest/presentation/widgets/guest_trending_carousel.dart';

void main() {
  const movies = [
    MovieShort(
        id: 348,
        name: 'Alien',
        releaseDate: '1979-05-25',
        overview: 'A spacecraft crew answers a distress call.',
        trailer: Trailer(key: 'fictional-trailer', site: 'YouTube')),
    MovieShort(
        id: 1,
        name: 'The Odyssey and a very long title that must stay readable',
        overview: 'A long journey. The whole story is available in Details.'),
  ];
  for (final (size, scale) in [
    (const Size(320, 568), 2.0),
    (const Size(430, 900), 1.0),
    (const Size(844, 390), 2.0),
    (const Size(1024, 768), 2.0),
  ]) {
    testWidgets('guest catalogue actions and paging fit $size at $scale',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final details = <int>[], saves = <int>[], trailers = <int>[];
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: SingleChildScrollView(
            child: GuestTrendingCarousel(
                movies: movies,
                onDetails: (m) => details.add(m.id),
                onSave: (m) => saves.add(m.id),
                onTrailer: (m) => trailers.add(m.id))),
      ))));
      await tester.tap(find.byTooltip('Watchlist').first);
      expect(saves, [348]);
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Details').first);
      await tester.tap(find.text('Trailer'));
      expect(details, [348]);
      expect(trailers, [348]);
      await tester.dragFrom(tester.getCenter(find.byTooltip('Details').first),
          Offset(-size.width * .8, 0));
      await tester.pumpAndSettle();
      expect(find.text(movies[1].name), findsOneWidget);
      details.clear();
      final secondCard =
          find.byWidgetPredicate((w) => w is HomeHeroCard && w.movie.id == 1);
      final secondDetails =
          find.descendant(of: secondCard, matching: find.byTooltip('Details'));
      await tester.ensureVisible(secondDetails);
      await tester.pumpAndSettle();
      await tester.tap(secondDetails);
      expect(details, [1]);
      for (final card
          in tester.widgetList<HomeHeroCard>(find.byType(HomeHeroCard))) {
        expect(card.showFriendActivity, isFalse);
      }
      expect(find.text('No friends have saved or favourited this yet'),
          findsNothing);
      expect(find.text('Favourite'), findsNothing);
      expect(find.text('Plan'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
