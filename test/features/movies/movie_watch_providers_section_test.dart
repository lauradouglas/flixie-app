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
