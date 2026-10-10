import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/movies/presentation/pages/show_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_episode_card.dart';
import 'package:flixie_app/features/settings/data/episode_spoiler_preference.dart';
import 'show_detail_controller_test.dart' show ShowAuth;
import 'movie_detail_action_flow_test.dart' show ActionAnalytics;

class TvDetailFixture {
  final auth = ShowAuth();
  final watched = <int, bool>{1: false, 2: false, 3: false};
  final writes = <http.Request>[];
  late final http.Client client = MockClient((request) async {
    if (request.method != 'GET') {
      writes.add(request);
      final match =
          RegExp(r'/episodes/(\d+)/progress').firstMatch(request.url.path);
      if (match != null) {
        watched[int.parse(match[1]!)] =
            jsonDecode(request.body)['watched'] as bool;
      }
      return http.Response('{}', 200);
    }
    if (request.url.path == '/shows/id/101') {
      return http.Response(
          jsonEncode({
            'id': 101,
            'name': 'Alien: Earth',
            'overview': 'A familiar world. A new arrival.',
            'numberOfSeasons': 1,
            'numberOfEpisodes': 3,
            'status': 'Returning Series',
            'seasons': [
              {
                'id': 1,
                'seasonNumber': 1,
                'name': 'Season 1',
                'episodeCount': 3,
                'episodes': [
                  for (var i = 1; i <= 3; i++)
                    {
                      'id': i,
                      'seasonNumber': 1,
                      'episodeNumber': i,
                      'name': i == 1 ? 'Pilot reveal' : 'Episode $i reveal',
                      'airDate': i == 3 ? '2100-01-01' : '2026-01-01',
                      'overview': 'Secret story $i',
                      'userState': {'watched': watched[i]}
                    },
                ]
              }
            ],
          }),
          200);
    }
    if (request.url.path.endsWith('/credits')) {
      return http.Response('{"cast":[],"crew":[]}', 200);
    }
    if (request.url.path.contains('rating')) return http.Response('null', 200);
    if (request.url.path.contains('friend')) return http.Response('{}', 200);
    return http.Response('[]', 200);
  });
  void install() {
    SharedPreferences.setMockInitialValues(
        {EpisodeSpoilerPreference.storageKey: true});
    auth.account = auth.account!.copyWith(
        favoriteShows: List.generate(
            10,
            (i) => {
                  'showId': i + 20,
                  'show': {'id': i + 20, 'name': 'Fixture favourite $i'}
                }));
    ApiClient.useClientForTesting(client);
  }

  void dispose() {
    ApiClient.useClientForTesting(null);
    client.close();
    auth.dispose();
  }
}

Widget tvDetailApp(TvDetailFixture fixture, {double scale = 1}) =>
    MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: fixture.auth),
          ChangeNotifierProvider<AnalyticsController>(
              create: (_) => ActionAnalytics())
        ],
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: const ShowDetailScreen(showId: '101')));
Future<void> scrollTvControlIntoView(
    WidgetTester tester, Finder control) async {
  for (var step = 0;
      step < 24 &&
          (control.evaluate().isEmpty ||
              control.hitTestable().evaluate().isEmpty);
      step++) {
    await tester.drag(
        find.byType(CustomScrollView).first, const Offset(0, -140));
    await tester.pumpAndSettle();
  }
  expect(control.hitTestable(), findsWidgets);
}

Future<void> openTvEpisodes(WidgetTester tester) async {
  final tab = find.text('Episodes');
  final tabs = find.descendant(
      of: find.byType(SliverPersistentHeader), matching: find.byType(ListView));
  for (var step = 0;
      step < 30 && tab.hitTestable().evaluate().isEmpty;
      step++) {
    if (tabs.hitTestable().evaluate().isNotEmpty) {
      await tester.drag(tabs, const Offset(-100, 0));
    } else {
      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, -140));
    }
    await tester.pumpAndSettle();
  }
  expect(tab.hitTestable(), findsOneWidget);
  await tester.tap(tab.hitTestable());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'episode spoilers, marking and Undo preserve the actual screen journey',
      (tester) async {
    final fixture = TvDetailFixture()..install();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(tvDetailApp(fixture));
    await tester.pumpAndSettle();
    await openTvEpisodes(tester);
    expect(find.text('Pilot reveal'), findsNothing);
    expect(find.text('Title hidden'), findsNWidgets(3));
    final first = find.byType(ShowEpisodeCard).first;
    await scrollTvControlIntoView(
        tester, find.descendant(of: first, matching: find.byType(Checkbox)));
    await tester
        .tap(find.descendant(of: first, matching: find.byType(Checkbox)));
    await tester.pumpAndSettle();
    expect(fixture.watched[1], true);
    expect(find.text('Pilot reveal'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(fixture.watched[1], false);
    expect(find.text('Pilot reveal'), findsNothing);
    final upcoming = find.byType(ShowEpisodeCard).last;
    await scrollTvControlIntoView(
        tester, find.descendant(of: upcoming, matching: find.byType(Checkbox)));
    expect(
        tester
            .widget<Checkbox>(
                find.descendant(of: upcoming, matching: find.byType(Checkbox)))
            .onChanged,
        isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('an open episode sheet cannot save into a different account',
      (tester) async {
    final fixture = TvDetailFixture()..install();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(tvDetailApp(fixture));
    await tester.pumpAndSettle();
    await openTvEpisodes(tester);
    final card = find.byType(ShowEpisodeCard).first;
    await scrollTvControlIntoView(tester, card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    final save = find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.text('Mark watched'));
    expect(save, findsOneWidget);
    fixture.auth.select('other');
    await tester.pumpAndSettle();
    final writesBeforeTap = fixture.writes.length;
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(fixture.writes.length, writesBeforeTap);
    expect(fixture.watched[1], false);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 800),
    const Size(390, 850),
    const Size(1024, 800),
    const Size(844, 390)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'TV overview and episodes ${size.width}x${size.height} scale $scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = TvDetailFixture()..install();
        addTearDown(fixture.dispose);
        await tester.pumpWidget(tvDetailApp(fixture, scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await openTvEpisodes(tester);
        await scrollTvControlIntoView(tester, find.byType(ShowEpisodeCard));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
