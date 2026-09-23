import 'package:flixie_app/features/movies/data/movie_watch_plan_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';

void main() {
  testWidgets(
      'selecting a watch plan links the rating and changes notes to a plan review',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    MovieWatchPlanChoice? selected;
    double? savedRating;
    String? savedReview;
    final plan = MovieWatchPlanChoice(
        id: 'group:1',
        label: 'With Film Club',
        save: ({watchedAt, rating, recommended, notes}) async {
          savedRating = rating;
          savedReview = notes;
        });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RewatchLogSheet(
      watchPlans: Future.value([plan]),
      showReviewOption: true,
      onPlanSelected: (value) => selected = value,
      onSubmit: (
          {required watchedAt,
          required rating,
          required recommended,
          required notes}) async {
        await selected!.save(
            watchedAt: watchedAt,
            rating: rating,
            recommended: recommended,
            notes: notes);
      },
    ))));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.text('With Film Club'));
    await tester.pump();
    expect(selected, same(plan));
    expect(find.text('Write a review after logging'), findsNothing);
    await tester.tap(
        find.ancestor(of: find.text('8'), matching: find.byType(TextButton)));
    await tester.pump();
    await tester.tap(find.text('Review & date (optional)'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'Loved watching this together');
    await tester.ensureVisible(find.text('Rate & mark watched'));
    await tester.tap(find.text('Rate & mark watched'));
    await tester.pumpAndSettle();
    expect(savedRating, 8);
    expect(savedReview, 'Loved watching this together');
  });

  testWidgets('a rated watch can clear a recommendation to no opinion',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    bool? savedRecommendation = true;
    double? savedRating;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RewatchLogSheet(
      initial: const MovieWatchEntry(
          id: 'watch',
          userId: 'user',
          movieId: 603,
          rating: 5,
          recommended: true,
          removed: false),
      onSubmit: (
          {required watchedAt,
          required rating,
          required recommended,
          required notes}) async {
        savedRecommendation = recommended;
        savedRating = rating;
      },
    ))));
    await tester.ensureVisible(find.text('No opinion'));
    await tester.tap(find.text('No opinion'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(savedRating, 5);
    expect(savedRecommendation, isNull);
  });
  testWidgets('editing an imported undated watch does not default to today',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? submittedDate = 'not-submitted';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RewatchLogSheet(
      initial: const MovieWatchEntry(
          id: 'imported',
          userId: 'user',
          movieId: 603,
          rating: 8,
          removed: false),
      onSubmit: (
          {required watchedAt,
          required rating,
          required recommended,
          required notes}) async {
        submittedDate = watchedAt;
      },
    ))));
    await tester.tap(find.byTooltip('Recommend'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(submittedDate, isNull);
  });
  testWidgets('watch entry can continue into the review journey',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
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

    expect(find.text('Details (optional)'), findsOneWidget);
    expect(find.text('Rating (optional)'), findsOneWidget);
    await tester.ensureVisible(find.text('Write a review after logging'));
    await tester.tap(find.text('Write a review after logging'));
    await tester.ensureVisible(find.text('Mark watched without rating'));
    await tester.tap(find.text('Mark watched without rating'));
    await tester.pumpAndSettle();

    expect(submitted, isTrue);
    expect(submittedWatchedAt, isNotNull);
    expect(reviewSelected, isTrue);
  });
}
