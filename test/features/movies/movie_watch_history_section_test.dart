import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_watch_history_section.dart';

void main() {
  testWidgets('history edit and delete target the selected watch entry',
      (tester) async {
    const entry = MovieWatchEntry(
        id: 'watch-2',
        userId: 'fixture',
        movieId: 1,
        removed: false,
        watchedAt: '2026-10-06',
        rating: 8,
        notes: 'Second watch');
    MovieWatchEntry? edited;
    MovieWatchEntry? deleted;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MovieWatchHistorySection(
                entries: const [entry],
                loading: false,
                formatDate: (date) => date ?? 'Unknown',
                onAdd: () {},
                onEdit: (watch) => edited = watch,
                onDelete: (watch) => deleted = watch))));
    expect(find.text('Rating: 8/10 • Second watch'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(edited, same(entry));
    expect(deleted, isNull);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, same(entry));
  });

  testWidgets('empty history lets the viewer log their first watch',
      (tester) async {
    var added = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MovieWatchHistorySection(
                entries: const [],
                loading: false,
                formatDate: (_) => '',
                onAdd: () => added = true,
                onEdit: (_) {},
                onDelete: (_) {}))));
    await tester.tap(find.text('Log watch'));
    expect(added, true);
  });
}
