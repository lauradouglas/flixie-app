import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_detail_metadata.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_watch_providers_section.dart';

void main() {
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
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: SingleChildScrollView(
                    child: Column(children: [
                  ShowInfoSection(show: show, credits: const []),
                  ShowCastSection(show: show, credits: const [])
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
