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

  String? get _year {
    final releaseDate = movie.releaseDate;
    if (releaseDate == null || releaseDate.isEmpty) return null;
    final parsed = DateTime.tryParse(releaseDate);
    if (parsed != null) return parsed.year.toString();
    return releaseDate.length >= 4 ? releaseDate.substring(0, 4) : null;
  }

  @override
  Widget build(BuildContext context) {
    final year = _year;
    final overview = movie.overview?.trim();
    final rating = movie.voteAverage;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 50,
                  height: 75,
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
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 7,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const _MovieTypePill(),
                        if (year != null)
                          Text(
                            year,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: FlixieColors.medium),
                          ),
                        if (rating != null && rating > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: FlixieColors.warning,
                          ),
                          Text(
                            rating.toStringAsFixed(1),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: FlixieColors.warning),
                          ),
                        ],
                      ],
                    ),
                    if (overview != null && overview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: FlixieColors.light),
                      ),
                    ],
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

class _MovieTypePill extends StatelessWidget {
  const _MovieTypePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: FlixieColors.danger.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: FlixieColors.danger.withValues(alpha: 0.38),
        ),
      ),
      child: const Text(
        'Movie',
        style: TextStyle(
          color: FlixieColors.danger,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
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
