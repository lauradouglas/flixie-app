import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_hero_card.dart';
import 'package:flixie_app/models/movie_short.dart';

void main() {
  for (final size in [
    const Size(320, 800),
    const Size(390, 850),
    const Size(1024, 800),
    const Size(844, 390)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('hero actions remain usable at $size and text scale $scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var saved = false, opened = false;
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: SizedBox(
            width: size.width * .84,
            height: 280 + 220 * scale,
            child: HomeHeroCard(
                movie:
                    const MovieShort(id: 13, name: 'Alien', voteAverage: 8.5),
                posterHeight: 280,
                inWatchlist: false,
                isUpdating: false,
                interactions: const [],
                friendActivityLoading: false,
                friendActivityFailed: false,
                onOpen: () => opened = true,
                onDetails: () {},
                onWatchlist: () => saved = true,
                onTrailer: () {},
                onFriendsRetry: () {}),
          ))),
        ));
        await tester.ensureVisible(find.byTooltip('Watchlist'));
        await tester.tap(find.byTooltip('Watchlist'));
        expect(saved, true);
        await tester.ensureVisible(find.text('Alien'));
        await tester.tap(find.text('Alien'));
        expect(opened, true);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
