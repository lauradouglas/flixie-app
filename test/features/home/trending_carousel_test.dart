import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/widgets/trending_carousel.dart';
import 'package:flixie_app/models/movie_short.dart';

void main() {
  testWidgets(
      'signed-in bookmark shows saved state and blocks repeated pending writes',
      (tester) async {
    var saves = 0;
    Widget build(Set<int> pending) => MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: TrendingCarousel(
                    movies: const [MovieShort(id: 348, name: 'Alien')],
                    savedIds: const {348},
                    pendingIds: pending,
                    onSave: (_) => saves++,
                    onDetails: (_) {},
                    onTrailer: (_) {}))));
    await tester.pumpWidget(build({}));
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Remove from watchlist'));
    expect(saves, 1);
    await tester.pumpWidget(build({348}));
    final button = tester.widget<IconButton>(find.descendant(
        of: find.byTooltip('Remove from watchlist'),
        matching: find.byType(IconButton)));
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
