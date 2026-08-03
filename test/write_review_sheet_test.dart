import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';

void main() {
  testWidgets('uses the rating and recommendation from the watch entry',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WriteReviewSheet(
            movieId: 1,
            userId: 'user-1',
            initialRating: 9,
            initialRecommended: false,
            onSubmitted: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('9 / 10'), findsOneWidget);
    final selectedRatings = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .where((chip) => chip.selected)
        .toList();
    expect(selectedRatings, hasLength(1));
    expect((selectedRatings.single.label as Text).data, '9');
    expect(tester.widgetList<Switch>(find.byType(Switch)).first.value, isFalse);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });
}
