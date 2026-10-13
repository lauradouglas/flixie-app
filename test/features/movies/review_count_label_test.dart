import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/widgets/review_count_label.dart';

void main() {
  for (final entry in [(0, '0'), (3, '3'), (999, '999'), (1000, '1k+'), (12345, '1k+')]) {
    testWidgets('review count ${entry.$1} displays ${entry.$2}', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
        child: SizedBox(width: 80, child: ReviewCountLabel(count: entry.$1))))));
      expect(find.text(entry.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('unknown count has no misleading zero pill', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReviewCountLabel(count: null)));
    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}
