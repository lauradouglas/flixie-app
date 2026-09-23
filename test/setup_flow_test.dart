import 'dart:async';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/api_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/country.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/models/genre.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import 'package:flixie_app/features/authentication/presentation/pages/onboarding_screen.dart';
import 'support/watchlist_auth.dart';

class SetupFixture extends SetupService {
  bool failSave = false;
  Completer<List<SetupTitle>>? showLoad;
  List<WatchProvider> extraProviders = [];
  Country? savedCountry;
  Set<int>? selected;
  List<SetupTitle> taste = [];
  List<SetupTitle>? browseTitles;
  final added = <SetupTitle>[];
  @override
  Future<String?> referrer(String userId) async => null;
  @override
  Future<List<Country>> countries() async => [
        const Country(
            id: 1,
            abbreviation: 'GB',
            name: 'United Kingdom',
            nativeName: 'United Kingdom')
      ];
  @override
  Future<List<WatchProvider>> providers() async => [
        const WatchProvider(
            id: 8,
            providerName: 'Netflix',
            displayPriority: 1,
            logoPath: '',
            tvShows: true,
            movies: true,
            isVisible: true,
            supportsGb: false,
            supportsUs: false),
        ...extraProviders,
      ];
  @override
  Future<List<WatchProvider>> savedProviders(String id) async => [];
  @override
  Future<List<SetupTitle>> loadTaste(String id) async => [];
  @override
  Future<List<Genre>> genres() async => [];
  @override
  Future<void> saveWatching(
      String id, Country country, Set<int> providers) async {
    if (failSave) throw Exception('offline');
    savedCountry = country;
    selected = Set.of(providers);
  }

  @override
  Future<void> saveTaste(
      String id, List<SetupTitle> titles, Set<int> genres) async {
    taste = titles;
  }

  @override
  Future<List<SetupTitle>> popular(bool shows) async =>
      (shows && showLoad != null ? await showLoad!.future : null) ??
      browseTitles ??
      [
        SetupTitle(1, shows ? 'Fixture show' : 'Fixture movie', null,
            isShow: shows)
      ];
  @override
  Future<List<SetupTitle>> search(String query, bool shows) => popular(shows);
  @override
  Future<List<SetupTitle>> recommendations(List<SetupTitle> seeds) async =>
      [const SetupTitle(2, 'Your next show', null, isShow: true)];
  @override
  Future<List<WatchProvider>> availability(SetupTitle title, String region) =>
      providers();
  @override
  Future<void> addToWatchlist(String userId, SetupTitle title) async {
    added.add(title);
  }
}

class ApiShowsSetupFixture extends SetupFixture {
  @override
  Future<List<SetupTitle>> popular(bool shows) =>
      shows ? const SetupService().popular(true) : super.popular(false);
}

