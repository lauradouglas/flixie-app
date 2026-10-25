import 'package:flixie_app/features/movies/models/watch_log_details.dart';
import 'package:flixie_app/features/movies/data/movie_watch_plan_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';

void main() {
  testWidgets(
      'recommendation and watch comments are available before opening the optional review',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? comment;
    bool? recommendation;
    WatchLogDetails? details;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RewatchLogSheet(
                onDetailsChanged: (value) => details = value,
                onSubmit: (
                    {required watchedAt,
                    required rating,
                    required recommended,
                    required notes}) async {
                  comment = notes;
                  recommendation = recommended;
                }))));
    expect(find.text('Would you recommend it?'), findsOneWidget);
    expect(find.text('Recommend'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Watch comment (optional)'),
        findsOneWidget);
    expect(
        find.widgetWithText(TextField, 'Your review (optional)'), findsNothing);
    await tester.tap(find.text('Recommend'));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextField, 'Watch comment (optional)'),
        'Cinema night with Sophie');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save watch'));
    await tester.pumpAndSettle();
    expect(comment, 'Cinema night with Sophie');
    expect(recommendation, isTrue);
    expect(details!.reviewBody, isEmpty);
  });

  testWidgets(
      'rating fills gold stars cumulatively and retains the numeric score',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    double? saved;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RewatchLogSheet(
        onSubmit: (
            {required watchedAt,
            required rating,
            required recommended,
            required notes}) async {
      saved = rating;
    }))));
    Finder choice(int n) => find.byWidgetPredicate((widget) =>
        widget is Semantics && widget.properties.label == 'Rate $n out of 10');
    await tester.tap(choice(8));
    await tester.pump();
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(8));
    expect(find.text('9'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('8 / 10'), findsOneWidget);
    await tester.tap(choice(3));
    await tester.pump();
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.text('1'), findsOneWidget);
    await tester.tap(choice(8));
    await tester.pump();
    await tester.tap(find.text('Save watch'));
    await tester.pumpAndSettle();
    expect(saved, 8);
  });

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
        save: ({watchedAtCinema, watchedAt, rating, recommended, notes}) async {
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
    expect(find.text('Write a review next'), findsNothing);
    await tester.tap(
        find.ancestor(of: find.text('8'), matching: find.byType(TextButton)));
    await tester.pump();
    await tester.enterText(
        find.byType(TextField), 'Loved watching this together');
    await tester.ensureVisible(find.text('Save watch'));
    await tester.tap(find.text('Save watch'));
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
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
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
    await tester.tap(find.text('Recommend'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
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

    expect(find.text('Your rating'), findsOneWidget);
    await tester.ensureVisible(find.text('Write a review next'));
    await tester.tap(find.text('Write a review next'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save & write review'));
    await tester.tap(find.text('Save & write review'));
    await tester.pumpAndSettle();

    expect(submitted, isTrue);
    expect(submittedWatchedAt, isNotNull);
    expect(reviewSelected, isTrue);
  });
}
