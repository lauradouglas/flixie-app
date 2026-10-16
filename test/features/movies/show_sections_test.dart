import 'package:flutter/material.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_episodes_section.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_detail_metadata.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_watch_providers_section.dart';

void main() {
  testWidgets('selecting a season shows its premiere date or an unknown date',
      (tester) async {
    const seasons = [
      TvSeason(id: 1, seasonNumber: 1, name: 'Season 1', airDate: '2025-08-12'),
      TvSeason(id: 2, seasonNumber: 2, name: 'Season 2'),
    ];
    var selected = 1;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (context, setState) => SingleChildScrollView(
          child: ShowEpisodesSection(
        show: const TvShow(id: 101, name: 'Alien: Earth', seasons: seasons),
        selectedSeason: selected,
        updatingSeasons: const {},
        updatingEpisodes: const {},
        hideSpoilers: true,
        savingSpoilers: false,
        loading: false,
        loaded: true,
        failed: false,
        onRetry: () {},
        onSeasonSelected: (value) => setState(() => selected = value),
        onSpoilersChanged: (_) {},
        onSeasonWatched: (_, __) {},
        onEpisodeWatched: (_, __) {},
        onOpenEpisode: (_) {},
      )),
    ))));
    expect(find.text('Premiere · Tuesday, August 12, 2025'), findsOneWidget);
    await tester.tap(find.text('Season 2'));
    await tester.pump();
    expect(find.text('Release date to be announced'), findsOneWidget);
    expect(find.text('Premiere · Tuesday, August 12, 2025'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'detail rows omit missing metadata and cast preserves full names at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const show =
        TvShow(id: 101, name: 'The Newsroom', status: 'Ended', createdBy: [
      'Aaron Sorkin'
    ], cast: [
      TvShowCredit(
          id: 0, name: 'John Gallagher Jr.', character: 'James Harper'),
      TvShowCredit(
          id: 0, name: 'Emily Mortimer', character: 'MacKenzie McHale'),
    ]);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(2)),
                child: SingleChildScrollView(
                    child: Column(children: [
                  ShowInfoSection(show: show, credits: []),
                  ShowCastSection(show: show, credits: [])
                ]))))));
    expect(find.text('Created by'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    expect(find.text('-'), findsNothing);
    for (final name in ['John Gallagher Jr.', 'MacKenzie McHale']) {
      final text = tester.widget<Text>(find.text(name));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'single provider category uses compact row without redundant tabs',
      (tester) async {
    final provider = WatchProvider.fromJson({
      'id': 1,
      'providerName': 'HBO Max',
      'availabilityTypes': ['rent']
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ShowWatchProvidersSection(
                providers: [provider],
                userProviderIds: const {},
                userProviderMatchKeys: const {},
                region: 'GB',
                loading: false,
                loaded: true,
                failed: false,
                onRetry: () async {},
                onRegionChanged: () async {}))));
    expect(find.text('HBO Max'), findsOneWidget);
    expect(find.text('Available to rent'), findsOneWidget);
    expect(find.text('Stream'), findsNothing);
    expect(find.text('Buy'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