Widget setupApp(SetupFixture service,
        {double scale = 1, bool reduceMotion = false}) =>
    MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => TestAuth()),
          ChangeNotifierProvider<MovieRatingPrivacy>(
              create: (_) => MovieRatingPrivacy(loadRatings: (_) async => {})
                ..syncUser('viewer'))
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
                data: MediaQueryData(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: reduceMotion),
                child: OnboardingScreen(service: service))));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  test(
      'setup keeps services with absent regional flags and ranks familiar brands first',
      () {
    WatchProvider provider(String name, int priority) =>
        WatchProvider.fromJson({
          'id': priority + 1,
          'providerName': name,
          'displayPriority': priority,
        });
    final catalogue = [
      provider('MUBI', 0),
      provider('NOW TV Cinema', 1),
      provider('Amazon Prime Video', 2),
      provider('HBO Max', 3),
      provider('Disney Plus', 4),
      provider('Netflix', 5),
      provider('Apple TV', 6),
    ];
    expect(setupProviders(catalogue).map((p) => p.providerName), [
      'Apple TV',
      'Netflix',
      'Disney Plus',
      'HBO Max',
      'Amazon Prime Video',
      'NOW TV Cinema',
      'MUBI',
    ]);
    expect(setupProviders(catalogue, query: ' NETFLIX ').single.providerName,
        'Netflix');
  });

  test('movie suggestions mix current hits and classics without duplicates',
      () {
    MovieShort movie(int id) => MovieShort(id: id, name: 'Movie $id');
    final mixed = blendSetupMovies([movie(1), movie(2), movie(3)],
        [movie(4), movie(1), movie(5), movie(6)]);
    expect(mixed.map((m) => m.id), [1, 4, 2, 3, 5, 6]);
    expect(blendSetupMovies([], [movie(4)]).single.id, 4);
    expect(blendSetupMovies([movie(1)], []).single.id, 1);
  });

  test('setup adds movies and shows using user watchlist routes', () async {
    final requests = <String>[];
    useApiFixture(MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      return http.Response('{}', 200,
          headers: {'content-type': 'application/json'});
    }));
    const service = SetupService();
    await service.addToWatchlist('viewer', const SetupTitle(77, 'Movie', null));
    await service.addToWatchlist(
        'viewer', const SetupTitle(88, 'Show', null, isShow: true));
    await MovieService().removeFromWatchlist('viewer', 77);
    expect(requests, [
      'POST /users/viewer/movie/watchlist/77',
      'POST /users/viewer/show/watchlist/88',
      'DELETE /users/viewer/movie/watchlist/77',
    ]);
  });

  test(
      'setup saves movie and show favourites in selection order; skip writes none',
      () async {
    final requests = <http.Request>[];
    useApiFixture(MockClient((request) async {
      requests.add(request);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final show = body.containsKey('showIds');
      return http.Response(
          jsonEncode([
            {
              show ? 'showId' : 'movieId':
                  (body[show ? 'showIds' : 'movieIds'] as List).single,
              'removed': false
            }
          ]),
          200);
    }));
    const service = SetupService();
    await service.saveTaste('viewer', [
      const SetupTitle(12, 'First movie', null),
      const SetupTitle(12, 'First show', null, isShow: true),
      const SetupTitle(4, 'Second movie', null),
    ], {});
    expect(requests.map((r) => r.url.path), [
      '/users/viewer/movies/favorites',
      '/users/viewer/shows/favorites',
      '/users/viewer/movies/favorites',
    ]);
    expect(requests.map((r) => jsonDecode(r.body)), [
      {
        'movieIds': [12]
      },
      {
        'showIds': [12]
      },
      {
        'movieIds': [4]
      },
    ]);
    requests.clear();
    await service.saveTaste('viewer', [], {});
    expect(requests, isEmpty);
  });

  test(
      'setup rejects an empty successful favourites response and permits retry',
      () async {
    var saveWorks = false;
    useApiFixture(MockClient((request) async => http.Response(
        saveWorks ? '[{"movieId":12,"removed":false}]' : '[]', 200)));
    const service = SetupService();
    const picks = [SetupTitle(12, 'Movie', null)];
    await expectLater(service.saveTaste('viewer', picks, {}), throwsStateError);
    expect(await service.loadTaste('viewer'), isEmpty);
    saveWorks = true;
    await service.saveTaste('viewer', picks, {});
    expect((await service.loadTaste('viewer')).single.id, 12);
  });

  testWidgets(
      'switching to shows explains loading and hides stale movie results',
      (tester) async {
    final service = SetupFixture();
    await tester.pumpWidget(setupApp(service));
    await tester.pumpAndSettle();
    await tap(tester, 'Skip for now');
    expect(find.byKey(const ValueKey('taste-movie:1')), findsOneWidget);
    service.showLoad = Completer<List<SetupTitle>>();
    await tester.ensureVisible(find.text('Shows'));
    await tester.tap(find.text('Shows'));
    await tester.pump();
    expect(find.text('Loading shows…'), findsOneWidget);
    expect(find.byKey(const ValueKey('taste-movie:1')), findsNothing);
    service.showLoad!
        .complete([const SetupTitle(2, 'A show', null, isShow: true)]);
    await tester.pumpAndSettle();
    expect(find.text('Loading shows…'), findsNothing);
    expect(find.byKey(const ValueKey('taste-show:2')), findsOneWidget);
  });

  testWidgets('Shows loads the backend weekly route and saves a selected show',
      (tester) async {
    final paths = <String>[];
    useApiFixture(MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/shows/top_rated')) {
        return http.Response(
            jsonEncode([
              {
                'id': 88,
                'title': 'Classic fixture show',
                'poster': '/classic.jpg'
              },
              {
                'id': 77,
                'title': 'Trending fixture show',
                'poster': '/fixture-show-poster.jpg'
              },
            ]),
            200,
            headers: {'content-type': 'application/json'});
      }
      if (!request.url.path.endsWith('/trending/show/week')) {
        return http.Response('Cannot GET ${request.url.path}', 404);
      }
      return http.Response(
          jsonEncode([
            {
              'id': 77,
              'name': 'Trending fixture show',
              'poster': '/fixture-show-poster.jpg'
            }
          ]),
          200,
          headers: {'content-type': 'application/json'});
    }));
    final service = ApiShowsSetupFixture();
    await tester.pumpWidget(setupApp(service));
    await tester.pumpAndSettle();
    await tap(tester, 'Skip for now');
    await tap(tester, 'Shows');
    expect(paths, contains(endsWith('/trending/show/week')));
    expect(paths, contains(endsWith('/shows/top_rated')));
    expect(find.byKey(const ValueKey('taste-show:88')), findsOneWidget);
    expect(find.byKey(const ValueKey('taste-show:77')), findsOneWidget);
    expect(find.text('Classic fixture show'), findsOneWidget);
    expect(find.text('Couldn’t load titles. Try again.'), findsNothing);
    final show = find.byKey(const ValueKey('taste-show:77'));
    await tester.ensureVisible(show);
    await tester.tap(show);
    await tester.pumpAndSettle();
    await tap(tester, 'Continue');
    expect(service.taste.single.key, 'show:77');
    expect(service.taste.single.poster, '/fixture-show-poster.jpg');
    expect(find.byType(FlixieWordmark), findsOneWidget);
  });

  testWidgets('country action opens picker before continuing to services',
      (tester) async {
    await tester.pumpWidget(setupApp(SetupFixture()));
    await tester.pumpAndSettle();
    expect(find.text('Choose your country to get started'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Choose country').hitTestable(), findsOneWidget);
    expect(find.text('Search streaming services'), findsNothing);
    await tester.tap(find.text('Choose country'));
    await tester.pumpAndSettle();
    await tap(tester, 'United Kingdom');
    expect(find.text('Continue').hitTestable(), findsOneWidget);
    expect(find.text('Search streaming services'), findsOneWidget);
    expect(find.text('Choose your country to get started'), findsNothing);
  });

  testWidgets('all services can be scrolled to and selected without expanding',
      (tester) async {
    final service = SetupFixture()
      ..extraProviders = List.generate(
          15,
          (index) => WatchProvider.fromJson({
                'id': 100 + index,
                'providerName': 'Service $index',
                'displayPriority': index,
                'isVisible': true,
              }));
    await tester.pumpWidget(setupApp(service));
    await tester.pumpAndSettle();
    await tap(tester, 'Choose country');
    await tap(tester, 'United Kingdom');
    expect(find.text('Show all services'), findsNothing);
    expect(tester.getTopLeft(find.text('Netflix')).dy,
        lessThan(tester.getTopLeft(find.text('Service 0')).dy));
    final continuePosition = tester.getTopLeft(find.text('Continue'));
    expect(find.text('Continue').hitTestable(), findsOneWidget);
    expect(find.text('Skip for now').hitTestable(), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Service 14'), 300,
        scrollable: find.byType(Scrollable).first);
    await tap(tester, 'Service 14');
    expect(tester.getTopLeft(find.text('Continue')), continuePosition);
    expect(find.text('Continue').hitTestable(), findsOneWidget);
    expect(find.text('Skip for now').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(service.selected, {114});
    expect(find.text('Your taste.\nBetter discoveries.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'country and services save together; failure preserves choices for retry',
      (tester) async {
    final service = SetupFixture();
    await tester.pumpWidget(setupApp(service));
    await tester.pumpAndSettle();
    await tap(tester, 'Choose country');
    await tap(tester, 'United Kingdom');
    await tap(tester, 'Netflix');
    expect(find.text('Your services · 1 selected'), findsOneWidget);
    service.failSave = true;
    await tap(tester, 'Continue');
    expect(find.textContaining('Couldn’t save this step'), findsOneWidget);
    expect(find.text('Less searching.\nMore watching.'), findsOneWidget);
    service.failSave = false;
    await tap(tester, 'Continue');
    expect(service.savedCountry?.id, 1);
    expect(service.selected, {8});
    expect(find.text('Your taste.\nBetter discoveries.'), findsOneWidget);
  });
  testWidgets(
      'movie and show with same id stay separate; suggestions add a show',
      (tester) async {
    final service = SetupFixture();
    await tester.pumpWidget(setupApp(service));
    await tester.pumpAndSettle();
    await tap(tester, 'Skip for now');
    await tester.ensureVisible(find.byKey(const ValueKey('taste-movie:1')));
    await tester.tap(find.byKey(const ValueKey('taste-movie:1')));
    await tester.pumpAndSettle();
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    await tap(tester, 'Shows');
    expect(
        tester.widget<RawChip>(find.widgetWithText(RawChip, 'Shows')).selected,
        isTrue);
    expect(
        tester.widget<RawChip>(find.widgetWithText(RawChip, 'Movies')).selected,
        isFalse);
    await tester.ensureVisible(find.byKey(const ValueKey('taste-show:1')));
    await tester.tap(find.byKey(const ValueKey('taste-show:1')));
    await tester.pumpAndSettle();
    await tap(tester, 'Continue');
    expect(service.taste.map((t) => t.key), ['movie:1', 'show:1']);
    await tap(tester, 'Show my picks');
    await tap(tester, 'Add to watchlist');
    expect(service.added.single.isShow, isTrue);
    expect(find.text('Added'), findsOneWidget);
    expect(find.text('Take an optional tour'), findsOneWidget);
  });
  testWidgets(
      'taste limit, deselection and pinned preferences preserve choices',
      (tester) async {
    final service = SetupFixture()
      ..browseTitles = List.generate(
          6, (index) => SetupTitle(index + 1, 'Pick $index', null));
    await tester.pumpWidget(setupApp(service));
    await tester.pumpAndSettle();
    await tap(tester, 'Skip for now');
    for (var id = 1; id <= 5; id++) {
      final tile = find.byKey(ValueKey('taste-movie:$id'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }
    expect(
        find.textContaining('5 of 5 selected').hitTestable(), findsOneWidget);
    final sixth = find.byKey(const ValueKey('taste-movie:6'));
    await tester.ensureVisible(sixth);
    await tester.tap(sixth);
    await tester.pumpAndSettle();
    expect(find.text('Five selected. Remove one to make room for another.'),
        findsOneWidget);
    final first = find.byKey(const ValueKey('taste-movie:1'));
    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(sixth);
    await tester.tap(sixth);
    await tester.pumpAndSettle();
    await tap(tester, 'Continue');
    expect(service.taste.map((title) => title.id), [2, 3, 4, 5, 6]);
    expect(find.text('Show my picks').hitTestable(), findsOneWidget);
    expect(find.text('Keep current preferences').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('step progress animates and respects reduced motion',
      (tester) async {
    for (final reduceMotion in [false, true]) {
      await tester.pumpWidget(const SizedBox());
      await tester
          .pumpWidget(setupApp(SetupFixture(), reduceMotion: reduceMotion));
      await tester.pumpAndSettle();
      expect(find.text('Find your next watch—and where to stream it.'),
          findsOneWidget);
      expect(
          tester
              .widget<LinearProgressIndicator>(
                  find.byKey(const ValueKey('setup-progress-0')))
              .value,
          1);
      await tester.tap(find.text('Skip for now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final progress = tester
          .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('setup-progress-1')))
          .value!;
      if (reduceMotion) {
        expect(progress, 1);
      } else {
        expect(progress, greaterThan(0));
        expect(progress, lessThan(1));
      }
      await tester.pumpAndSettle();
      expect(find.text('Your taste.\nBetter discoveries.'), findsOneWidget);
      expect(find.text('Less searching.\nMore watching.'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('optional taste can be skipped without fabricating favourites',
      (tester) async {
    final service = SetupFixture();
    await tester.pumpWidget(setupApp(service));
    await tester.pumpAndSettle();
    await tap(tester, 'Skip for now');
    await tap(tester, 'Skip taste picks');
    expect(service.taste, isEmpty);
    await tap(tester, 'Keep current preferences');
    expect(find.text('Popular picks to get you started'), findsOneWidget);
  });
  testWidgets('setup reflows across screen sizes and large text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [
      const Size(320, 640),
      const Size(430, 932),
      const Size(844, 390),
      const Size(1024, 768)
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(setupApp(SetupFixture(), scale: 2));
      await tester.pumpAndSettle();
      await tap(tester, 'Choose country');
      await tap(tester, 'United Kingdom');
      await tap(tester, 'Netflix');
      expect(find.text('Continue').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tap(tester, 'Continue');
      final tile = find.byKey(const ValueKey('taste-movie:1'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(
          find.textContaining('1 of 5 selected').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tap(tester, 'Skip taste picks');
      expect(tester.takeException(), isNull);
      await tap(tester, 'Keep current preferences');
      expect(tester.takeException(), isNull);
    }
  });
  test(
      'taste seeds survive restart, remain account scoped and distinguish media',
      () async {
    await SetupTasteStore.save('alice', [
      const SetupTitle(1, 'Movie', null),
      const SetupTitle(1, 'Show', null, isShow: true)
    ]);
    expect((await SetupTasteStore.load('alice')).map((t) => t.key),
        ['movie:1', 'show:1']);
    expect(await SetupTasteStore.load('bob'), isEmpty);
  });
  test(
      'setup uses the TV search contract and persists country with service IDs',
      () async {
    final requests = <http.Request>[];
    useApiFixture(MockClient((request) async {
      requests.add(request);
      return http.Response(
          jsonEncode(request.url.path.endsWith('/search')
              ? {
                  'results': [
                    {'id': 77, 'name': 'A show', 'media_type': 'tv'}
                  ]
                }
              : {'id': 'viewer', 'username': 'Viewer', 'email': ''}),
          200,
          headers: {'content-type': 'application/json'});
    }));
    const service = SetupService();
    final result = await service.search('show', true);
    expect(requests.single.url.queryParameters['type'], 'tv');
    expect(result.single.isShow, isTrue);
    await service.saveWatching(
        'viewer',
        const Country(id: 1, abbreviation: 'GB', name: 'UK', nativeName: 'UK'),
        {8});
    expect(jsonDecode(requests[1].body), {'countryId': 1});
    expect(jsonDecode(requests[2].body), {
      'watchProviderIds': [8]
    });
    expect(requests[2].method, 'PUT');
  });
}
