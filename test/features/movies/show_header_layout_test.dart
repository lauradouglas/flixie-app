import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_detail_hero.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_detail_images.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_header_backdrop.dart';

void main() {
  testWidgets(
      'show header overlays back, keeps sharing out of hero and reserves backdrop space',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget page(String? backdrop, {double scale = 1}) => MaterialApp(
        home: Scaffold(
            body: MediaQuery(
                data: MediaQueryData(
                    size: const Size(390, 844),
                    padding: const EdgeInsets.only(top: 44),
                    textScaler: TextScaler.linear(scale)),
                child: CustomScrollView(slivers: [
                  ShowDetailHero(
                      show: TvShow(
                          id: 101,
                          name: 'Alien: Earth',
                          backdropPath: backdrop))
                ]))));
    await tester.pumpWidget(page(null));
    final poster = tester.getRect(find.byType(ShowPoster));
    final back = find.byTooltip('Home');
    expect(poster.top, 44);
    expect(poster.overlaps(tester.getRect(back)), isTrue);
    expect(find.text('Share'), findsNothing);
    expect(tester.getTopLeft(find.text('Alien: Earth')).dy,
        lessThan(poster.top + 10));
    expect(find.byType(MovieHeaderBackdrop), findsNothing);
    await tester.pumpWidget(page('/alien-earth.jpg'));
    expect(tester.getTopLeft(find.byType(ShowPoster)).dy,
        closeTo(poster.top + 148.2, .01));
    expect(tester.getTopLeft(back).dy, 46);
    expect(tester.getBottomLeft(find.text('Alien: Earth')).dy,
        greaterThan(tester.getTopLeft(find.byType(ShowPoster)).dy + 100));
    expect(find.byType(MovieHeaderBackdrop), findsOneWidget);
    await tester.pumpWidget(page('  ', scale: 2));
    expect(find.byType(MovieHeaderBackdrop), findsNothing);
    expect(tester.getTopLeft(find.byType(ShowPoster)).dy, 44);
    expect(tester.takeException(), isNull);
  });
}
