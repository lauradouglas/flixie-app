import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';

class WatchHistoryCard extends StatelessWidget {
  const WatchHistoryCard({
    super.key,
    required this.title,
    this.posterPath,
    this.rating,
    this.reviewed = false,
    this.watchCount,
    required this.formattedDate,
    required this.onTap,
    this.onLogAgain,
    this.onEditEntry,
    this.onWriteReview,
  });

  final String title;
  final String? posterPath;
  final double? rating;
  final bool reviewed;
  final int? watchCount;
  final String formattedDate;
  final VoidCallback onTap;
  final VoidCallback? onLogAgain;
  final VoidCallback? onEditEntry;
  final VoidCallback? onWriteReview;

  @override
  Widget build(BuildContext context) {
    final posterUrl = posterPath != null
        ? (posterPath!.startsWith('http') ? posterPath : 'https://image.tmdb.org/t/p/w500$posterPath')
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _PosterFallback(),
                            errorWidget: (_, __, ___) => _PosterFallback(),
                          )
                        : _PosterFallback(),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: PopupMenuButton<String>(
                        tooltip: 'Actions for $title',
                        color: context.colors.surfaceElevated,
                        onSelected: (value) {
                          if (value == 'open') onTap();
                          if (value == 'log') onLogAgain?.call();
                          if (value == 'edit') onEditEntry?.call();
                          if (value == 'review') onWriteReview?.call();
                        },
                        itemBuilder: (_) => [
                          if (onLogAgain == null) const PopupMenuItem(value: 'open', child: Text('View show details')),
                          if (onLogAgain != null) const PopupMenuItem(
                            value: 'log',
                            child: Text('Log another watch'),
                          ),
                          if (onEditEntry != null)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit latest entry'),
                            ),
                          if (onWriteReview != null)
                            const PopupMenuItem(
                              value: 'review',
                              child: Text('Write a review'),
                            ),
                        ],
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                              child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.more_horiz,
                                color: Colors.white, size: 24),
                          )),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 7,
                      bottom: 7,
                      child: FlixiePill.label(
                          label: Text(watchCount == null
                              ? 'Watched'
                              : '$watchCount× watched')),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 102,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 38,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.24,
                        ),
                      ),
                    ),
                    if (formattedDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 12, color: context.colors.success),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              formattedDate,
                              style: TextStyle(
                                color: context.colors.medium,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (rating != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Your rating: ${rating!.toStringAsFixed(1)}/10${reviewed ? ' • Reviewed' : ''}',
                        style: TextStyle(
                          color: context.colors.tertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else if (reviewed) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Review added',
                        style: TextStyle(
                          color: FlixieColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E2D40),
      child: Center(
        child: Icon(Icons.movie_outlined, color: context.colors.medium),
      ),
    );
  }
}
