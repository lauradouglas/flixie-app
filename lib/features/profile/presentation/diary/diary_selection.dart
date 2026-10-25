import 'package:flixie_app/models/movie_watch_entry.dart';

DateTime diaryDay(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime diaryMonday(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);
DateTime? diaryWatchDay(MovieWatchEntry entry) {
  final parsed = DateTime.tryParse(entry.watchedAt ?? '');
  return parsed == null ? null : diaryDay(parsed.toLocal());
}

int diaryDaysBetween(DateTime a, DateTime b) =>
    DateTime.utc(a.year, a.month, a.day)
        .difference(DateTime.utc(b.year, b.month, b.day))
        .inDays;

/// Index actual viewings, preserving rewatches and keeping unknown dates separate.
class DiarySelection {
  DiarySelection(Iterable<MovieWatchEntry> entries) {
    final seen = <String>{};

    for (final entry in entries) {
      if (entry.removed || !seen.add(entry.id)) continue;
      final day = diaryWatchDay(entry);
      if (day == null) {
        undated.add(entry);
        continue;
      }
      days.putIfAbsent(day, () => []).add(entry);
    }
    for (final items in days.values) {
      items.sort((a, b) => (a.watchedAt ?? '').compareTo(b.watchedAt ?? ''));
    }
    final dated = days.values.expand((items) => items).toList()
      ..sort((a, b) {
        final comparison = DateTime.parse(a.watchedAt!)
            .compareTo(DateTime.parse(b.watchedAt!));
        return comparison == 0 ? a.id.compareTo(b.id) : comparison;
      });
    final movies = <int>{};
    for (final entry in dated) {
      if (!movies.add(entry.movieId)) rewatches.add(entry.id);
    }
  }
  final days = <DateTime, List<MovieWatchEntry>>{};
  final undated = <MovieWatchEntry>[];
  final rewatches = <String>{};
  List<MovieWatchEntry> week(DateTime date) => [
        for (int i = 0; i < 7; i++)
          ...?days[DateTime(date.year, date.month, date.day + i)]
      ];
}
