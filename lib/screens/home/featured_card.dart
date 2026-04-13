import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/movie_short.dart';
import '../../theme/app_theme.dart';

class FeaturedCard extends StatelessWidget {
  const FeaturedCard({super.key, required this.movie, this.onTap});

  final MovieShort movie;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster image
              if (movie.poster != null)
                CachedNetworkImage(
                  imageUrl: 'https://image.tmdb.org/t/p/w342${movie.poster}',
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: FlixieColors.primary.withValues(alpha: 0.3),
                    child: const Icon(Icons.movie_outlined, size: 36),
                  ),
                )
              else
                Container(
                  color: FlixieColors.primary.withValues(alpha: 0.3),
                  child: const Icon(Icons.movie_outlined, size: 36),
                ),
              // Stronger gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
              // Rating chip – top right
              if (movie.voteAverage != null && movie.voteAverage! > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: FlixieColors.tertiary.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 11, color: FlixieColors.tertiary),
                        const SizedBox(width: 3),
                        Text(
                          movie.voteAverage!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: FlixieColors.tertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Text content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      movie.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (movie.releaseDate != null &&
                        movie.releaseDate!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        () {
                          final raw = movie.releaseDate!;
                          // Handle ISO format: "2026-03-15" or "2026-03-15T..."
                          final iso = DateTime.tryParse(raw);
                          if (iso != null) return iso.year.toString();
                          // Handle JS date string: "Sun Mar 15 2026"
                          final parts = raw.split(' ');
                          if (parts.length == 4) {
                            return '${parts[2]} ${parts[1]} ${parts[3]}';
                          }
                          return raw;
                        }(),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
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
