import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/features/home/presentation/widgets/trending_carousel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/features/guest/presentation/widgets/guest_trending_carousel.dart';

void main() {
  const movies = [
    MovieShort(
        id: 348,
        name: 'Alien',
        poster: '/alien.jpg',
        releaseDate: '1979-05-25',
        overview: 'A crew encounters an alien aboard their ship.',
        voteAverage: 8.2,
        trailer: Trailer(key: 'fictional-trailer')),
    MovieShort(
        id: 1,
        mediaType: 'SHOW',
        poster: '/show.jpg',
        name: 'The Odyssey and a very long title that must stay readable'),
  ];
  for (final (size, scale) in [
    (const Size(320, 568), 2.0),
    (const Size(430, 900), 1.0),
    (const Size(844, 390), 2.0),
    (const Size(1024, 768), 2.0),
  ]) {
    testWidgets('complete guest artwork and actions fit $size at $scale',
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
      expect(find.byType(TrendingCarousel), findsOneWidget);
      expect(find.text('A crew encounters an alien aboard their ship.'),
          findsOneWidget);
      expect(find.text('8.2'), findsOneWidget);
      final pager = tester.widget<PageView>(find.byType(PageView)).controller!;
      Future<void> reveal(Finder finder, int page) async {
        await tester.ensureVisible(finder);
        pager.jumpToPage(page);
        await tester.pump();
      }

      await reveal(find.byTooltip('Details').first, 0);
      await tester.tap(find.byTooltip('Details').first);
      expect(details, [348]);
      await reveal(find.text('Trailer'), 0);
      await tester.tap(find.text('Trailer'));
      expect(trailers, [348]);
      await reveal(find.byTooltip('Watchlist').first, 0);
      await tester.tap(find.byTooltip('Watchlist').first);
      expect(saves, [348]);
      await tester.dragFrom(
          tester.getCenter(find.byTooltip('Watchlist').first) -
              const Offset(80, 0),
          const Offset(-600, 0));
      await tester.pumpAndSettle();
      // Existing carousel aligns the final card flush with the trailing edge.
      expect(pager.page, greaterThan(.5));
      await reveal(find.byTooltip('Details').last, 1);
      await tester.tap(find.byTooltip('Details').last);
      expect(details, [348, 1]);
      expect(find.text(movies[1].name), findsOneWidget);
      expect(find.text('TV show'), findsOneWidget);
      for (final image in tester
          .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))) {
        if (image.color != null) continue; // Decorative blurred background.
        expect(image.fit, BoxFit.contain,
            reason:
                'the entire source image must remain visible without changing its ratio');
      }
      expect(find.text('Favourite'), findsNothing);
      expect(find.text('Plan'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
