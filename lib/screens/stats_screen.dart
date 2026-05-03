import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/watchlist_movie.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'stats/genre_bar.dart';
import 'stats/monthly_bar_chart.dart';
import 'stats/section_header.dart';
import 'stats/stat_card.dart';
import 'stats/stats_entry.dart';
import 'stats/year_breakdown.dart';

const List<String> _kMonthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  // null = all time
  int? _selectedYear;

  // Parsed entries from user.watchedMovies
  late final List<StatsEntry> _allEntries;

  @override
  void initState() {
    super.initState();
    final raw = context.read<AuthProvider>().dbUser?.watchedMovies ?? [];
    _allEntries = raw
        .whereType<Map<String, dynamic>>()
        .where((m) => m['removed'] != true)
        .map((m) {
      WatchlistMovieDetails? movie;
      if (m['movie'] != null) {
        try {
          movie = WatchlistMovieDetails.fromJson(
              m['movie'] as Map<String, dynamic>);
        } catch (_) {}
      }
      final dateStr = m['watchedAt'] as String? ?? m['createdAt'] as String?;
      return StatsEntry(
        movie: movie,
        watchedAt: dateStr != null ? DateTime.tryParse(dateStr) : null,
      );
    }).toList();
  }

  List<int> get _availableYears {
    final years = <int>{};
    for (final e in _allEntries) {
      if (e.watchedAt != null) years.add(e.watchedAt!.year);
    }
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  List<StatsEntry> get _entries {
    if (_selectedYear == null) return _allEntries;
    return _allEntries
        .where((e) => e.watchedAt?.year == _selectedYear)
        .toList();
  }

  // ── derived stats ──────────────────────────────────────────────────────────

  int get _totalMovies => _entries.length;

  int get _totalMinutes =>
      _entries.fold(0, (sum, e) => sum + (e.movie?.runtime ?? 0));

  String get _runtimeLabel {
    final mins = _totalMinutes;
    if (mins == 0) return '—';
    final d = mins ~/ (60 * 24);
    final h = (mins % (60 * 24)) ~/ 60;
    final m = mins % 60;
    if (d > 0) return '${d}d ${h}h ${m}m';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  /// Top genres sorted by count, max 5
  List<MapEntry<String, int>> get _topGenres {
    final counts = <String, int>{};
    for (final e in _entries) {
      for (final g in e.movie?.genres ?? <String>[]) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  /// Movies watched per month [Jan..Dec] for selected year (or current year for all-time)
  List<int> get _monthlyBuckets {
    final buckets = List.filled(12, 0);
    final relevant = _selectedYear != null
        ? _entries
        : _allEntries.where((e) => e.watchedAt?.year == DateTime.now().year);
    for (final e in relevant) {
      if (e.watchedAt != null) {
        buckets[e.watchedAt!.month - 1]++;
      }
    }
    return buckets;
  }

  int get _mostActiveMonthIndex {
    final b = _monthlyBuckets;
    int maxIdx = 0;
    for (int i = 1; i < b.length; i++) {
      if (b[i] > b[maxIdx]) maxIdx = i;
    }
    return b[maxIdx] > 0 ? maxIdx : -1;
  }

  double get _avgRating {
    final ratings = context.read<AuthProvider>().cachedRatings ?? [];
    if (_selectedYear == null) {
      if (ratings.isEmpty) return 0;
      return ratings.fold(0.0, (s, r) => s + r.rating) / ratings.length;
    }
    // Filter by watched year: match rated movie ids against entries in selected year
    final yearMovieIds =
        _entries.map((e) => e.movie?.id).whereType<int>().toSet();
    final filtered =
        ratings.where((r) => yearMovieIds.contains(r.movieId)).toList();
    if (filtered.isEmpty) return 0;
    return filtered.fold(0.0, (s, r) => s + r.rating) / filtered.length;
  }

  @override
  Widget build(BuildContext context) {
    final years = _availableYears;
    final buckets = _monthlyBuckets;
    final maxBucket = buckets.reduce((a, b) => a > b ? a : b);
    final topGenres = _topGenres;
    final mostActive = _mostActiveMonthIndex;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        elevation: 0,
        title: const Text(
          'My Stats',
          style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (years.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: DropdownButton<int?>(
                value: _selectedYear,
                underline: const SizedBox(),
                dropdownColor: FlixieColors.tabBarBackgroundFocused,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Time')),
                  ...years.map(
                      (y) => DropdownMenuItem(value: y, child: Text('$y'))),
                ],
                onChanged: (v) => setState(() => _selectedYear = v),
              ),
            ),
        ],
      ),
      body: _allEntries.isEmpty
          ? const Center(
              child: Text('No watch history yet.',
                  style: TextStyle(color: FlixieColors.medium)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ── Headline cards ──────────────────────────────────────
                Row(
                  children: [
                    StatsCard(
                      label: 'Movies Watched',
                      value: _totalMovies > 0 ? '$_totalMovies' : '—',
                      icon: Icons.movie_outlined,
                    ),
                    const SizedBox(width: 12),
                    StatsCard(
                      label: 'Total Runtime',
                      value: _totalMovies > 0 ? _runtimeLabel : '—',
                      icon: Icons.schedule_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    StatsCard(
                      label: 'Avg Rating',
                      value:
                          _avgRating > 0 ? _avgRating.toStringAsFixed(1) : '—',
                      icon: Icons.star_outline,
                    ),
                    const SizedBox(width: 12),
                    StatsCard(
                      label: 'Most Active',
                      value: mostActive >= 0 ? _kMonthNames[mostActive] : '—',
                      subtitle: mostActive >= 0
                          ? '${buckets[mostActive]} movies'
                          : null,
                      icon: Icons.calendar_month_outlined,
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── Monthly bar chart ──────────────────────────────────
                SectionHeader(
                  title: _selectedYear != null
                      ? 'Monthly Activity ($_selectedYear)'
                      : 'Monthly Activity (${DateTime.now().year})',
                ),
                const SizedBox(height: 12),
                MonthlyBarChart(
                  buckets: buckets,
                  maxValue: maxBucket,
                  mostActiveIndex: mostActive,
                ),

                // ── Top genres ─────────────────────────────────────────
                if (topGenres.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const SectionHeader(title: 'Top Genres'),
                  const SizedBox(height: 12),
                  ...topGenres.asMap().entries.map((entry) {
                    final rank = entry.key;
                    final genre = entry.value;
                    final maxCount = topGenres.first.value;
                    return GenreBar(
                      rank: rank + 1,
                      name: genre.key,
                      count: genre.value,
                      maxCount: maxCount,
                    );
                  }),
                ],

                // ── All-time per-year breakdown ────────────────────────
                if (_selectedYear == null && years.length > 1) ...[
                  const SizedBox(height: 28),
                  const SectionHeader(title: 'By Year'),
                  const SizedBox(height: 12),
                  YearBreakdown(entries: _allEntries, years: years),
                ],
              ],
            ),
    );
  }
}
