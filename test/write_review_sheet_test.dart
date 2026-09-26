import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
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
        .widgetList<FlixiePill>(find.byType(FlixiePill))
        .where((chip) => chip.selected)
        .toList();
    expect(selectedRatings, hasLength(1));
    expect((selectedRatings.single.label as Text).data, '9');
    expect(tester.widgetList<Switch>(find.byType(Switch)).first.value, isFalse);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('supports the same review flow for a TV show', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WriteReviewSheet(
            showId: 42,
            userId: 'user-1',
            initialRating: 8,
            initialRecommended: true,
            onSubmitted: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Write a Review'), findsOneWidget);
    expect(find.text('8 / 10'), findsOneWidget);
    expect(find.text('I recommend this show'), findsOneWidget);
    expect(find.text('Share your thoughts about the show...'), findsOneWidget);
    expect(find.text('Contains spoilers'), findsOneWidget);
    expect(find.text('Submit Review'), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(800, 1000)]) {
    testWidgets('review links to the chosen viewing at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
        data: MediaQueryData(
            size: size, textScaler: const TextScaler.linear(1.4)),
        child: WriteReviewSheet(
            movieId: 1,
            userId: 'user',
            watchEntryId: 'recent',
            onSubmitted: (_) {},
            watchEntries: const [
              MovieWatchEntry(
                  id: 'recent',
                  userId: 'user',
                  movieId: 1,
                  removed: false,
                  watchedAt: '2026-09-23'),
              MovieWatchEntry(
                  id: 'older',
                  userId: 'user',
                  movieId: 1,
                  removed: false,
                  watchedAt: '2026-08-01'),
            ]),
      ))));
      final field = find.byType(DropdownButtonFormField<String>);
      expect(tester.state<FormFieldState<String>>(field).value, 'recent');
      // The preselected watch date is visible before opening or changing it.
      final selectedDate = find.text('Watch 2 · Wed, Sep 23').hitTestable();
      expect(selectedDate, findsOneWidget);
      final fieldBounds = tester.getRect(field);
      final dateBounds = tester.getRect(selectedDate);
      expect(fieldBounds.contains(dateBounds.center), isTrue);
      expect(dateBounds.top, greaterThanOrEqualTo(fieldBounds.top));
      expect(dateBounds.bottom, lessThanOrEqualTo(fieldBounds.bottom));
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Watch 1 · Sat, Aug 1').last);
      await tester.pumpAndSettle();
      expect(tester.state<FormFieldState<String>>(field).value, 'older');
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Standalone review').last);
      await tester.pumpAndSettle();
      expect(tester.state<FormFieldState<String>>(field).value, '');
      expect(tester.takeException(), isNull);
    });
  }
}
