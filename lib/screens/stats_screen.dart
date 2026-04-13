import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/watchlist_movie.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'stats/stats_entry.dart';

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
                    _StatCard(
                      label: 'Movies Watched',
                      value: _totalMovies > 0 ? '$_totalMovies' : '—',
                      icon: Icons.movie_outlined,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Total Runtime',
                      value: _totalMovies > 0 ? _runtimeLabel : '—',
                      icon: Icons.schedule_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCard(
                      label: 'Avg Rating',
                      value:
                          _avgRating > 0 ? _avgRating.toStringAsFixed(1) : '—',
                      icon: Icons.star_outline,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
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
                _SectionHeader(
                  title: _selectedYear != null
                      ? 'Monthly Activity ($_selectedYear)'
                      : 'Monthly Activity (${DateTime.now().year})',
                ),
                const SizedBox(height: 12),
                _MonthlyBarChart(
                  buckets: buckets,
                  maxValue: maxBucket,
                  mostActiveIndex: mostActive,
                ),

                // ── Top genres ─────────────────────────────────────────
                if (topGenres.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const _SectionHeader(title: 'Top Genres'),
                  const SizedBox(height: 12),
                  ...topGenres.asMap().entries.map((entry) {
                    final rank = entry.key;
                    final genre = entry.value;
                    final maxCount = topGenres.first.value;
                    return _GenreBar(
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
                  const _SectionHeader(title: 'By Year'),
                  const SizedBox(height: 12),
                  _YearBreakdown(entries: _allEntries, years: years),
                ],
              ],
            ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: FlixieColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: FlixieColors.primary, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!,
                  style: const TextStyle(
                      color: FlixieColors.medium, fontSize: 11)),
            ],
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: FlixieColors.medium, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  const _MonthlyBarChart({
    required this.buckets,
    required this.maxValue,
    required this.mostActiveIndex,
  });

  final List<int> buckets;
  final int maxValue;
  final int mostActiveIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(12, (i) {
          final count = buckets[i];
          final isActive = i == mostActiveIndex;
          final fraction = maxValue > 0 ? count / maxValue : 0.0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (count > 0)
                    Text(
                      '$count',
                      style: TextStyle(
                        color: isActive
                            ? FlixieColors.primary
                            : FlixieColors.medium,
                        fontSize: 9,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    height: 80 * fraction,
                    decoration: BoxDecoration(
                      color: isActive
                          ? FlixieColors.primary
                          : FlixieColors.primary.withValues(alpha: 0.35),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _kMonthNames[i],
                    style: TextStyle(
                      color: isActive ? Colors.white : FlixieColors.medium,
                      fontSize: 9,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _GenreBar extends StatelessWidget {
  const _GenreBar({
    required this.rank,
    required this.name,
    required this.count,
    required this.maxCount,
  });

  final int rank;
  final String name;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final fraction = maxCount > 0 ? count / maxCount : 0.0;
    final accent = rank == 1
        ? FlixieColors.primary
        : FlixieColors.primary.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              style: const TextStyle(
                  color: FlixieColors.medium,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13)),
                    Text('$count',
                        style: const TextStyle(
                            color: FlixieColors.medium, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: FlixieColors.tabBarBackgroundFocused,
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _YearBreakdown extends StatelessWidget {
  const _YearBreakdown({required this.entries, required this.years});
  final List<StatsEntry> entries;
  final List<int> years;

  @override
  Widget build(BuildContext context) {
    final maxCount = years.fold<int>(0, (m, y) {
      final c = entries.where((e) => e.watchedAt?.year == y).length;
      return c > m ? c : m;
    });

    return Column(
      children: years.map((y) {
        final count = entries.where((e) => e.watchedAt?.year == y).length;
        final fraction = maxCount > 0 ? count / maxCount : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text('$y',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 8,
                    backgroundColor: FlixieColors.tabBarBackgroundFocused,
                    valueColor: AlwaysStoppedAnimation(
                        FlixieColors.primary.withValues(alpha: 0.7)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$count',
                  style: const TextStyle(
                      color: FlixieColors.medium, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
