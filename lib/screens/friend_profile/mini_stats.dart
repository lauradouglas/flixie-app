import 'package:flutter/material.dart';

import '../../models/watchlist_movie.dart';
import '../../theme/app_theme.dart';
import 'genre_tag.dart';
import 'profile_chip.dart';

class FriendMiniStats extends StatelessWidget {
  const FriendMiniStats({super.key, required this.watchedMovies});
  final List<dynamic> watchedMovies;

  List<WatchlistMovieDetails> get _movies {
    final out = <WatchlistMovieDetails>[];
    for (final m in watchedMovies.whereType<Map<String, dynamic>>()) {
      if (m['removed'] == true) continue;
      if (m['movie'] != null) {
        try {
          out.add(WatchlistMovieDetails.fromJson(
              m['movie'] as Map<String, dynamic>));
        } catch (_) {}
      }
    }
    return out;
  }

  String get _runtimeLabel {
    final mins = _movies.fold<int>(0, (s, m) => s + (m.runtime ?? 0));
    if (mins == 0) return '—';
    final d = mins ~/ (60 * 24);
    final h = (mins % (60 * 24)) ~/ 60;
    final m = mins % 60;
    if (d > 0) return '${d}d ${h}h ${m}m';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  List<MapEntry<String, int>> get _topGenres {
    final counts = <String, int>{};
    for (final m in _movies) {
      for (final g in m.genres) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final movies = _movies;
    final topGenres = _topGenres;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // section header
        Row(
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                color: FlixieColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'STATS',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // runtime chip
        Row(
          children: [
            Expanded(
              child: FriendProfileChip(
                icon: Icons.schedule_outlined,
                label: _runtimeLabel,
                sublabel: 'total runtime',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FriendProfileChip(
                icon: Icons.movie_outlined,
                label: movies.isNotEmpty ? '${movies.length}' : '—',
                sublabel: 'movies watched',
              ),
            ),
          ],
        ),

        if (topGenres.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                topGenres.map((e) => FriendGenreTag(name: e.key)).toList(),
          ),
        ],
      ],
    );
  }
}
