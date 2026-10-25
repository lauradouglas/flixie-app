import 'package:flixie_app/features/movies/presentation/widgets/show_watch_providers_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_watch_providers_section.dart';

WatchProvider offer(int id, String name, String type, int priority) =>
    WatchProvider(
        id: id,
        providerName: name,
        displayPriority: priority,
        logoPath: '',
        tvShows: true,
        movies: true,
        isVisible: true,
        supportsGb: true,
        supportsUs: true,
        availabilityTypes: {type});

void main() {
  for (final show in [false, true]) {
    testWidgets(
        '${show ? 'show' : 'movie'} invites provider setup only with no saved services',
        (tester) async {
      var opened = 0;
      Widget section(Set<int> ids) => show
          ? ShowWatchProvidersSection(
              providers: const [],
              userProviderIds: ids,
              userProviderMatchKeys: const {},
              region: 'GB',
              loading: false,
              loaded: true,
              failed: false,
              onRetry: () async {},
              onRegionChanged: () async {},
              onAddProviders: () => opened++)
          : MovieWatchProvidersSection(
              providers: const [],
              userProviderIds: ids,
              userProviderMatchKeys: const {},
              region: 'GB',
              onChangeRegion: () async {},
              onAddProviders: () => opened++);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: section({}))));
      await tester.tap(find.text('Add watch providers'));
      expect(opened, 1);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: section({8}))));
      expect(find.text('Add watch providers'), findsNothing);
    });
  }
  testWidgets('saved subscriptions lead streaming; tabs show the right offers',
      (tester) async {
    final providers = [
      offer(1, 'Other stream', 'stream', 1),
      offer(2, 'Saved stream', 'stream', 9),
      offer(3, 'Rental service', 'rent', 1),
      offer(4, 'Purchase service', 'buy', 1)
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MovieWatchProvidersSection(
                providers: providers,
                userProviderIds: const {2},
                userProviderMatchKeys: const {},
                region: 'GB',
                onChangeRegion: () async {}))));
    expect(tester.getTopLeft(find.text('Saved stream')).dy,
        lessThan(tester.getTopLeft(find.text('Other stream')).dy));
    expect(find.text('Your subscription'), findsOneWidget);
    await tester.tap(find.text('Rent'));
    await tester.pump();
    expect(find.text('Rental service'), findsOneWidget);
    expect(find.text('Saved stream'), findsNothing);
    await tester.tap(find.text('Buy'));
    await tester.pump();
    expect(find.text('Purchase service'), findsOneWidget);
  });

  testWidgets(
      'all options opens a scrollable sheet and duplicate IDs appear once',
      (tester) async {
    final providers =
        List.generate(5, (i) => offer(i, 'Stream $i', 'stream', i));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MovieWatchProvidersSection(
                providers: [...providers, providers.first],
                userProviderIds: const {},
                userProviderMatchKeys: const {},
                region: 'GB',
                onChangeRegion: () async {}))));
    expect(find.text('See all 5 stream options'), findsOneWidget);
    await tester.tap(find.text('See all 5 stream options'));
    await tester.pumpAndSettle();
    expect(find.text('Stream options'), findsOneWidget);
    expect(find.text('Stream 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
