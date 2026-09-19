import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';

import 'package:flixie_app/models/movie_wrapped.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

const wrappedMonthNames = [
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

// ── Headline stat card ────────────────────────────────────────────────────────

class WrappedHeadlineCard extends StatelessWidget {
  const WrappedHeadlineCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.surfaceElevated,
            context.colors.tabBarBackgroundFocused,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FlixieColors.primary.withValues(alpha: .22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: FlixieColors.primary.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: FlixieColors.primary, size: 17),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  letterSpacing: -.3,
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.medium,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Month grid ────────────────────────────────────────────────────────────────

class WrappedMonthGrid extends StatelessWidget {
  const WrappedMonthGrid({super.key, required this.months});
  final List<WrappedMonthlyCount> months;

  @override
  Widget build(BuildContext context) {
    final countByMonth = {for (final m in months) m.month: m.count};
    final maxCount = countByMonth.values.fold(0, (a, b) => a > b ? a : b);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: .9,
      ),
      itemCount: 12,
      itemBuilder: (_, i) {
        final month = i + 1;
        final count = countByMonth[month] ?? 0;
        final intensity = maxCount > 0 ? count / maxCount : 0.0;
        final bg = Color.lerp(
          context.colors.tabBarBackgroundFocused,
          FlixieColors.primary,
          intensity * 0.85,
        )!;
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: FlixieColors.primary.withValues(
                alpha: .14 + (intensity * .25),
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                wrappedMonthNames[i],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: intensity > 0.4 ? Colors.white : context.colors.light,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: intensity > 0.4 ? Colors.white : context.colors.medium,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Genre chips ───────────────────────────────────────────────────────────────

class WrappedGenreChips extends StatelessWidget {
  const WrappedGenreChips({super.key, required this.genres});
  final List<WrappedNamedCount> genres;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: genres.map((g) {
        return FlixiePill.label(
            colorKey: g.name, label: Text('${g.name}  ${g.count}'));
      }).toList(),
    );
  }
}

// ── Director list ─────────────────────────────────────────────────────────────

class WrappedDirectorList extends StatelessWidget {
  const WrappedDirectorList({super.key, required this.directors});
  final List<WrappedNamedCount> directors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: directors.map((d) {
        final tappable = d.personId != null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            visualDensity: const VisualDensity(vertical: -2),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: context.colors.surfaceElevated.withValues(alpha: .55),
            title: Text(
              d.name,
              style: TextStyle(
                color: tappable ? FlixieColors.primary : context.colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${d.count} film${d.count == 1 ? '' : 's'}',
                    style: TextStyle(color: context.colors.medium)),
                if (tappable) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      color: context.colors.medium, size: 18),
                ],
              ],
            ),
            onTap: tappable
                ? () => context.push(personDetailPath(d.personId!))
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// ── Summary hero card ─────────────────────────────────────────────────────────

class WrappedSummaryCard extends StatelessWidget {
  const WrappedSummaryCard({super.key, required this.card});
  final WrappedCard card;

  @override
  Widget build(BuildContext context) {
    final posterPath = card.mostRewatchedMovie?.posterPath;
    final posterUrl = posterPath != null
        ? 'https://image.tmdb.org/t/p/w342$posterPath'
        : null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1040), Color(0xFF2A1B5E), Color(0xFF0D1B2A)],
        ),
        border: Border.all(color: FlixieColors.primary.withValues(alpha: 0.4)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (posterUrl != null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.08,
                  child: CachedNetworkImage(
                      imageUrl: posterUrl, fit: BoxFit.cover),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FlixiePill.label(label: Text('${card.year} Wrapped')),
                  const SizedBox(height: 14),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${card.totalWatchCount}',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: context.colors.white,
                            height: 1,
                          ),
                        ),
                        TextSpan(
                          text: ' watches',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: context.colors.light,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (card.topGenre != null)
                        Expanded(
                          child: _SummaryStatColumn(
                            label: 'Top Genre',
                            value: card.topGenre!.name,
                            icon: Icons.category_outlined,
                          ),
                        ),
                      if (card.topGenre != null && card.topDirector != null)
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white12,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      if (card.topDirector != null)
                        Expanded(
                          child: _SummaryStatColumn(
                            label: 'Top Director',
                            value: card.topDirector!.name,
                            icon: Icons.movie_creation_outlined,
                          ),
                        ),
                    ],
                  ),
                  if (card.mostRewatchedMovie != null) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),
                    _SummaryMovieRow(
                      movie: card.mostRewatchedMovie!,
                      posterUrl: posterUrl,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStatColumn extends StatelessWidget {
  const _SummaryStatColumn({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: context.colors.medium),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 11, color: context.colors.medium)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.colors.white,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _SummaryMovieRow extends StatelessWidget {
  const _SummaryMovieRow({required this.movie, required this.posterUrl});
  final WrappedTopMovie movie;
  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 36,
            height: 52,
            child: posterUrl == null
                ? Container(
                    color: context.colors.tabBarBackgroundFocused,
                    child: const Icon(Icons.movie_outlined, size: 16),
                  )
                : CachedNetworkImage(imageUrl: posterUrl!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Most Rewatched',
                  style: TextStyle(fontSize: 11, color: context.colors.medium)),
              const SizedBox(height: 2),
              Text(
                movie.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        FlixiePill.label(label: Text('${movie.watchCount}x')),
      ],
    );
  }
}

// ── Movie rows ────────────────────────────────────────────────────────────────

class WrappedRatedMovieRow extends StatelessWidget {
  const WrappedRatedMovieRow({super.key, required this.movie});
  final WrappedRatedMovie movie;

  @override
  Widget build(BuildContext context) {
    final url = movie.posterPath != null
        ? 'https://image.tmdb.org/t/p/w185${movie.posterPath}'
        : null;
    return _MovieRowBase(
      movieId: movie.movieId,
      title: movie.title,
      posterUrl: url,
      badge: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 15),
          const SizedBox(width: 3),
          Text(
            '${movie.rating}/10',
            style: TextStyle(
              color: context.colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class WrappedRewatchMovieRow extends StatelessWidget {
  const WrappedRewatchMovieRow({super.key, required this.movie});
  final WrappedTopMovie movie;

  @override
  Widget build(BuildContext context) {
    final url = movie.posterPath != null
        ? 'https://image.tmdb.org/t/p/w185${movie.posterPath}'
        : null;
    return _MovieRowBase(
      movieId: movie.movieId,
      title: movie.title,
      posterUrl: url,
      badge: Text(
        '${movie.watchCount}x',
        style: const TextStyle(
          color: FlixieColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _MovieRowBase extends StatelessWidget {
  const _MovieRowBase({
    required this.movieId,
    required this.title,
    required this.posterUrl,
    required this.badge,
  });
  final int movieId;
  final String title;
  final String? posterUrl;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(movieDetailPath(movieId)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: FlixieColors.primary.withValues(alpha: .16),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 39,
                height: 56,
                child: posterUrl == null
                    ? Container(
                        color: const Color(0xFF1E1E2E),
                        child: Icon(Icons.movie_outlined,
                            size: 20, color: context.colors.medium),
                      )
                    : CachedNetworkImage(
                        imageUrl: posterUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: const Color(0xFF1E1E2E)),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            badge,
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: context.colors.medium, size: 18),
          ],
        ),
      ),
    );
  }
}
