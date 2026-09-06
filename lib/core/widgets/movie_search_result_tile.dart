import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/movie_short.dart';

class MovieSearchResultTile extends StatelessWidget {
  const MovieSearchResultTile({
    super.key,
    required this.movie,
    this.onTap,
  });

  final MovieShort movie;
  final VoidCallback? onTap;

  String? get _releaseDateLabel {
    final releaseDate = movie.releaseDate;
    if (releaseDate == null || releaseDate.isEmpty) return null;
    final parsed = DateTime.tryParse(releaseDate);
    if (parsed != null) return _formatDate(parsed);

    // Some cinema feeds return an already-localised value such as “29 Jun
    // 2026”. Keep that intact rather than truncating it to “29 J”.
    final words = releaseDate.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) return words.take(3).join(' ');
    return releaseDate;
  }

  String _formatDate(DateTime date) {
    const months = [
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final releaseDate = _releaseDateLabel;
    final rating = movie.voteAverage;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 50,
                  height: 68,
                  child: movie.poster != null
                      ? CachedNetworkImage(
                          imageUrl:
                              'https://image.tmdb.org/t/p/w92${movie.poster}',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const _MoviePlaceholder(),
                        )
                      : const _MoviePlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (releaseDate != null)
                          _MovieMetadata(
                            icon: Icons.calendar_today_outlined,
                            label: releaseDate,
                          ),
                        if (rating != null && rating > 0) ...[
                          _MovieMetadata(
                            icon: Icons.star_rounded,
                            label: rating.toStringAsFixed(1),
                            color: FlixieColors.warning,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: FlixieColors.medium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovieMetadata extends StatelessWidget {
  const _MovieMetadata({
    required this.icon,
    required this.label,
    this.color = FlixieColors.medium,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MoviePlaceholder extends StatelessWidget {
  const _MoviePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FlixieColors.danger.withValues(alpha: 0.2),
      child: const Icon(Icons.movie_rounded, color: FlixieColors.danger),
    );
  }
}
