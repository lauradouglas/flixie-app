import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';

import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class FavoriteMoviesSection extends StatelessWidget {
  const FavoriteMoviesSection({
    super.key,
    required this.favoriteMovies,
  });

  final List<FavoriteMovie> favoriteMovies;

  void _showAllMoviesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: context.colors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AllFavoriteMoviesSheet(
          favoriteMovies:
              favoriteMovies.where((e) => e.removed != true).toList()
                ..sort((a, b) => (a.rank ?? 999).compareTo(b.rank ?? 999))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ranked = favoriteMovies
        .where((movie) => movie.removed != true)
        .toList()
      ..sort((a, b) => (a.rank ?? 999).compareTo(b.rank ?? 999));
    final visibleMovies = ranked.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                  child: Text(
                'Favourite movies',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary),
              )),
              if (ranked.isNotEmpty)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_forward,
                    color: FlixieColors.primary,
                    size: 20,
                  ),
                  tooltip: 'See all favourite movies',
                  onPressed: () => _showAllMoviesSheet(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
        if (visibleMovies.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No favourite movies yet.',
              style:
                  textTheme.bodySmall?.copyWith(color: context.colors.medium),
            ),
          )
        else
          SizedBox(
            height: 150 + 6 + MediaQuery.textScalerOf(context).scale(38),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visibleMovies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final movie = _parseMovie(visibleMovies[index]);
                return SizedBox(
                  width: 100,
                  child: _MoviePosterCard(
                    movieId: movie.$1,
                    title: movie.$2,
                    posterPath: movie.$3,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// Returns (movieId, title, posterPath) from a favoriteMovies item.
  (int?, String, String?) _parseMovie(FavoriteMovie item) {
    final title = item.movie?['title'] as String? ?? 'Unknown';
    final poster = item.movie?['posterPath'] as String?;
    return (item.movieId, title, poster);
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
      onTap: movieId != null
          ? () => context.push(movieDetailPath(movieId!))
          : null,
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
                      errorWidget: (_, __, ___) => _fallback(context),
                    )
                  : _fallback(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.colors.light,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: context.colors.tabBarBorder,
      child: Icon(
        Icons.movie_outlined,
        color: context.colors.medium,
        size: 36,
      ),
    );
  }
}

class _AllFavoriteMoviesSheet extends StatelessWidget {
  const _AllFavoriteMoviesSheet({required this.favoriteMovies});
  final List<FavoriteMovie> favoriteMovies;

  (int?, String, String?) _parseMovie(FavoriteMovie item) {
    final title = item.movie?['title'] as String? ?? 'Unknown';
    final poster = item.movie?['posterPath'] as String?;
    return (item.movieId, title, poster);
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
              color: context.colors.medium.withValues(alpha: 0.4),
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
                FlixiePill.label(label: Text('${favoriteMovies.length}')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final scaler = MediaQuery.textScalerOf(context);
              final availableWidth = constraints.maxWidth - 40;
              final columns = (availableWidth / (scaler.scale(100) + 10))
                  .floor()
                  .clamp(1, 5);
              final posterWidth =
                  (availableWidth - (columns - 1) * 10) / columns;
              return GridView.builder(
                controller: scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 10,
                  mainAxisExtent:
                      posterWidth * 1.5 + 6 + scaler.scale(13) * 1.4 * 2 + 4,
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
              );
            }),
          ),
        ],
      ),
    );
  }
}
