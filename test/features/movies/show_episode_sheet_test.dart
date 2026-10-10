import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_episode_sheet.dart';

void main() {
  testWidgets(
      'selecting episode offers earlier-only and optional selected catch-up',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? included;
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Builder(builder: (context) {
      return TextButton(
          onPressed: () => showShowEpisodeSheet(
              context,
              const TvEpisode(
                  id: 5,
                  seasonNumber: 1,
                  episodeNumber: 5,
                  name: 'Paradise',
                  airDate: '2020-01-01'),
              earlierUnwatched: 4,
              hideSpoilers: true,
              onCatchUp: (value) => included = value,
              onToggleWatched: () {}),
          child: const Text('Episode 5'));
    }))));
    await tester.tap(find.text('Episode 5'));
    await tester.pumpAndSettle();
    expect(included, isNull);
    expect(find.text('Paradise'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Include episode 5 too'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark 5 episodes watched'));
    await tester.pumpAndSettle();
    expect(included, true);
  });
}
