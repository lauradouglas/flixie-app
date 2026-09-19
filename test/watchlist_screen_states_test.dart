import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'watchlist_recommendation_batch_test.dart' show TestAuth, item, response;

WatchProvider provider(String type) => WatchProvider(
    id: 1,
    providerName: 'Saved service',
    displayPriority: 1,
    logoPath: '',
    tvShows: true,
    movies: true,
    isVisible: true,
    supportsGb: true,
    supportsUs: true,
    availabilityTypes: {type});

class ScreenAuth extends TestAuth {
  Set<int> services = {1};
  @override
  User get dbUser => User(
          id: 'viewer',
          username: 'Me',
          email: '',
          iconColorId: 0,
          completedSetup: true,
          darkMode: true,
          movieWatchlist: [
            for (final id in [1, 2])
              WatchlistMovie(
                  id: '$id',
                  userId: 'viewer',
                  movieId: id,
                  movie: WatchlistMovieDetails(
                      id: id,
                      title: id == 1
                          ? 'A title with an included offer'
                          : 'A rental on the same service',
                      releaseDate: '2020-01-01',
                      runtime: 132))
          ],
          showWatchlist: [
            {
              'showId': 3,
              'show': {
                'id': 3,
                'title': 'A show my friends watched',
                'firstAirDate': '2022-01-01',
                'numberOfSeasons': 2
              }
            }
          ]);
  @override
  Map<int, List<WatchProvider>> get cachedWatchProvidersByMovieId => {
        1: [provider('flatrate')],
        2: [provider('rent')]
      };
  @override
  Set<int> get cachedUserWatchProviderIds => services;
}

class MissingShowAuth extends ScreenAuth {
  @override
  User get dbUser => super.dbUser.copyWith(movieWatchlist: [], showWatchlist: [
        {'showId': 15621, 'createdAt': '2026-09-12T12:00:00Z'},
      ]);
}

http.Response handle(http.Request request) {
  if (request.url.path.endsWith('friend-recommendations')) {
    final body = jsonDecode(request.body) as Map;
    final ids = body['movieIds'] ?? body['showIds'];
    return response({
      'items': (ids as List)
          .map((id) => {
                ...item(id),
                'friends': id == 2
                    ? []
                    : [
                        {
                          'userId': 'a',
                          'username': 'Alice',
                          'profileBadges': ['FOUNDER'],
                          'watched': true,
                          'rating': 8,
                          'recommends': false,
                          'ratingScope': id == 3 ? 'show' : 'movie'
                        },
                        {
                          'userId': 'b',
                          'username': 'Mia',
                          'profileBadges': [],
                          'watched': true,
                          'rating': null,
                          'recommends': false,
                          'ratingScope': id == 3 ? 'show' : 'movie'
                        }
                      ]
              })
          .toList()
    });
  }
  if (request.url.path.endsWith('/watch-providers')) {
    return response({
      'watchProviders': [
        {'id': 1, 'providerName': 'Saved service'}
      ]
    });
  }
  return response({'stream': [], 'rent': [], 'buy': []});
}

