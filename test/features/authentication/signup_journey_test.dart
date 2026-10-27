import 'package:flixie_app/features/settings/data/availability_alert_service.dart';
import 'package:flixie_app/features/taste/data/taste_setup_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/watchlist/data/guest_watchlist_store.dart';
import 'package:flixie_app/features/authentication/presentation/widgets/signup_title_context.dart';
import 'package:flutter/services.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import 'package:flixie_app/features/authentication/data/signup_journey_service.dart';
import 'package:flixie_app/features/authentication/models/signup_journey.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_journey_page.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/movies/models/external_watch_invite.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/country.dart';
import 'package:flixie_app/models/watch_provider.dart';
import '../movies/movie_detail_action_flow_test.dart'
    show ActionAuth, ActionAnalytics;

class JourneyAuth extends ActionAuth {
  JourneyAuth() {
    account = const User(
        id: 'fixture',
        username: 'FilmFan',
        email: 'filmfan@example.invalid',
        completedSetup: false,
        darkMode: true,
        iconColorId: 1);
  }
  int finishes = 0, refreshes = 0;
  @override
  Future<bool> completeOnboarding() async {
    finishes++;
    account = account!.copyWith(completedSetup: true);
    notifyListeners();
    return false;
  }

  @override
  Future<bool> refreshLibrary() async {
    refreshes++;
    return true;
  }
}

class JourneyData extends SignupJourneyService {
  final saves = <String>[], favourites = <String>[];
  final logs = <LogMovieWatchRequest>[];
  int ratings = 0, episodes = 0;
  bool failSave = false, failRate = false;
  Completer<void>? saveGate;
  @override
  Future<SetupTitle> title(SignupJourney journey) async => SetupTitle(
      journey.mediaId, journey.isShow ? 'The Newsroom' : 'Alien', null,
      isShow: journey.isShow);
  @override
  Future<({String? releaseDate, String? status})> movieRelease(int id) async =>
      (releaseDate: '1979-01-01', status: 'Released');
  @override
  Future<List<SetupTitle>> suggestions(SetupTitle title) async => const [
        SetupTitle(157336, 'Interstellar', null,
            reason: 'Because you chose Alien'),
        SetupTitle(238, 'The Godfather', null, reason: 'Trending now'),
        SetupTitle(1396, 'Breaking Bad', null,
            isShow: true, reason: 'Trending now')
      ];
  @override
  Future<List<SetupTitle>> initialSuggestions() =>
      suggestions(const SetupTitle(348, 'Alien', null));
  @override
  Future<void> saveTitle(String userId, SetupTitle title,
      {bool favourite = false}) async {
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('Offline');
    (favourite ? favourites : saves).add(title.key);
  }

  @override
  Future<void> rate(
      SignupJourney journey, int rating, String? recommendation) async {
    if (failRate) throw StateError('Offline');
    ratings++;
  }

  @override
  Future<MovieWatchEntry> log(
      String userId, LogMovieWatchRequest request) async {
    logs.add(request);
    return MovieWatchEntry(
        id: 'viewing-1',
        userId: userId,
        movieId: request.movieId,
        watchedAt: request.watchedAt,
        rating: request.rating,
        removed: false,
        externalInvite: request.externalCompanionName == null
            ? null
            : ExternalWatchInvite(
                id: 'invite-for-viewing-1',
                displayName: request.externalCompanionName!));
  }

  @override
  Future<void> episode(SignupJourney journey) async {
    episodes++;
  }
}

class JourneySetup extends SetupService {
  bool _publicSharing = true;
  @override
  Future<bool> sharing() async => _publicSharing;
  @override
  Future<void> setSharing(bool value) async {
    _publicSharing = value;
  }

  @override
  Future<AvailabilityAlertSettings> availabilityAlerts() async =>
      const AvailabilityAlertSettings(enabled: false);
  @override
  Future<void> saveAvailabilityAlerts(bool enabled) async {}
  @override
  Future<bool> enableAvailabilityPush() async => true;
  @override
  Future<List<Country>> countries() async => const [
        Country(
            id: 1,
            abbreviation: 'GB',
            name: 'United Kingdom',
            nativeName: 'United Kingdom')
      ];
  @override
  Future<List<WatchProvider>> providers() async => const [
        WatchProvider(
            id: 1,
            providerName: 'Netflix',
            displayPriority: 1,
            logoPath: '',
            tvShows: true,
            movies: true,
            isVisible: true,
            supportsGb: true,
            supportsUs: true)
      ];
  @override
  Future<List<WatchProvider>> savedProviders(String id) async => [];
  @override
  Future<void> saveWatching(
      String id, Country country, Set<int> providers) async {}
}

