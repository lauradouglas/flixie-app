import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import 'package:flixie_app/features/authentication/presentation/pages/onboarding_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/setup_profile_favourites.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/social/data/genre_community_service.dart';
import 'setup_flow_test.dart' show SetupFixture;
import 'support/watchlist_auth.dart';

class ActivationAuth extends TestAuth {
  @override
  Future<void> refreshDbUser() async {}
  @override
  Future<bool> completeOnboarding() async => false;
}

class ActivationFixture extends SetupFixture {
  final favourites = <String>[];
  final joins = <int>[];
  @override
  Future<Map<String, dynamic>?> conversation(int id) async => {
        'id': 'local-thread',
        'title': 'Which Alien would you watch again?',
        'spoiler': 'none'
      };
  @override
  Future<List<GenreCommunity>> communities() async =>
      [const GenreCommunity(id: 27, name: 'Horror', joined: false)];
  @override
  Future<Set<int>> titleCommunityGenres(
          SetupTitle title, List<GenreCommunity> available) async =>
      {27};
  @override
  Future<void> addProfileFavourite(String id, SetupTitle title) async {
    favourites.add(title.key);
  }

  @override
  Future<void> joinCommunity(int id) async {
    joins.add(id);
  }
}

Future<void> captureActivation(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('ACTIVATION_CAPTURE')) return;
  final boundary =
      t.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  await t.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('/tmp/flixie-activation-$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> tap(WidgetTester t, String label) async {
    final f = find.text(label).last;
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> mount(WidgetTester t, ActivationFixture service,
      {double scale = 1}) async {
    final router = GoRouter(initialLocation: '/onboarding', routes: [
      GoRoute(
          path: '/onboarding',
          builder: (_, __) => OnboardingScreen(service: service)),
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Home destination'))),
      GoRoute(
          path: '/social',
          builder: (_, __) => const Scaffold(body: Text('Social destination'))),
      GoRoute(
          path: '/genre-communities/:genre/discussions/:thread',
          builder: (_, __) =>
              const Scaffold(body: Text('Real thread destination'))),
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => ActivationAuth()),
          ChangeNotifierProvider<MovieRatingPrivacy>(
              create: (_) => MovieRatingPrivacy(loadRatings: (_) async => {})
                ..syncUser('viewer')),
        ],
        child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!))));
    await t.pumpAndSettle();
  }

  Future<void> picks(WidgetTester t) async {
    final tile = find.byKey(const ValueKey('taste-movie:1'));
    await t.ensureVisible(tile);
    await t.tap(tile);
    await t.pumpAndSettle();
    await tap(t, 'Continue');
    await tap(t, 'Skip services for now');
  }

  testWidgets(
      'taste then picks then optional community, with no automatic favourites or joins',
      (t) async {
    t.view.physicalSize = const Size(430, 932);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final service = ActivationFixture();
    await mount(t, service);
    await picks(t);
    await captureActivation(t, '430-picks');
    expect(find.text('Your picks.'), findsOneWidget);
    expect(service.favourites, isEmpty);
    expect(service.joins, isEmpty);
    await tap(t, 'Add to watchlist');
    expect(service.added.single.id, 2);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('1 saved for later').hitTestable(), findsOneWidget);
    expect(find.text('Waiting for you in Watchlist.'), findsOneWidget);
    await tap(t, 'Find my kind of people');
    expect(find.text('Which Alien would you watch again?'), findsOneWidget);
    await tap(t, 'Read the conversation');
    expect(find.text('Real thread destination'), findsOneWidget);
    expect(service.joins, isEmpty);
  });
  testWidgets(
      'profile strengthening is explicit and does not happen when expanded',
      (t) async {
    final service = ActivationFixture();
    await mount(t, service);
    await picks(t);
    await tap(t, 'Make your profile more you');
    expect(service.favourites, isEmpty);
    final choice = find.widgetWithText(CheckboxListTile, 'Fixture movie');
    expect(t.widget<CheckboxListTile>(choice).value, false);
    await t.ensureVisible(choice);
    await t.tap(choice);
    await t.pumpAndSettle();
    expect(service.favourites, isEmpty);
    await tap(t, 'Add selected to my profile');
    expect(service.favourites, ['movie:1']);
    expect(find.text('Added to your profile'), findsOneWidget);
  });
  testWidgets('joining is explicit; skipping setup can reach Home', (t) async {
    final service = ActivationFixture();
    await mount(t, service);
    await picks(t);
    await tap(t, 'Find my kind of people');
    await tap(t, 'Horror');
    expect(service.joins, isEmpty);
    await tap(t, 'Join 1 & explore');
    expect(service.joins, [27]);
    expect(find.text('Social destination'), findsOneWidget);
  });
  testWidgets('skip does not publish selected taste', (t) async {
    final service = ActivationFixture();
    await mount(t, service);
    await tap(t, 'Skip taste picks');
    await tap(t, 'Skip services for now');
    await tap(t, 'I’ll explore on my own');
    expect(find.text('Home destination'), findsOneWidget);
    expect(service.taste, isEmpty);
    expect(service.favourites, isEmpty);
    expect(service.joins, isEmpty);
  });
  testWidgets('partial favourite failure retries only remaining selection',
      (t) async {
    final attempts = <int>[];
    var fail = true;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: SetupProfileFavourites(
      titles: const [
        SetupTitle(348, 'Alien', null),
        SetupTitle(2, 'Obsession', null)
      ],
      save: (title) async {
        attempts.add(title.id);
        if (title.id == 2 && fail) throw StateError('offline');
      },
    )))));
    await tap(t, 'Make your profile more you');
    await tap(t, 'Alien');
    await tap(t, 'Obsession');
    await tap(t, 'Add selected to my profile');
    expect(attempts, [348, 2]);
    expect(find.textContaining('Your successful choices are saved'),
        findsOneWidget);
    fail = false;
    await tap(t, 'Add selected to my profile');
    expect(attempts, [348, 2, 2]);
  });
  for (final size in [
    const Size(320, 640),
    const Size(430, 932),
    const Size(844, 390),
    const Size(1024, 768)
  ]) {
    testWidgets('activation fits $size with double text', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await mount(t, ActivationFixture(), scale: 2);
      await picks(t);
      expect(t.takeException(), isNull);
      await captureActivation(t, '${size.width.toInt()}-picks-large');
      await tap(t, 'Make your profile more you');
      expect(t.takeException(), isNull);
      await tap(t, 'Find my kind of people');
      expect(t.takeException(), isNull);
    });
  }
}
