import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/home/presentation/widgets/movie_carousel_tile.dart';

class FeaturedCard extends StatelessWidget {
  const FeaturedCard({
    super.key,
    required this.movie,
    this.onTap,
    this.onBookmarkTap,
    this.isBookmarked = false,
    this.isBookmarkUpdating = false,
    this.showNewBadge = false,
    this.recommendationReason,
  });

  final MovieShort movie;
  final VoidCallback? onTap;
  final VoidCallback? onBookmarkTap;
  final bool isBookmarked;
  final bool isBookmarkUpdating;
  final bool showNewBadge;
  final String? recommendationReason;

  @override
  Widget build(BuildContext context) {
    return MovieCarouselTile(
      title: movie.name,
      subtitle: recommendationReason,
      posterPath: movie.poster,
      onTap: onTap,
      topLeft: showNewBadge ? const FlixiePill.label(label: Text('New')) : null,
      topRight: movie.voteAverage != null && movie.voteAverage! > 0
          ? FlixiePill.label(
              label: Text(movie.voteAverage!.toStringAsFixed(1)),
              avatar: Icon(Icons.star_rounded, color: context.colors.tertiary))
          : null,
      bottomLeft: onBookmarkTap != null
          ? Material(
              color: Colors.black.withValues(alpha: 0.66),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: isBookmarkUpdating ? null : onBookmarkTap,
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(
                    isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded,
                    color: isBookmarkUpdating
                        ? context.colors.medium
                        : FlixieColors.primary,
                    size: 20,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
