import 'package:flixie_app/screens/stats/genre_bar.dart';
import 'package:flixie_app/screens/stats/monthly_bar_chart.dart';
import 'package:flixie_app/screens/stats/section_header.dart';
import 'package:flixie_app/screens/stats/stat_card.dart';
import 'package:flixie_app/screens/stats/stats_entry.dart';
import 'package:flixie_app/screens/stats/year_breakdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget _wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('stats reusable widgets', () {
    testWidgets('SectionHeader renders uppercase title', (tester) async {
      await tester.pumpWidget(_wrap(const SectionHeader(title: 'Top Genres')));

      expect(find.text('TOP GENRES'), findsOneWidget);
    });

    testWidgets('StatsCard renders label, value, and subtitle', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Row(
            children: [
              StatsCard(
                label: 'Movies Watched',
                value: '12',
                subtitle: 'this year',
                icon: Icons.movie_outlined,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Movies Watched'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('this year'), findsOneWidget);
    });

    testWidgets('MonthlyBarChart shows counts and month labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MonthlyBarChart(
            buckets: [0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            maxValue: 3,
            mostActiveIndex: 1,
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
      expect(find.text('Feb'), findsOneWidget);
    });

    testWidgets('GenreBar renders rank, genre name and count', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GenreBar(rank: 1, name: 'Drama', count: 7, maxCount: 10),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Drama'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('YearBreakdown aggregates yearly counts', (tester) async {
      await tester.pumpWidget(
        _wrap(
          YearBreakdown(
            years: const [2025, 2024],
            entries: [
              StatsEntry(watchedAt: DateTime(2025, 1, 1)),
              StatsEntry(watchedAt: DateTime(2025, 2, 1)),
              StatsEntry(watchedAt: DateTime(2024, 3, 1)),
            ],
          ),
        ),
      );

      expect(find.text('2025'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
    });
  });
}