void main() {
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets('genre filtering needs no request input or matching API',
      (tester) async {
    final auth = ScreenAuth();
    addTearDown(auth.dispose);
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: AppTheme.darkTheme, home: const WatchlistScreen())));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Genre'));
      await tester.tap(find.text('Genre'));
      await tester.pumpAndSettle();
      expect(find.text('What do you fancy?'), findsNothing);
      await tester.tap(find.text('Rom com'));
      await tester.pumpAndSettle();
      expect(find.text('A title with an included offer'), findsNothing);
      await tester.tap(find.text('Rom com'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All genres'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text('A title with an included offer'), 150,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('A title with an included offer'), findsOneWidget);
    },
        () => MockClient((request) async {
              expect(request.url.path.endsWith('/watchlist-fit'), false);
              return handle(request);
            }));
  });
  testWidgets(
      'tonight time limit filters the actual list and clearing restores it',
      (tester) async {
    final auth = ScreenAuth();
    addTearDown(auth.dispose);
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: AppTheme.darkTheme, home: const WatchlistScreen())));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Time'), 180,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.ancestor(
          of: find.text('Time'), matching: find.byType(FlixiePill)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('90 min'), 180,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('90 min'));
      await tester.pumpAndSettle();
      expect(find.text('Date added · 0'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('No watchlist matches'), 180,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('No watchlist matches'), findsOneWidget);
      await tester.tap(find.text('Clear filters').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text('A title with an included offer'), 180,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('A title with an included offer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async => handle(request)));
  });

  testWidgets('ID-only saved show loads its title, poster and season details',
      (tester) async {
    final auth = MissingShowAuth();
    addTearDown(auth.dispose);
    var detailBatches = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: AppTheme.darkTheme, home: const WatchlistScreen())));
      await tester.pumpAndSettle();
      expect(find.text('The Newsroom'), findsOneWidget);
      expect(find.text('TV show'), findsNothing);
      expect(find.textContaining('3 seasons'), findsOneWidget);
      expect(detailBatches, 1);
      auth.notifyOnly();
      await tester.pumpAndSettle();
      expect(detailBatches, 1);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/shows/by-ids')) {
                detailBatches++;
                expect(jsonDecode(request.body)['ids'], [15621]);
                return response([
                  {
                    'id': 15621,
                    'name': 'The Newsroom',
                    'poster_path': '/newsroom.jpg',
                    'first_air_date': '2012-06-24',
                    'number_of_seasons': 3,
                    'genres': [
                      {'name': 'Drama'}
                    ]
                  }
                ]);
              }
              return handle(request);
            }));
  });

  testWidgets('search services stay local when saved subscriptions change',
      (tester) async {
    final auth = ScreenAuth();
    addTearDown(auth.dispose);
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: AppTheme.darkTheme, home: const WatchlistScreen())));
      await tester.pumpAndSettle();
      await tester.tap(find.ancestor(
          of: find.text('Services'), matching: find.byType(FlixiePill)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use for this search'));
      await tester.pumpAndSettle();
      expect(find.text('A title with an included offer'), findsOneWidget);
      auth.services = {};
      auth.notifyOnly();
      await tester.pumpAndSettle();
      expect(find.text('A title with an included offer'), findsOneWidget);
    }, () => MockClient((request) async => handle(request)));
  });
  test('movie fallback preserves region, nested offers and rental semantics',
      () async {
    final movieService = MovieService()..clearCache();
    await http.runWithClient(() async {
      final offers = await movieService.getMovieWatchProviders(90001, 'US');
      expect(offers.single.isRental, isTrue);
      expect(offers.single.isIncludedOffer, isFalse);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/US/watch/providers')) {
                return response({'message': 'missing'}, 404);
              }
              expect(request.url.queryParameters['countryCode'], 'US');
              return response({
                'watchProviders': {
                  'stream': [],
                  'buy': [],
                  'rent': [
                    {'id': 1, 'providerName': 'Store'}
                  ]
                }
              });
            }));
  });
  test(
      'TV batches are bounded, deduplicated and partial failures remain absent',
      () async {
    var calls = 0;
    await http.runWithClient(() async {
      final result = await ShowService.getFriendRecommendations(
          [...List.generate(51, (i) => i + 1), 1]);
      expect(result.length, 26);
      expect(result.keys, containsAll([1, 25, 51]));
    },
        () => MockClient((request) async {
              calls++;
              final ids = jsonDecode(request.body)['showIds'] as List;
              expect(ids.length, lessThanOrEqualTo(25));
              if (calls == 2) return response({'message': 'offline'}, 503);
              return response({'items': ids.map((id) => item(id)).toList()});
            }));
    expect(calls, 3);
  });
  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(834, 1194),
    const Size(844, 390)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('full screen, shortcuts and clear recovery $size text $scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = ScreenAuth();
        addTearDown(auth.dispose);
        final key = GlobalKey();
        await http.runWithClient(() async {
          await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: MaterialApp(
                  theme: AppTheme.darkTheme,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!),
                  home: RepaintBoundary(
                      key: key,
                      child: const ColoredBox(
                          color: FlixieColors.background,
                          child: WatchlistScreen())))));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (Platform.environment['WATCHLIST_CAPTURE'] == '1' && scale == 1) {
            await tester.runAsync(() async {
              final boundary = key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
              final image = await boundary.toImage();
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              await File('/tmp/watchlist-screen-${size.width.toInt()}.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
            });
          }
          await tester.ensureVisible(find.text('Services'));
          await tester.tap(find.ancestor(
              of: find.text('Services'), matching: find.byType(FlixiePill)));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Use for this search'));
          await tester.pumpAndSettle();
          expect(find.text('A rental on the same service'), findsNothing);
          // Clear via the toolbar, then verify the friends shortcut includes TV.
          await tester.ensureVisible(find.byTooltip('More watchlist filters'));
          await tester.tap(find.byTooltip('More watchlist filters'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Clear filters').first);
          await tester.tap(find.text('Clear filters').first);
          Navigator.of(tester.element(find.text('More watchlist filters')))
              .pop();
          await tester.pumpAndSettle();
          await Scrollable.ensureVisible(
              tester.element(find.byTooltip('More watchlist filters')),
              alignment: .5);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('More watchlist filters'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text('Friends watched'), -150,
              scrollable: find.byType(Scrollable).first);
          await Scrollable.ensureVisible(
              tester.element(find.text('Friends watched')),
              alignment: .5);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Friends watched'));
          await tester.pumpAndSettle();
          expect(
              tester
                  .widget<Semantics>(find.bySemanticsLabel('Friends watched'))
                  .properties
                  .checked,
              isTrue);
          await tester.pumpAndSettle();
          Navigator.of(tester.element(find.text('Friends watched'))).pop();
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text('Shows'), -150,
              scrollable: find.byType(Scrollable).first);
          await Scrollable.ensureVisible(tester.element(find.text('Shows')),
              alignment: .5);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Shows'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
              find.text('A show my friends watched'), 150,
              scrollable: find.byType(Scrollable).first);
          expect(find.text('A show my friends watched'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }, () => MockClient((request) async => handle(request)));
      });
    }
  }
}
