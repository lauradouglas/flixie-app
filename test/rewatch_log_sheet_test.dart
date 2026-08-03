import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';

void main() {
  testWidgets('watch entry can continue into the review journey',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var submitted = false;
    var reviewSelected = false;
    String? submittedWatchedAt = 'not-submitted';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RewatchLogSheet(
            showReviewOption: true,
            onReviewSelected: (value) => reviewSelected = value,
            onSubmit: ({
              required watchedAt,
              required rating,
              required recommended,
              required notes,
            }) async {
              submitted = true;
              submittedWatchedAt = watchedAt;
            },
          ),
        ),
      ),
    );

    expect(find.text('Write a review after saving'), findsOneWidget);
    expect(find.text('Add a specific watch date'), findsOneWidget);
    expect(find.text('Rating (optional)'), findsOneWidget);
    await tester.tap(find.text('Write a review after saving'));
    await tester.ensureVisible(find.text('Mark watched without rating'));
    await tester.tap(find.text('Mark watched without rating'));
    await tester.pumpAndSettle();

    expect(submitted, isTrue);
    expect(submittedWatchedAt, isNotNull);
    expect(reviewSelected, isTrue);
  });
}
