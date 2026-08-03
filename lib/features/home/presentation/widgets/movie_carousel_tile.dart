import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

/// Shared portrait tile used by the compact movie carousels on the homepage.
class MovieCarouselTile extends StatelessWidget {
  const MovieCarouselTile({
    super.key,
    required this.title,
    this.subtitle,
    this.posterPath,
    this.onTap,
    this.onLongPress,
    this.topLeft,
    this.topRight,
    this.bottomLeft,
    this.bottomRight,
  });

  static const double width = 110;
  static const double posterHeight = 148;

  final String title;
  final String? subtitle;
  final String? posterPath;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? topLeft;
  final Widget? topRight;
  final Widget? bottomLeft;
  final Widget? bottomRight;

  @override
  Widget build(BuildContext context) {
    final rawPoster = posterPath;
    final posterUrl = rawPoster == null || rawPoster.isEmpty
        ? null
        : rawPoster.startsWith('http')
            ? rawPoster
            : 'https://image.tmdb.org/t/p/w342$rawPoster';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: width,
                    height: posterHeight,
                    child: posterUrl == null
                        ? _fallback()
                        : CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _fallback(),
                          ),
                  ),
                ),
                if (topLeft != null)
                  Positioned(top: 6, left: 6, child: topLeft!),
                if (topRight != null)
                  Positioned(top: 6, right: 6, child: topRight!),
                if (bottomLeft != null)
                  Positioned(bottom: 7, left: 7, child: bottomLeft!),
                if (bottomRight != null)
                  Positioned(bottom: 7, right: 7, child: bottomRight!),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 11,
                      color: FlixieColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 9.5,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        color: FlixieColors.tabBarBackgroundFocused,
        alignment: Alignment.center,
        child: const Icon(
          Icons.movie_outlined,
          color: FlixieColors.medium,
          size: 30,
        ),
      );
}
