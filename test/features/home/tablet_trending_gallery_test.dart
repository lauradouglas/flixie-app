import 'package:flixie_app/features/home/presentation/widgets/home_tablet_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/home/presentation/widgets/trending_carousel.dart';
import 'package:flixie_app/features/home/presentation/widgets/tablet_trending_gallery.dart';
import 'package:flixie_app/models/movie_short.dart';

void main() {
  testWidgets('selecting tablet poster updates details and bookmark action',
      (t) async {
    t.view.physicalSize = const Size(820, 1180);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final saved = <int>[], opened = <int>[];
    Widget app(Set<int> pending) => MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: SingleChildScrollView(
                child: TrendingCarousel(
                    movies: const [
              MovieShort(id: 348, name: 'Alien'),
              MovieShort(id: 634, name: 'The Odyssey')
            ],
                    savedIds: const {
              634
            },
                    pendingIds: pending,
                    onSave: (m) => saved.add(m.id),
                    onDetails: (m) => opened.add(m.id),
                    onTrailer: (_) {}))));
    await t.pumpWidget(app({}));
    expect(find.byType(TabletTrendingGallery), findsOneWidget);
    await t.tap(find.descendant(
        of: find.byKey(const ValueKey('trending-poster-634')),
        matching: find.byType(InkWell)));
    await t.pumpAndSettle();
    await t.tap(find.text('In your watchlist'));
    expect(saved, [634]);
    await t.tap(find.widgetWithText(TextButton, 'The Odyssey'));
    expect(opened, [634]);
    await t.pumpWidget(app({634}));
    expect(
        t
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'In your watchlist'))
            .onPressed,
        isNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('large text uses the scrollable compact carousel', (t) async {
    t.view.physicalSize = const Size(820, 1180);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MediaQuery(
                    data:
                        const MediaQueryData(textScaler: TextScaler.linear(2)),
                    child: TrendingCarousel(
                        movies: const [MovieShort(id: 348, name: 'Alien')],
                        onDetails: (_) {},
                        onSave: (_) {},
                        onTrailer: (_) {}))))));
    expect(find.byType(TabletTrendingGallery), findsNothing);
    await t.ensureVisible(find.byTooltip('Watchlist'));
    expect(find.byTooltip('Watchlist').hitTestable(), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'tablet synopsis preview follows selection and opens full film details',
      (t) async {
    MovieShort? opened;
    const alien = MovieShort(
        id: 348,
        name: 'Alien',
        releaseDate: '1979-05-25',
        overview:
            'A crew answers a distress signal. Something follows them aboard.',
        voteAverage: 8.2);
    const odyssey = MovieShort(
        id: 634,
        name: 'The Odyssey',
        overview: 'A long journey home. The full story continues in details.');
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: SingleChildScrollView(
                child: HomeTabletScope(
                    child: SizedBox(
                        width: 680,
                        child: TabletTrendingGallery(
                            movies: const [alien, odyssey],
                            savedIds: const {},
                            pendingIds: const {},
                            onDetails: (m) => opened = m,
                            onSave: (_) {},
                            onTrailer: (_) {})))))));
    expect(find.text('A crew answers a distress signal.'), findsOneWidget);
    expect(find.text(alien.overview!), findsNothing);
    await t.tap(find.descendant(
        of: find.byKey(const ValueKey('trending-poster-634')),
        matching: find.byType(InkWell)));
    await t.pumpAndSettle();
    expect(find.text('A long journey home.'), findsOneWidget);
    expect(find.text('A crew answers a distress signal.'), findsNothing);
    await t.tap(find.widgetWithText(TextButton, 'The Odyssey'));
    expect(opened, same(odyssey));
    expect(opened!.overview, contains('The full story continues in details.'));
    expect(t.takeException(), isNull);
  });
}
