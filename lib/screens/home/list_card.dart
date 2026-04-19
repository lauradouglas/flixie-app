import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/movie_short.dart';
import '../../theme/app_theme.dart';

class HomeListCard extends StatelessWidget {
  const HomeListCard({super.key, required this.movie, this.onTap});

  final MovieShort movie;
  final VoidCallback? onTap;

  Future<void> _searchInCinemas() async {
    final query = Uri.encodeComponent('${movie.name} in cinemas near me');
    final url = Uri.parse('https://www.google.com/search?q=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: FlixieColors.primary, width: 3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Text content
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        movie.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: FlixieColors.white,
                        ),
                      ),
                      if (movie.releaseDate != null &&
                          movie.releaseDate!.length >= 4) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Released: ${movie.releaseDate!}',
                          style: textTheme.bodySmall
                              ?.copyWith(color: FlixieColors.light),
                        ),
                      ],
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _searchInCinemas,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.map_outlined,
                                color: FlixieColors.primary, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Find in cinemas',
                              style: textTheme.bodySmall?.copyWith(
                                color: FlixieColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Poster flush to right
              SizedBox(
                width: 90,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    movie.poster != null
                        ? CachedNetworkImage(
                            imageUrl:
                                'https://image.tmdb.org/t/p/w185${movie.poster}',
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color:
                                  FlixieColors.primary.withValues(alpha: 0.3),
                              child: const Icon(Icons.movie,
                                  color: FlixieColors.primary),
                            ),
                          )
                        : Container(
                            color: FlixieColors.primary.withValues(alpha: 0.3),
                            child: const Icon(Icons.movie,
                                color: FlixieColors.primary),
                          ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Theme.of(context).cardColor,
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.25],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
