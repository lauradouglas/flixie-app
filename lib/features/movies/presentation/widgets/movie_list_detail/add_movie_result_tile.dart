import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

import 'package:flixie_app/features/movies/presentation/movie_list_selection.dart';

class AddMovieResultTile extends StatelessWidget {
  const AddMovieResultTile({
    super.key,
    required this.movie,
    required this.alreadyAdded,
    required this.isAdding,
    required this.onAdd,
  });

  final MovieShort movie;
  final bool alreadyAdded;
  final bool isAdding;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final posterUrl = movie.poster == null
        ? null
        : 'https://image.tmdb.org/t/p/w185${movie.poster}';
    final year = extractYear(movie.releaseDate);

    return Material(
      color: alreadyAdded
          ? FlixieColors.primary.withValues(alpha: .09)
          : context.colors.tabBarBackgroundFocused,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: alreadyAdded
              ? FlixieColors.primary.withValues(alpha: .45)
              : Colors.transparent,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onAdd,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 72,
                  child: posterUrl == null
                      ? Container(
                          color: const Color(0xFF1E2D40),
                          child: Icon(
                            Icons.movie_outlined,
                            color: context.colors.medium,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFF1E2D40),
                            child: Icon(
                              Icons.movie_outlined,
                              color: context.colors.medium,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.name,
                      style: TextStyle(
                        color: context.colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    ...[
                      const SizedBox(height: 4),
                      Text(
                        '${movie.mediaType == 'tv' ? 'Show' : 'Movie'}${year == null ? '' : ' · $year'}',
                        style: TextStyle(
                          color: context.colors.medium,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (alreadyAdded) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded,
                              size: 16, color: context.colors.primaryText),
                          const SizedBox(width: 4),
                          Flexible(
                              child: Text('Added',
                                  style: TextStyle(
                                      color: context.colors.primaryText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (isAdding)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (!alreadyAdded)
                IconButton.outlined(
                  tooltip: 'Add ${movie.name}',
                  onPressed: onAdd,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: context.colors.primaryText,
                    side: BorderSide(
                        color:
                            context.colors.primaryText.withValues(alpha: .3)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 22),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
