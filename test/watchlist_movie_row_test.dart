import 'dart:io';
import 'dart:ui' as ui;
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/friend_recommendation.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const title = WatchlistMovie(
    id: 'saved',
    userId: 'me',
    movieId: 42,
    createdAt: '2026-05-25T10:15:00Z',
    movie: WatchlistMovieDetails(
        id: 42,
        title: 'A meaningful long title that must remain readable',
        releaseDate: '2020-01-01',
        runtime: 132,
        genres: ['Science fiction', 'Adventure']));
const friends = [
  FriendRecommendationItem(
      userId: 'a',
      username: 'Alice',
      profileBadges: ['FOUNDER'],
      rating: 8,
      recommends: false),
  FriendRecommendationItem(
      userId: 'b',
      username: 'Jonah',
      profileBadges: ['BETA_TESTER'],
      rating: 10,
      recommends: true),
  FriendRecommendationItem(userId: 'c', username: 'Mia', recommends: false),
];
WatchProvider offer(String type,
        {int id = 1, String name = 'Example service', String? url}) =>
    WatchProvider(
        id: id,
        providerName: name,
        displayPriority: 1,
        logoPath: '',
        tvShows: true,
        movies: true,
        isVisible: true,
        supportsGb: true,
        supportsUs: false,
        availabilityTypes: {type},
        watchUrl: url);
Widget row(
        {List<FriendRecommendationItem> people = friends,
        List<WatchProvider> providers = const [],
        bool loading = false,
        bool failed = false,
        VoidCallback? remove,
        VoidCallback? open,
        VoidCallback? retry,
        bool show = false}) =>
    WatchlistMovieRow(
        watchlistItem: title,
        isWatched: false,
        isShow: show,
        recommendations: people,
        availableProviders: providers,
        userWatchProviderIds: const {1},
        isLoadingProviders: loading,
        providersFailed: failed,
        onRetryProviders: retry,
        onTap: open ?? () {},
        onMarkAsWatched: () {},
        onRemove: remove ?? () {});
Widget wrap(Widget child, {double scale = 1, Key? capture}) => MaterialApp(
    theme: AppTheme.darkTheme,
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: Scaffold(
        backgroundColor: FlixieColors.background,
        body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(
                key: capture,
                child: ColoredBox(
                    color: FlixieColors.background,
                    child: SingleChildScrollView(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: child)))))));

