import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_viewing_timeline.dart';

void main() {
  for (final undated in [false, true]) {
    testWidgets(
        'completed show displays final watched episode with bulk or missing dates $undated',
        (tester) async {
      final date = DateTime(2026, 10, 1);
      final episodes = List.generate(
          23,
          (i) => TvEpisode(
              id: i + 1,
              name: 'Episode ${i + 1}',
              seasonNumber: i < 12 ? 1 : 2,
              episodeNumber: i < 12 ? i + 1 : i - 11,
              watched: true,
              watchedAt: undated && i > 0 ? null : date));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: ShowViewingTimeline(
                      show: TvShow(id: 1, name: 'Fixture', episodes: episodes),
                      now: DateTime(2026, 10, 10),
                      hideSpoilers: false,
                      busy: false,
                      onMarkWatched: null,
                      onOpenEpisode: (_) {},
                      onViewEpisodes: () {})))));
      expect(find.text('Last watched · Season 2 · Episode 11'), findsOneWidget);
      expect(find.text('Last watched · Season 1 · Episode 1'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'timeline distinguishes start, continue and old dated progress without spoilers',
      (tester) async {
    final now = DateTime(2026, 10, 10);
    var marks = 0, views = 0;
    Future<void> render({bool watched = false, DateTime? date}) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: ShowViewingTimeline(
        show: TvShow(id: 101, name: 'Alien: Earth', episodes: [
          TvEpisode(
              id: 1,
              name: 'Pilot',
              seasonNumber: 1,
              episodeNumber: 1,
              airDate: '2026-01-01',
              watched: watched,
              watchedAt: date),
          const TvEpisode(
              id: 2,
              name: 'Secret reveal',
              seasonNumber: 1,
              episodeNumber: 2,
              airDate: '2026-01-02'),
        ]),
        now: now,
        hideSpoilers: true,
        busy: false,
        onMarkWatched: () => marks++,
        onOpenEpisode: (_) {},
        onViewEpisodes: () => views++,
      )))));
    }

    await render();
    expect(find.text('Start watching'), findsOneWidget);
    await tester.tap(find.text('Mark watched'));
    expect(marks, 1);
    await render(watched: true, date: now.subtract(const Duration(days: 2)));
    expect(find.text('Continue watching'), findsOneWidget);
    expect(find.text('Secret reveal'), findsNothing);
    await render(watched: true, date: now.subtract(const Duration(days: 120)));
    expect(find.text('Your place, saved'), findsOneWidget);
    await tester.tap(find.text('Check my place'));
    expect(views, 1);
    await render(watched: true);
    expect(find.text('Continue watching'), findsOneWidget);
    expect(find.text('Check my place'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
