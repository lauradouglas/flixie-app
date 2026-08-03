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
      topLeft: showNewBadge
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: FlixieColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            )
          : null,
      topRight: movie.voteAverage != null && movie.voteAverage! > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: FlixieColors.tertiary.withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      size: 11, color: FlixieColors.tertiary),
                  const SizedBox(width: 2),
                  Text(
                    movie.voteAverage!.toStringAsFixed(1),
                    style: const TextStyle(
                      color: FlixieColors.tertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
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
                        ? FlixieColors.medium
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
