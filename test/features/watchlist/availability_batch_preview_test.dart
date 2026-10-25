// Opt-in screenshots of production widgets with fictional availability data.
// WRITE_AVAILABILITY_BATCH_PREVIEWS=1 flutter test --no-pub test/features/watchlist/availability_batch_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flixie_app/core/storage/library_image_warmup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/presentation/widgets/notification_inbox/notification_inbox_view.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import '../../support/availability_batch_fixture.dart';

final _netflix = WatchProvider.fromJson({
  'id': 8,
  'providerName': 'Netflix',
  'availabilityTypes': ['flatrate'],
  'supportsGb': true,
  'movies': true,
});

class _PreviewAuth extends AvailabilityBatchAuth {
  @override
  User get dbUser => super.dbUser.copyWith(movieWatchlist: const [
        WatchlistMovie(
            id: 'fixture-alien',
            userId: 'viewer',
            movieId: 1,
            createdAt: '2026-10-23T10:00:00Z',
            movie: WatchlistMovieDetails(
                id: 1,
                title: 'Alien',
                posterPath: '/preview-alien.jpg',
                releaseDate: '1979-05-25',
                runtime: 117,
                genres: ['Science Fiction', 'Horror'])),
        WatchlistMovie(
            id: 'fixture-odyssey',
            userId: 'viewer',
            movieId: 2,
            movie: WatchlistMovieDetails(id: 2, title: 'The Odyssey')),
        WatchlistMovie(
            id: 'fixture-obsession',
            userId: 'viewer',
            movieId: 3,
            createdAt: '2026-10-22T10:00:00Z',
            movie: WatchlistMovieDetails(
                id: 3,
                title: 'Obsession',
                releaseDate: '2026-05-15',
                runtime: 108,
                genres: ['Horror', 'Thriller'])),
      ]);
  @override
  Set<int> get cachedUserWatchProviderIds => {8};
  @override
  Map<int, List<WatchProvider>> get cachedWatchProvidersByMovieId => {
        for (final id in ids) id: [_netflix],
      };
}

void main() {
  testWidgets('render batched inbox and filtered watchlist previews',
      (tester) async {
    if (Platform.environment['WRITE_AVAILABILITY_BATCH_PREVIEWS'] != '1') {
      return;
    }
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final family in ['Roboto', '.SF Pro Display']) {
      await (FontLoader(family)
            ..addFont(
                rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
          .load();
    }
    final poster = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
          await File('assets/images/why-flixie-alien.jpg').readAsBytes());
      return ImageInfo(image: (await codec.getNextFrame()).image);
    });
    final posterKey = await libraryPosterWarmupProvider(
            'https://image.tmdb.org/t/p/w342/preview-alien.jpg',
            tester.view.devicePixelRatio)
        .obtainKey(ImageConfiguration.empty);
    PaintingBinding.instance.imageCache.putIfAbsent(
        posterKey, () => OneFrameImageStreamCompleter(Future.value(poster!)));
    final fixture = AvailabilityBatchFixture(date: '2026-10-24');
    final auth = _PreviewAuth();
    ApiClient.useClientForTesting(fixture.client);
    addTearDown(() {
      ApiClient.useClientForTesting(null);
      fixture.dispose();
      auth.dispose();
    });
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const notice = FlixieNotification(
        id: 'fictional-movie-batch',
        userId: 'viewer',
        type: FlixieNotification.availabilityAlert,
        event: 'WATCHLIST_MOVIE_DIGEST',
        read: false,
        notificationReceived: '2026-10-24T08:15:00Z',
        message: 'Alien and Obsession are now listed on Netflix in GB.',
        data: {
          'count': '2',
          'mediaType': 'movie',
          'availabilityDate': '2026-10-24',
          'route': '/watchlist?availableOn=2026-10-24'
        });
    final router = GoRouter(initialLocation: '/notifications', routes: [
      GoRoute(
          path: '/notifications',
          builder: (context, _) => Scaffold(
                appBar: AppBar(
                    title: const Text('Notifications'),
                    leading: IconButton(
                        onPressed: () {}, icon: const Icon(Icons.arrow_back))),
                body: NotificationInboxView(
                    notifications: const [notice],
                    processingIds: const {},
                    loading: false,
                    error: null,
                    unreadCount: 1,
                    onRetry: () {},
                    onMarkAllRead: () {},
                    onDismiss: (_) {},
                    onOptions: (_) {},
                    onRespond: (_, __) {},
                    onOpen: (_, route) => context.push(route)),
              )),
      GoRoute(
          path: '/watchlist',
          builder: (_, state) => WatchlistScreen(
              availableOn: state.uri.queryParameters['availableOn'])),
    ]);
    addTearDown(router.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.darkTheme,
                routerConfig: router))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final dir = Directory('design/availability-alerts/review')
          ..createSync(recursive: true);
        final render =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final screenshot = await render.toImage(pixelRatio: 2);
        final bytes =
            await screenshot.toByteData(format: ui.ImageByteFormat.png);
        await File('${dir.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        screenshot.dispose();
      });
    }

    await capture('batch-notification');
    await tester.tap(find.text('View what’s available'));
    await tester.pumpAndSettle();
    expect(find.text('Newly available today'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture('batch-filtered-watchlist');
  });
}
