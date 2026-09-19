import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/watchlist/presentation/widgets/watch_request_input.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/watchlist/domain/tonight_filters.dart';
import 'package:flixie_app/features/watchlist/presentation/widgets/tonight_filters_panel.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
  });
  testWidgets('request refinements keep the rest of the viewer’s words',
      (tester) async {
    final controller =
        TextEditingController(text: 'A chick flick, no violence');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: WatchRequestInput(controller: controller))));
    await tester.tap(find.text('Rom-com'));
    await tester.pumpAndSettle();
    expect(controller.text, 'A rom com, no violence');
    expect(find.text('Include possible matches'), findsNothing);
    expect(find.text('Emotional romance'), findsNothing);
  });
  test('time limits exclude unknown and zero durations, and include exact fits',
      () {
    expect(fitsWatchTime(null, 90), false);
    expect(fitsWatchTime(0, 90), false);
    expect(fitsWatchTime(91, 90), false);
    expect(fitsWatchTime(90, 90), true);
    expect(fitsWatchTime(null, null), true);
  });
  test('experience goals keep genres separate and evidence ranking explicit',
      () {
    expect(WatchlistMood.values.map((m) => m.id),
        containsAll(['switch_off', 'feel_good', 'feel_something']));
    expect(WatchlistMood.values.map((m) => m.id), isNot(contains('romcom')));
    final possible = ExperienceFit.fromJson({
      'tier': 'possible',
      'score': 1,
      'personalScore': 100,
      'eligible': true
    });
    final reviewed = ExperienceFit.fromJson({
      'tier': 'match',
      'source': 'reviewed',
      'score': 2,
      'personalScore': 0,
      'eligible': true
    });
    expect(possible.label, 'Possible match');
    expect(reviewed.compareTo(possible), lessThan(0));
  });
  test('selected subscriptions never imply rental or purchase access', () {
    WatchProvider offer(String type, [int id = 1]) => WatchProvider(
        id: id,
        providerName: 'Service',
        displayPriority: 0,
        logoPath: '',
        tvShows: true,
        movies: true,
        isVisible: true,
        supportsGb: true,
        supportsUs: true,
        availabilityTypes: {type});
    bool matches(List<WatchProvider> offers, {bool rent = false}) =>
        matchesWatchServices(offers, selectedIds: {1}, includeRentals: rent);
    expect(matches([offer('flatrate')]), true);
    expect(matches([offer('flatrate', 2)]), false);
    expect(matches([offer('rent')]), false);
    expect(matches([offer('rent', 2)], rent: true), true);
    expect(matches([offer('buy')], rent: true), false);
    expect(matches([offer('')]), false);
    expect(matches([]), false);
  });
  test('episode duration survives roundtrip and uses longest known duration',
      () {
    final show = TvShow.fromJson({
      'id': 1,
      'name': 'Show',
      'episode_run_time': [24, 30]
    });
    expect(show.episodeRuntime, 30);
    expect(TvShow.fromJson(show.toJson()).episodeRuntime, 30);
    expect(
        TvShow.fromJson({'id': 2, 'name': 'Unknown'}).episodeRuntime, isNull);
  });
  testWidgets(
      'guest services apply only to this search and never write profile preferences',
      (tester) async {
    Set<int>? applied;
    final saved = <int>{1};
    final providers = [
      WatchProvider.fromJson(
          {'id': 1, 'providerName': 'My Stream', 'supportsGb': true})
    ];
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
              body: TonightFiltersPanel(
            minutes: null,
            mood: WatchlistMood.any,
            providers: providers,
            selectedProviders: saved,
            savedProviderIds: saved,
            servicesOnly: false,
            rentals: false,
            count: 2,
            loading: false,
            region: 'GB',
            onTime: (_) {},
            onMood: (_) {},
            onServices: (catalog, ids, enabled, rental) {
              applied = ids;
              expect(enabled, true);
            },
            onClear: () {},
            onPick: () {},
            onMore: () {},
            onSort: () {},
            sortLabel: 'Date added',
          ))));
      await tester.tap(find.ancestor(
          of: find.text('Services'), matching: find.byType(FlixiePill)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add another service'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guest Stream'));
      await tester.tap(find.text('Guest Stream'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use for this search'));
      await tester.pumpAndSettle();
      expect(applied, {1, 2});
      expect(saved, {1});
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              expect(request.method, 'GET');
              expect(request.url.path, endsWith('/utils/watch-providers'));
              return http.Response(
                  jsonEncode({
                    'watchProviders': [
                      {
                        'id': 1,
                        'providerName': 'My Stream',
                        'supportsGb': true
                      },
                      {
                        'id': 2,
                        'providerName': 'Guest Stream',
                        'supportsGb': true
                      },
                    ]
                  }),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
  });
  for (final size in [
    const Size(320, 640),
    const Size(393, 852),
    const Size(844, 390),
    const Size(1024, 1366)
  ]) {
    testWidgets('compact filters and scrollable sheets fit large text at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      int? time;
      String? appliedGenre;
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: TonightFiltersPanel(
            minutes: null,
            mood: WatchlistMood.gripping,
            providers: const [],
            selectedProviders: const {},
            savedProviderIds: const {},
            servicesOnly: false,
            rentals: false,
            count: 3,
            loading: false,
            region: 'GB',
            onTime: (v) => time = v,
            onMood: (_) {},
            onGenre: (genre) => appliedGenre = genre,
            onServices: (_, __, ___, ____) {},
            onClear: () {},
            onPick: () {},
            onMore: () {},
            onSort: () {},
            sortLabel: 'Date added',
          )))));
      expect(find.text('What fits tonight?'), findsNothing);
      await tester.tap(find.ancestor(
          of: find.text('Time'), matching: find.byType(FlixiePill)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('30 min'));
      await tester.tap(find.text('30 min'));
      await tester.pumpAndSettle();
      expect(time, 30);
      await tester.tap(find.ancestor(
          of: find.text('Genre'), matching: find.byType(FlixiePill)));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.ensureVisible(find.text('Rom com'));
      await tester.tap(find.text('Rom com'));
      await tester.pumpAndSettle();
      expect(appliedGenre, 'Rom com');
      expect(find.text('Pick one'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
