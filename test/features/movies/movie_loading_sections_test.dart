import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_detail_loading_sections.dart';

void main() {
  for (final (width, scale, expectedHeight) in [
    (390.0, 1.0, 60.0),
    (320.0, 1.0, 114.0),
    (390.0, 2.0, 114.0)
  ]) {
    testWidgets('watch-entry skeleton matches row reflow $width $scale',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: SizedBox(width: width, child: const MovieWatchEntrySkeleton()),
      ))));
      expect(tester.getSize(find.byType(MovieWatchEntrySkeleton)).height,
          expectedHeight);
      expect(tester.takeException(), isNull);
      expect(find.byType(FilledButton), findsNothing);
    });
  }
}
