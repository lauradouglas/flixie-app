import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/guest/presentation/widgets/guest_cinema_list.dart';
import 'package:flixie_app/models/movie_short.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('cinema list actions and more releases at scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final movies = List.generate(
          4,
          (i) => MovieShort(
              id: i,
              name: 'Cinema film $i',
              overview: 'A real plot preview.',
              releaseDate: '2026-10-16',
              voteAverage: 7.2,
              trailer: const Trailer(key: 'fixture')));
      int? opened, saved, played;
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
              body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SingleChildScrollView(
                      child: GuestCinemaList(
                          movies: movies,
                          onDetails: (m) => opened = m.id,
                          onSave: (m) => saved = m.id,
                          onTrailer: (m) => played = m.id))))));
      expect(find.byType(PageView), findsNothing);
      expect(find.text('Cinema film 3'), findsNothing);
      await tester.tap(find.text('Cinema film 0'));
      expect(opened, 0);
      await tester.tap(find.byTooltip('Watchlist').first);
      expect(saved, 0);
      await tester.ensureVisible(find.text('Trailer').first);
      await tester.tap(find.text('Trailer').first);
      expect(played, 0);
      await tester.ensureVisible(find.text('Show more cinema releases'));
      await tester.tap(find.text('Show more cinema releases'));
      await tester.pump();
      expect(find.text('Cinema film 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
