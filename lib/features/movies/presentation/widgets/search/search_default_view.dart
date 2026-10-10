import 'package:flixie_app/core/widgets/flixie_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import '../../controllers/search_controller.dart';
import 'search_content.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';

class SearchDefaultView extends StatelessWidget {
  const SearchDefaultView({
    super.key,
    required this.state,
    required this.onHistory,
  });
  final SearchScreenController state;
  final ValueChanged<String> onHistory;
  @override
  Widget build(BuildContext context) =>
      FlixieRefresh(onRefresh: state.refresh, child: _content(context));

  Widget _content(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (state.recentSearches.isNotEmpty) ...[
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.start,
            spacing: 12,
            children: [
              const Text(
                'Recent searches',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: () => state.removeHistory(),
                child: const Text('Clear all'),
              ),
            ],
          ),
          for (final query in state.recentSearches)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded, size: 20),
              title: Text(query),
              trailing: IconButton(
                tooltip: 'Remove $query from recent searches',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => state.removeHistory(query),
              ),
              onTap: () => onHistory(query),
            ),
          const SizedBox(height: 16),
        ],
        const FlixieSectionHeader(title: 'Trending movies'),
        const SizedBox(height: 12),
        if (state.isLoadingDefault && state.trendingMovies.isEmpty)
          const ContentPlaceholder(
            label: 'Loading trending movies',
            style: ContentPlaceholderStyle.posters,
          ),
        if (state.defaultFailed)
          searchRetryMessage(
            'Couldn’t load trending movies.',
            state.loadDefault,
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth /
                    (180 * MediaQuery.textScalerOf(context).scale(1)))
                .floor()
                .clamp(2, 5);
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 20,
              children: [
                for (final movie in state.trendingMovies)
                  SizedBox(
                    width: width,
                    child: SearchTrendingCard(
                      movie: movie,
                      onTap: () => context.push(
                        movieDetailPath(
                          movie.id,
                          source: DetailSource.trending,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class SearchTrendingCard extends StatelessWidget {
  const SearchTrendingCard({super.key, required this.movie, this.onTap});

  final MovieShort movie;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final year = searchReleaseYear(movie.releaseDate);
    final vote = hideMovieRatings(context, movie.id) ? null : movie.voteAverage;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: movie.poster != null
                    ? CachedNetworkImage(
                        imageUrl:
                            'https://image.tmdb.org/t/p/w342${movie.poster}',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: (_, __, ___) => Container(
                          color: context.colors.tabBarBackgroundFocused,
                          child: Icon(
                            Icons.movie_outlined,
                            color: context.colors.medium,
                          ),
                        ),
                      )
                    : Container(
                        color: context.colors.tabBarBackgroundFocused,
                        child: Icon(
                          Icons.movie_outlined,
                          color: context.colors.medium,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              movie.name,
              style: TextStyle(
                color: context.colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 3),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (year != null)
                  Text(
                    year,
                    style: TextStyle(
                      color: context.colors.medium,
                      fontSize: 12,
                    ),
                  ),
                if (year != null && vote != null && vote > 0) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: context.colors.tertiary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    vote.toStringAsFixed(1),
                    style: TextStyle(
                      color: context.colors.tertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