class PosterSearchSetup extends JourneySetup {
  @override
  Future<List<SetupTitle>> search(String query, bool shows) async => [
        SetupTitle(557, shows ? 'Spider-Man TV' : 'Spider-Man',
            '/spider-man-fixture.jpg',
            isShow: shows)
      ];
}

Future<GoRouter> pumpJourney(
    WidgetTester tester, String action, JourneyData data, JourneyAuth auth,
    {bool show = false,
    GlobalKey? boundary,
    SetupService? setup,
    String? diaryDraftId}) async {
  final request = SignupJourney(
      userId: 'fixture',
      diaryDraftId: diaryDraftId,
      action: action,
      path: action == 'guest-watchlist'
          ? '/guest-watchlist'
          : action == 'home'
              ? '/'
              : action == 'profile'
                  ? '/profile'
                  : show
                      ? '/shows/1547'
                      : '/movies/348',
      episodeId: action == 'episode' ? 7 : null,
      seasonNumber: action == 'episode' ? 1 : null,
      episodeNumber: action == 'episode' ? 2 : null,
      episodeTitle: action == 'episode' ? 'Cat’s in the Bag…' : null);
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) => SignupJourneyPage(
            journey: request, service: data, setup: setup ?? JourneySetup())),
    for (final path in [
      '/watchlist',
      '/movies/348',
      '/shows/1547',
      '/profile',
      '/search'
    ])
      GoRoute(
          path: path,
          builder: (_, __) => Scaffold(body: Text('Destination $path'))),
  ]);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<AnalyticsController>.value(
            value: ActionAnalytics()),
      ],
      child: RepaintBoundary(
          key: boundary,
          child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              routerConfig: router))));
  await tester.pump();
  await tester.pump();
  return router;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GuestAccess.clear();
    ApiClient.setToken('isolated-fixture');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            SystemChannels.platform, (call) async => null);
  });
  tearDown(() {
    GuestAccess.clear();
    ApiClient.useClientForTesting(null);
    ApiClient.setToken(null);
  });
  test(
      'claiming binds every supported action to its account and exact destination',
      () {
    for (final (action, path) in [
      ('watchlist', '/movies/348'),
      ('rate', '/shows/1547'),
      ('review', '/movies/348'),
      ('episode', '/shows/1547'),
      ('season', '/shows/1547'),
      ('list', '/movies/348'),
      ('favorite', '/people/525'),
      ('collection', '/collections/8091'),
      ('plan', '/movies/348'),
      ('providers', '/movies/348'),
      ('post-score', '/play/popcorn-catch'),
      ('home', '/'),
      ('profile', '/profile'),
      ('community', '/genre-communities/27'),
      (
        'discussion',
        '/community/posts/fictional-viewer/MOVIE_REVIEW/fictional-review'
      )
    ]) {
      GuestAccess.clear();
      GuestAccess.action = action;
      GuestAccess.destination = path;
      GuestAccess.episodeId = 7;
      GuestAccess.seasonNumber = 2;
      GuestAccess.awaitingAccount = true;
      final claimed = GuestAccess.claimJourney('fixture');
      expect(claimed, isNotNull, reason: action);
      expect(claimed!.path, path);
      expect(claimed.action, action);
      expect(claimed.episodeId, 7);
      expect(claimed.seasonNumber, 2);
      expect(GuestAccess.claimJourney('other-account'), isNull);
    }
    expect(SignupJourney.supports('log', '/shows/1547'), isFalse);
    expect(
        SignupJourney.supports('watchlist', 'https://example.com/movies/348'),
        isFalse);
  });
  testWidgets(
      'existing list editor receives its original intent without generic setup',
      (tester) async {
    final auth = JourneyAuth();
    final data = JourneyData();
    final router = await pumpJourney(tester, 'list', data, auth);
    await tester.pumpAndSettle();
    expect(auth.finishes, 1);
    expect(data.saves, isEmpty);
    expect(find.text('Destination /movies/348'), findsOneWidget);
    expect(GuestAccess.takeAction('/movies/348'), 'list');
    router.dispose();
  });
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 768)
  ]) {
    testWidgets(
        'poster results and first-action layout reflow at $size with larger text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final router =
          await pumpJourney(tester, 'watchlist', JourneyData(), JourneyAuth());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      router.dispose();
    });
  }
  test(
      'real journey persistence uses ratings, idempotent watch and watched membership APIs',
      () async {
    final writes = <(String, Map<String, dynamic>)>[];
    ApiClient.useClientForTesting(MockClient((request) async {
      writes.add((
        request.url.path,
        Map<String, dynamic>.from(jsonDecode(request.body) as Map)
      ));
      return http.Response(
          jsonEncode({
            'id': 'saved-viewing',
            'userId': 'fixture',
            'movieId': 348,
            'removed': false
          }),
          200);
    }));
    const service = SignupJourneyService();
    await service.rate(
        const SignupJourney(
            userId: 'fixture', action: 'rate', path: '/movies/348'),
        8,
        'recommend');
    await service.rate(
        const SignupJourney(
            userId: 'fixture', action: 'rate', path: '/shows/1547'),
        9,
        'avoid');
    expect(
        writes[0].$2, {'userId': 'fixture', 'rating': 8, 'recommended': true});
    expect(writes[1].$2,
        {'userId': 'fixture', 'rating': 9, 'recommendation': 'avoid'});
    final saved = await service.log(
        'fixture',
        const LogMovieWatchRequest(
            movieId: 348,
            draftId: 'stable-draft',
            externalCompanionName: 'Sam'));
    expect(saved.id, 'saved-viewing');
    expect(writes[2].$1, endsWith('/watch-requests/log-watch'));
    expect(writes[2].$2['draftId'], 'stable-draft');
    expect(writes[2].$2['externalCompanionName'], 'Sam');
    expect(writes[3].$1, endsWith('/users/fixture/movie/watched/348'));
  });
  testWidgets('search shows poster cards and keeps film and TV modes',
      (tester) async {
    final router = await pumpJourney(
        tester, 'watchlist', JourneyData(), JourneyAuth(),
        setup: PosterSearchSetup());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Spider');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Spider-Man'), findsOneWidget);
    final poster = tester.widget<Image>(find.byType(Image));
    expect((poster.image as NetworkImage).url,
        endsWith('/spider-man-fixture.jpg'));
    await tester.tap(find.text('TV shows'));
    await tester.pumpAndSettle();
    expect(find.text('Spider-Man TV'), findsOneWidget);
    router.dispose();
  });
  test('related and trending are interleaved and deduplicated by media type',
      () {
    final rows = mixJourneySuggestions(const [
      SetupTitle(1, 'Related', null),
      SetupTitle(2, 'Overlap', null)
    ], const [
      SetupTitle(2, 'Overlap', null),
      SetupTitle(1, 'TV same ID', null, isShow: true),
      SetupTitle(3, 'Original', null)
    ], exclude: 'movie:3');
    expect(rows.map((t) => t.key), ['movie:1', 'movie:2', 'show:1']);
  });
  testWidgets(
      'original watchlist save precedes suggestions and optional services; skip finishes',
      (tester) async {
    final data = JourneyData()..saveGate = Completer<void>();
    final auth = JourneyAuth();
    final router = await pumpJourney(tester, 'watchlist', data, auth);
    expect(find.text('Anything else for later?'), findsNothing);
    expect(auth.finishes, 0);
    data.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(data.saves, ['movie:348']);
    expect(find.text('Anything else for later?'), findsOneWidget);
    expect(auth.finishes, 0);
    await tester.tap(find.byTooltip('Save Interstellar'));
    await tester.pumpAndSettle();
    expect(data.saves, ['movie:348', 'movie:157336']);
    await tester.ensureVisible(find.text('Continue').first);
    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();
    expect(find.text('Where do you watch?'), findsOneWidget);
    expect(auth.finishes, 0);
    await tester.ensureVisible(find.text('Skip for now'));
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(auth.finishes, 1);
    expect(auth.refreshes, 1);
    expect(find.text('Destination /watchlist'), findsOneWidget);
    router.dispose();
  });
  testWidgets(
      'guest collection saves all picks before optional setup and retries safely',
      (tester) async {
    final store = GuestWatchlistStore.instance;
    await store.toggle(const SetupTitle(348, 'Alien', null));
    await store.toggle(const SetupTitle(157336, 'Interstellar', null));
    final data = JourneyData()..failSave = true;
    final auth = JourneyAuth();
    final router = await pumpJourney(tester, 'guest-watchlist', data, auth);
    await tester.pumpAndSettle();
    expect(find.text('Anything else for later?'), findsNothing);
    expect(await store.read(), hasLength(2));
    expect(auth.finishes, 0);
    data.failSave = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(data.saves, ['movie:348', 'movie:157336']);
    expect(await store.read(), isEmpty);
    expect(find.text('Anything else for later?'), findsOneWidget);
    expect(auth.finishes, 0);
    router.dispose();
  });
  testWidgets('failed bookmark retries without optional setup appearing first',
      (tester) async {
    final data = JourneyData()..failSave = true;
    final auth = JourneyAuth();
    final router = await pumpJourney(tester, 'watchlist', data, auth);
    await tester.pumpAndSettle();
    expect(find.text('Anything else for later?'), findsNothing);
    expect(auth.finishes, 0);
    data.failSave = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(data.saves, ['movie:348']);
    expect(find.text('Anything else for later?'), findsOneWidget);
    router.dispose();
  });
  for (final show in [false, true]) {
    testWidgets(
        '${show ? 'show' : 'film'} rating requires a score and saves before heart favourites',
        (tester) async {
      final data = JourneyData()..failRate = true;
      final auth = JourneyAuth();
      final router = await pumpJourney(tester, 'rate', data, auth, show: show);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Save rating'))
              .onPressed,
          isNull);
      await tester.tap(find.widgetWithText(FlixiePill, '8'));
      await tester.pump();
      await tester.tap(find.text('Save rating'));
      await tester.pumpAndSettle();
      expect(find.text('Your rating couldn’t be saved. Try again.'),
          findsOneWidget);
      expect(data.ratings, 0);
      data.failRate = false;
      await tester.tap(find.text('Save rating'));
      await tester.pumpAndSettle();
      expect(data.ratings, 1);
      expect(find.text('Any all-time favourites?'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsWidgets);
      await tester.tap(find.byTooltip('Add Interstellar to favourites'));
      await tester.pumpAndSettle();
      expect(data.favourites, ['movie:157336']);
      expect(auth.finishes, 0);
      router.dispose();
    });
  }
  testWidgets('home starts with purpose and profile starts with favourites',
      (tester) async {
    final home =
        await pumpJourney(tester, 'home', JourneyData(), JourneyAuth());
    await tester.pumpAndSettle();
    expect(find.text('What brings you to Flixie?'), findsOneWidget);
    home.dispose();
    final profile =
        await pumpJourney(tester, 'profile', JourneyData(), JourneyAuth());
    await tester.pumpAndSettle();
    expect(find.text('Make yourself at home'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsWidgets);
    profile.dispose();
  });
  testWidgets('episode is fulfilled before setup and keeps the show',
      (tester) async {
    final data = JourneyData();
    final auth = JourneyAuth();
    final router = await pumpJourney(tester, 'episode', data, auth, show: true);
    await tester.pumpAndSettle();
    expect(data.episodes, 1);
    expect(find.text('Episode marked watched'), findsOneWidget);
    expect(find.textContaining('Season 1 · Episode 2: Cat’s in the Bag…'),
        findsOneWidget);
    expect(auth.finishes, 0);
    await tester.tap(find.text('Back to the show'));
    await tester.pumpAndSettle();
    expect(find.text('Destination /shows/1547'), findsOneWidget);
    router.dispose();
  });
  testWidgets(
      'log embeds the existing editor and copy invite belongs to the saved watch',
      (tester) async {
    ApiClient.useClientForTesting(MockClient((request) async => http.Response(
        jsonEncode(request.url.path.endsWith('/share')
            ? {
                'url':
                    'https://www.flixie.co.uk/invite?watch=isolated-watch-token'
              }
            : {'friendships': []}),
        200)));
    final data = JourneyData();
    final auth = JourneyAuth();
    final router = await pumpJourney(tester, 'log', data, auth);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add someone'));
    await tester.tap(find.text('Add someone'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Sam');
    await tester.pump();
    await tester.tap(find.text('Add to my watch'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save watch'));
    await tester.tap(find.text('Save watch'));
    await tester.pumpAndSettle();
    expect(data.logs.single.externalCompanionName, 'Sam');
    expect(data.logs.single.draftId, isNotEmpty);
    expect(find.text('That watch is in the diary'), findsOneWidget);
    expect(find.text('Copy invite'), findsOneWidget);
    expect(auth.finishes, 0);
    await tester.ensureVisible(find.text('Copy invite'));
    await tester.tap(find.text('Copy invite'));
    await tester.pumpAndSettle();
    expect(
        find.text('Invite copied. Nothing sent automatically.'), findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '));
    router.dispose();
  });
  testWidgets(
      'review submits once, then offers a diary entry without reposting the review',
      (tester) async {
    var posts = 0;
    ApiClient.useClientForTesting(MockClient((request) async {
      if (request.url.path.endsWith('/review')) {
        posts++;
        final body = (jsonDecode(request.body) as Map)['review'] as Map;
        return http.Response(
            jsonEncode({...body, 'id': 'review-fixture', 'movieId': 348}), 200);
      }
      return http.Response('{}', 200);
    }));
    final data = JourneyData();
    final auth = JourneyAuth();
    final router = await pumpJourney(tester, 'review', data, auth);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('8'));
    await tester.tap(find.widgetWithText(FlixiePill, '8'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'Still a classic');
    await tester.enterText(fields.last, 'Still an incredible film.');
    await tester.ensureVisible(find.text('Post review'));
    await tester.tap(find.text('Post review'));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(find.text('Your review is posted'), findsOneWidget);
    expect(await const TasteSetupStore().eligible('fixture'), true);
    expect(auth.finishes, 0);
    await tester.tap(find.text('Add date & watched with'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save watch'));
    await tester.tap(find.text('Save watch'));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(data.logs, hasLength(1));
    expect(data.logs.single.rating, 8);
    router.dispose();
  });
  testWidgets('Home logging keeps intent and opens the chosen film editor',
      (tester) async {
    final data = JourneyData();
    final auth = JourneyAuth();
    final router = await pumpJourney(tester, 'home', data, auth);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log something I’ve watched'));
    await tester.pumpAndSettle();
    expect(find.text('What have you watched?'), findsOneWidget);
    await tester.tap(find.byTooltip('Log Interstellar'));
    await tester.pumpAndSettle();
    expect(find.text('Log your watch'), findsOneWidget);
    expect(find.byTooltip('Skip for now'), findsOneWidget);
    expect(find.byTooltip('Close'), findsNothing);
    expect(auth.finishes, 0);
    await tester.tap(find.text('Save watch'));
    await tester.pumpAndSettle();
    expect(data.logs.single.movieId, 157336);
    router.dispose();
  });
  testWidgets('leaving an unfinished rating never implies a save',
      (tester) async {
    final data = JourneyData();
    final auth = JourneyAuth();
    final router = await pumpJourney(tester, 'rate', data, auth);
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsNothing);
    await tester.tap(find.byTooltip('Skip for now'));
    await tester.pumpAndSettle();
    expect(data.ratings, 0);
    expect(auth.finishes, 1);
    router.dispose();
  });

  for (final action in ['rate', 'review', 'log']) {
    for (final size in [
      const Size(320, 568),
      const Size(844, 390),
      const Size(1024, 768)
    ]) {
      testWidgets(
          '$action editor retains title context and controls at $size with larger text',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = 1.8;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final router =
            await pumpJourney(tester, action, JourneyData(), JourneyAuth());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Film'), findsOneWidget);
        if (action == 'rate' || action == 'review') {
          final editor = action == 'rate'
              ? find.text('How was Alien?')
              : find.byKey(const ValueKey('review-notebook'));
          expect(tester.getTopLeft(find.byType(SignupTitleContext)).dx,
              closeTo(tester.getTopLeft(editor).dx, 1),
              reason: 'Poster context aligns with the editor at every width');
        }
        expect(find.byTooltip('Skip for now'), findsOneWidget);
        router.dispose();
      });
    }
  }
}
