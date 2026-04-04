import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

class FavoriteMoviesSection extends StatelessWidget {
  const FavoriteMoviesSection({
    super.key,
    required this.favoriteMovies,
  });

  final List<dynamic> favoriteMovies;

  void _showAllMoviesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AllFavoriteMoviesSheet(favoriteMovies: favoriteMovies),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final top3 = favoriteMovies.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: FlixieColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'FAVOURITE MOVIES',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (favoriteMovies.length > 3)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_forward,
                    color: FlixieColors.primary,
                    size: 20,
                  ),
                  onPressed: () => _showAllMoviesSheet(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
        if (top3.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No favourite movies yet.',
              style: textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
            ),
          )
        else
          Row(
            children: top3.map((item) {
              final movie = _parseMovie(item);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _MoviePosterCard(
                    movieId: movie.$1,
                    title: movie.$2,
                    posterPath: movie.$3,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  /// Returns (movieId, title, posterPath) from a favoriteMovies item.
  (int?, String, String?) _parseMovie(dynamic item) {
    if (item is Map<String, dynamic>) {
      final movie = item['movie'] as Map<String, dynamic>?;
      final id =
          (item['movieId'] as num?)?.toInt() ?? (movie?['id'] as num?)?.toInt();
      final title = movie?['title'] as String? ?? 'Unknown';
      final poster = movie?['posterPath'] as String?;
      return (id, title, poster);
    }
    return (null, 'Unknown', null);
  }
}

class _MoviePosterCard extends StatelessWidget {
  const _MoviePosterCard({
    required this.movieId,
    required this.title,
    this.posterPath,
  });

  final int? movieId;
  final String title;
  final String? posterPath;

  static const String _imgBase = 'https://image.tmdb.org/t/p/w185';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: movieId != null ? () => context.push('/movies/$movieId') : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: posterPath != null
                  ? CachedNetworkImage(
                      imageUrl: '$_imgBase$posterPath',
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _fallback(),
                    )
                  : _fallback(),
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              title.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: FlixieColors.tabBarBorder,
      child: const Icon(
        Icons.movie_outlined,
        color: FlixieColors.medium,
        size: 36,
      ),
    );
  }
}

class _AllFavoriteMoviesSheet extends StatelessWidget {
  const _AllFavoriteMoviesSheet({required this.favoriteMovies});
  final List<dynamic> favoriteMovies;

  (int?, String, String?) _parseMovie(dynamic item) {
    if (item is Map<String, dynamic>) {
      final movie = item['movie'] as Map<String, dynamic>?;
      final id =
          (item['movieId'] as num?)?.toInt() ?? (movie?['id'] as num?)?.toInt();
      final title = movie?['title'] as String? ?? 'Unknown';
      final poster = movie?['posterPath'] as String?;
      return (id, title, poster);
    }
    return (null, 'Unknown', null);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: FlixieColors.medium.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Favourite Movies',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FlixieColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${favoriteMovies.length}',
                    style: const TextStyle(
                      color: FlixieColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 10,
                childAspectRatio: 0.55,
              ),
              itemCount: favoriteMovies.length,
              itemBuilder: (_, i) {
                final movie = _parseMovie(favoriteMovies[i]);
                return _MoviePosterCard(
                  movieId: movie.$1,
                  title: movie.$2,
                  posterPath: movie.$3,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
