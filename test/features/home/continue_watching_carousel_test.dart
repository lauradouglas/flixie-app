import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/features/home/presentation/widgets/continue_watching_carousel.dart';
import 'package:flixie_app/models/continue_watching_show.dart';

void main() {
  testWidgets('confirms before removing a show without deleting progress',
      (tester) async {
    const show = ContinueWatchingShow(
      showId: 10,
      name: 'A Great Show',
      watchedEpisodes: 3,
      totalEpisodes: 10,
      completionPercent: 30,
    );
    ContinueWatchingShow? removed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContinueWatchingCarousel(
            shows: const [show],
            onTap: (_) {},
            onRemove: (value) => removed = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Remove from Continue Watching'));
    await tester.pumpAndSettle();

    expect(find.text('Remove from Continue Watching?'), findsOneWidget);
    expect(find.textContaining('progress will stay saved'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(removed?.showId, 10);
  });
}
