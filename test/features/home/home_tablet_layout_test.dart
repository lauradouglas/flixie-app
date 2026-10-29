import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/pip/models/pip_collection.dart';
import 'package:flixie_app/features/pip/presentation/controllers/pip_collection_controller.dart';
import '../pip/pip_collection_test.dart' show FakePips;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_tablet_layout.dart';
import 'package:flixie_app/features/home/presentation/widgets/tablet_trending_gallery.dart';
import 'package:flixie_app/features/home/presentation/widgets/cinema_list.dart';
import 'package:flixie_app/features/home/presentation/widgets/personalized_recommendation_card.dart';
import 'package:flixie_app/features/home/presentation/widgets/find_tonights_film_section.dart';
import 'package:flixie_app/models/movie_short.dart';

const movies = [
  MovieShort(
      id: 348,
      name: 'Alien',
      releaseDate: '1979-05-25',
      overview: 'A crew answers a mysterious signal in deep space.',
      voteAverage: 8.2),
  MovieShort(id: 634, name: 'The Odyssey'),
  MovieShort(id: 1, name: 'Obsession'),
  MovieShort(id: 2, name: 'Spider-Man'),
];

void main() {
  testWidgets('portrait picker uses active Pip and preserves pick action',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = FakePips()
      ..value =
          const PipCollection(activePip: 'cinemaClub', cinemaUnlocked: true);
    final controller = PipCollectionController(service: service);
    controller.syncUser('fixture', 0);
    await tester.pumpAndSettle();
    var picks = 0;
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
            home: Scaffold(
                body: HomeTabletScope(
                    portrait: true,
                    child: FindTonightsFilmSection(onPick: () => picks++))))));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(
        find.byKey(const ValueKey('portrait-picker-selected-pip')));
    expect((image.image as AssetImage).assetName,
        PipCollection.asset('cinemaClub'));
    await controller.select('classic');
    await tester.pumpAndSettle();
    expect(
        (tester
                .widget<Image>(
                    find.byKey(const ValueKey('portrait-picker-selected-pip')))
                .image as AssetImage)
            .assetName,
        PipCollection.asset('classic'));
    await tester.tap(find.text('Pick for me'));
    expect(picks, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final spec in [
    (name: 'tablet', size: const Size(1366, 1024), scale: 1.0, wide: true),
    (name: 'small-tablet', size: const Size(1024, 768), scale: 1.0, wide: true),
    (name: 'portrait', size: const Size(820, 1180), scale: 1.0, wide: false),
    (name: 'phone', size: const Size(390, 844), scale: 1.0, wide: false),
    (name: 'large-phone', size: const Size(430, 932), scale: 1.0, wide: false),
    (
      name: 'phone-landscape',
      size: const Size(932, 430),
      scale: 1.0,
      wide: false
    ),
    (name: 'split-view', size: const Size(600, 1024), scale: 1.0, wide: false),
    (name: 'large-text', size: const Size(1366, 1024), scale: 2.0, wide: false),
  ]) {
    testWidgets('${spec.name} preserves order and reachable film picker',
        (tester) async {
      tester.view.physicalSize = spec.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var picks = 0;
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(spec.scale)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: HomeTabletLayout(
                      greeting: const Text('Good morning, Casey'),
                      discovery:
                          const SizedBox(height: 260, child: Text('Discovery')),
                      cinemas: const Text('Cinema fixture'),
                      plans: const Text('Plans fixture'),
                      picker: FindTonightsFilmSection(onPick: () => picks++),
                      community: const Text('Activity fixture'),
                      games: const Text('Pip fixture'))))));
      expect(find.byKey(const ValueKey('home-tablet-layout')),
          spec.wide ? findsOneWidget : findsNothing);
      if (spec.wide) {
        expect(tester.getTopLeft(find.text('Plans fixture')).dx,
            greaterThan(tester.getTopLeft(find.text('Discovery')).dx));
        expect(
            tester.getTopLeft(find.text('Activity fixture')).dx,
            greaterThanOrEqualTo(
                tester.getTopLeft(find.text('Plans fixture')).dx));
      } else if (spec.name == 'portrait') {
        expect(find.byKey(const ValueKey('home-tablet-portrait-layout')),
            findsOneWidget);
        expect(tester.getTopLeft(find.text('Plans fixture')).dy,
            greaterThan(tester.getTopLeft(find.text('Cinema fixture')).dy));
        expect(tester.getTopLeft(find.text('Pick for me')).dx,
            greaterThan(tester.getTopLeft(find.text('Plans fixture')).dx));
        expect(tester.getTopLeft(find.text('Pip fixture')).dx,
            tester.getTopLeft(find.text('Plans fixture')).dx);
        expect(tester.getTopLeft(find.text('Pip fixture')).dy,
            greaterThan(tester.getTopLeft(find.text('Plans fixture')).dy));
        expect(tester.getTopLeft(find.text('Activity fixture')).dy,
            greaterThan(tester.getBottomLeft(find.text('Pip fixture')).dy));
      } else {
        expect(find.text('Plans fixture'), findsNothing);
        expect(tester.getTopLeft(find.text('Cinema fixture')).dy,
            greaterThan(tester.getTopLeft(find.text('Discovery')).dy));
      }
      await tester.ensureVisible(find.text('Pick for me'));
      await tester.tap(find.text('Pick for me'));
      expect(picks, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('portrait enables compact trending without two reading columns',
      (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      expect(HomeTabletLayout.trendingActive(context), isTrue);
      expect(HomeTabletLayout.active(context), isFalse);
      return const SizedBox();
    })));
  });

  testWidgets(
      'tablet discovery and cinema keep save, detail and expansion actions',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saved = <int>[], opened = <int>[];
    final boundary = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
                body: SingleChildScrollView(
                    child: HomeTabletLayout(
                        greeting: const Text('Good morning, Casey'),
                        discovery: TabletTrendingGallery(
                            movies: movies,
                            savedIds: const {},
                            pendingIds: const {},
                            onDetails: (m) => opened.add(m.id),
                            onSave: (m) => saved.add(m.id),
                            onTrailer: (_) {}),
                        cinemas: CinemaList(
                            movies: movies,
                            onDetails: (m) => opened.add(m.id),
                            onSave: (m) => saved.add(m.id),
                            onTrailer: (_) {}),
                        plans: const Text('Watch together'),
                        picker: FindTonightsFilmSection(onPick: () {}),
                        community: const Text('Around Flixie'),
                        games: const Text('Play with Pip')))))));
    await tester.pumpAndSettle();
    expect(
        tester
            .getSize(find.byKey(const ValueKey('tablet-trending-feature')))
            .height,
        lessThanOrEqualTo(240));
    expect(
        find.descendant(
            of: find.byType(TabletTrendingGallery),
            matching: find.text(movies.first.overview!)),
        findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('trending-poster-634')),
        matching: find.byType(InkWell)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to watchlist'));
    expect(saved, [634]);
    await tester.tap(find.widgetWithText(TextButton, 'The Odyssey'));
    expect(opened, [634]);
    await tester.tap(find.byTooltip('Watchlist').first);
    expect(saved, [634, 348]);
    final lastCinema = find.descendant(
        of: find.byType(CinemaList), matching: find.text('Spider-Man'));
    await tester.ensureVisible(lastCinema);
    await tester.pumpAndSettle();
    await tester.tap(lastCinema);
    expect(opened, [634, 2]);
    expect(find.text('Show more cinema releases'), findsNothing);
    expect(tester.takeException(), isNull);
    if (Platform.environment['FLIXIE_RENDER_TABLET_HOME'] == '1') {
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('/tmp/flixie-tablet-home-layout.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets(
      'compact recommendations retain all tracking actions and full title',
      (tester) async {
    final actions = <String>[];
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
            body: HomeTabletScope(
                child: SizedBox(
                    width: 280,
                    height: 210,
                    child: PersonalizedRecommendationCard(
                        movie: const MovieShort(
                            id: 569094,
                            name: 'Spider-Man: Across the Spider-Verse',
                            releaseDate: '2023-06-02',
                            voteAverage: 8.3),
                        reasons: const ['Because you enjoy epic adventures'],
                        isBookmarked: false,
                        isBookmarkUpdating: false,
                        isPreviouslyWatched: false,
                        onTap: () => actions.add('open'),
                        onBookmarkTap: () => actions.add('save'),
                        onMarkWatched: () => actions.add('watch'),
                        onNotInterested: () => actions.add('dismiss')))))));
    final art = find.byKey(const ValueKey('tablet-recommendation-artwork'));
    final footer = find.byKey(const ValueKey('tablet-recommendation-actions'));
    final reason = find.text('Because you enjoy epic adventures');
    expect(tester.getSize(art).width / tester.getSize(art).height,
        closeTo(2 / 3, .001));
    expect(tester.getBottomRight(reason).dy,
        lessThanOrEqualTo(tester.getTopLeft(footer).dy));
    expect(tester.getBottomLeft(art).dy, tester.getTopLeft(footer).dy);
    expect(find.text('Movie · 2023'), findsOneWidget);
    expect(find.text('8.3'), findsOneWidget);
    final watched = tester.getRect(find.byTooltip('Mark watched'));
    final save = tester.getRect(find.byTooltip('Add to watchlist'));
    final dismiss = tester.getRect(find.byTooltip('Not interested'));
    final details = tester.getRect(find.byTooltip('Movie details'));
    expect(save.left - watched.right, closeTo(dismiss.left - save.right, .01));
    expect(
        dismiss.left - save.right, closeTo(details.left - dismiss.right, .01));
    expect(watched.left, closeTo(tester.getRect(footer).left + 8, .01));
    expect(details.right, closeTo(tester.getRect(footer).right - 8, .01));
    await tester.tap(find.byTooltip('Add to watchlist'));
    await tester.tap(find.byTooltip('Mark watched'));
    await tester.tap(find.byTooltip('Not interested'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Movie details'));
    expect(actions, ['save', 'watch', 'dismiss', 'open']);
    expect(tester.takeException(), isNull);
  });
}