void main() {
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets('movie and show posters open their detail action',
      (tester) async {
    for (final isShow in [false, true]) {
      var opened = 0;
      await tester.pumpWidget(wrap(row(show: isShow, open: () => opened++)));
      await tester.tap(find.bySemanticsLabel('${title.movie!.title} poster'));
      expect(opened, 1);
    }
  });

  testWidgets(
      'watched friends include non-recommenders; null excluded from average and badges preserved',
      (tester) async {
    await tester.pumpWidget(wrap(row()));
    expect(find.text('3 friends watched'), findsOneWidget);
    expect(find.text('Friends’ average 9.0/10 · 2 rated'), findsOneWidget);
    expect(
        tester
            .widgetList<ProfileAvatarView>(find.byType(ProfileAvatarView))
            .first
            .profileBadges,
        ['FOUNDER']);
    await tester.tap(find.text('3 friends watched'));
    await tester.pumpAndSettle();
    expect(find.text('Watched · Not rated yet'), findsOneWidget);
    expect(find.text('8/10'), findsOneWidget);
    expect(find.text('Watched · Movie rating'), findsNWidgets(2));
    expect(find.text('Friends who watched'), findsOneWidget);
    expect(find.text('Friends’ average 9.0/10 · Based on 2 ratings'),
        findsOneWidget);
    expect(tester.getSize(find.byType(BottomSheet)).height, lessThan(500));
    expect(tester.getTopLeft(find.text('8/10')).dx,
        greaterThan(tester.getTopLeft(find.text('Alice')).dx));
    expect(find.text('Recommends'), findsNothing);
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet, isNotNull);
  });
  testWidgets(
      'one friend uses a compact sheet; many friends scroll at large text',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrap(row(people: [friends.first])));
    await tester.tap(find.text('1 friend watched'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(BottomSheet)).height, lessThan(350));
    if (Platform.environment['WATCHLIST_CAPTURE'] == '1') {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find
            .ancestor(
                of: find.byType(BottomSheet),
                matching: find.byType(RepaintBoundary))
            .first);
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/friends-sheet-corrected.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpWidget(wrap(
        row(
            people: List.generate(
                20,
                (i) => FriendRecommendationItem(
                    userId: '$i',
                    username: 'Friend number $i',
                    recommends: false))),
        scale: 2));
    await tester.ensureVisible(find.text('20 friends watched'));
    await tester.tap(find.text('20 friends watched'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(BottomSheet)).height,
        lessThanOrEqualTo(568 * .85));
    final scroll = find.descendant(
        of: find.byType(BottomSheet), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text('Friend number 19'), 300,
        scrollable: scroll);
    expect(tester.takeException(), isNull);
  });
  testWidgets('date and remove live in overflow', (tester) async {
    var removed = false;
    await tester.pumpWidget(wrap(row(remove: () => removed = true)));
    expect(find.text('Added 25 May 2026'), findsNothing);
    expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.text('Added 25 May 2026'), findsOneWidget);
    for (final action in [
      'Mark as Watched',
      'Add to favourites',
      'Add to list',
      'Invite friends'
    ]) {
      expect(find.text(action), findsOneWidget);
    }
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(removed, isTrue);
  });
  testWidgets('provider logos fill available width and count hidden options',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    var previousCount = 0;
    for (final width in [320.0, 430.0, 834.0]) {
      tester.view.physicalSize = Size(width, 1200);
      await tester.pumpWidget(wrap(row(providers: [
        for (var i = 0; i < 15; i++)
          offer('flatrate', id: i + 1, name: 'Provider $i'),
      ])));
      await tester.pumpAndSettle();
      final logos = find.byWidgetPredicate((widget) =>
          widget is Tooltip &&
          (widget.message?.startsWith('Provider ') ?? false));
      final count = logos.evaluate().length;
      expect(count, greaterThan(previousCount));
      expect(find.text('+${15 - count} options'), findsOneWidget);
      expect(tester.takeException(), isNull);
      previousCount = count;
    }
  });

  testWidgets(
      'included offers outrank rentals and all options explain requirements',
      (tester) async {
    await tester.pumpWidget(wrap(row(
        providers: [offer('rent'), offer('flatrate'), offer('buy', id: 2)])));
    expect(find.text('Watch on'), findsOneWidget);
    expect(find.text('Example service'), findsNothing);
    expect(find.byTooltip('Example service · Included'), findsOneWidget);
    expect(find.text('View options'), findsOneWidget);
    expect(
        tester.getTopLeft(find.byTooltip('Example service · Included')).dx,
        lessThan(
            tester.getTopLeft(find.byTooltip('Example service · Rent')).dx));
    await tester.tap(find.text('View options'));
    await tester.pumpAndSettle();
    expect(find.text('United Kingdom'), findsOneWidget);
    expect(find.text('Where to watch'), findsOneWidget);
    expect(find.text('Buy'), findsOneWidget);
    expect(find.text('Included · Rent'), findsOneWidget);
    expect(find.text('Provider destination not supplied'), findsNothing);
    expect(find.text('Example service'), findsNWidgets(2));
  });
  testWidgets(
      'loading, failed and confirmed no offers are different; retry works',
      (tester) async {
    await tester.pumpWidget(wrap(row(loading: true)));
    expect(find.text('Checking availability…'), findsOneWidget);
    var retry = false;
    await tester.pumpWidget(wrap(row(failed: true, retry: () => retry = true)));
    expect(find.text('No providers found'), findsNothing);
    await tester.tap(find.text('Availability couldn’t load · Retry'));
    expect(retry, isTrue);
    await tester.pumpWidget(wrap(row()));
    expect(find.text('No providers found'), findsOneWidget);
  });
  testWidgets('TV average excludes episode ratings and labels show scope',
      (tester) async {
    await tester.pumpWidget(wrap(row(show: true, people: [
      const FriendRecommendationItem(
          userId: 'a',
          username: 'Alice',
          recommends: false,
          rating: 8,
          ratingScope: 'show'),
      const FriendRecommendationItem(
          userId: 'b',
          username: 'Jonah',
          recommends: false,
          rating: 2,
          ratingScope: 'episode'),
    ])));
    expect(find.text('Friends’ average 8.0/10 · 1 rated'), findsOneWidget);
    await tester.tap(find.text('2 friends watched'));
    await tester.pumpAndSettle();
    expect(find.text('Watched · Show rating'), findsOneWidget);
    expect(find.text('Watched · Episode rating'), findsOneWidget);
  });
  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(834, 1194),
    const Size(844, 390)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'responsive row and sheets ${size.width}x${size.height} text $scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(wrap(row(providers: [offer('flatrate')]),
            scale: scale, capture: key));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(title.movie!.title), findsOneWidget);
        if (Platform.environment['WATCHLIST_CAPTURE'] == '1' && scale == 1) {
          await tester.runAsync(() async {
            final boundary = key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File('/tmp/watchlist-${size.width.toInt()}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
        await tester.ensureVisible(find.text('View options'));
        await tester.tap(find.text('View options'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (Platform.environment['WATCHLIST_CAPTURE'] == '1' && scale == 1) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(find
                .ancestor(
                    of: find.byType(BottomSheet),
                    matching: find.byType(RepaintBoundary))
                .first);
            final image = await boundary.toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File('/tmp/providers-sheet-${size.width.toInt()}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
  test(
      'rental-only, untyped and parent subscriptions are not included; destinations are verified',
      () {
    expect(() => parseWatchProviderOffers(null), throwsFormatException);
    expect(() => parseWatchProviderOffers({'error': 'offline'}),
        throwsFormatException);
    expect(parseWatchProviderOffers({'stream': [], 'rent': [], 'buy': []}),
        isEmpty);
    expect(offer('rent').isIncludedOffer, isFalse);
    expect(offer('').isIncludedOffer, isFalse);
    expect(offer('flatrate').isIncludedOffer, isTrue);
    expect(offer('flatrate', name: 'Example Amazon Channel').matchKey,
        isNot(offer('flatrate', name: 'Amazon Prime Video').matchKey));
    expect(offer('rent', url: 'https://evil.example/watch').verifiedWatchUri,
        isNull);
    expect(
        offer('rent',
                url: 'https://www.themoviedb.org/movie/42/watch?locale=GB')
            .verifiedWatchUri,
        isNotNull);
  });
}
