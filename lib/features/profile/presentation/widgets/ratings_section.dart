import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';

import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';

class RatingsSection extends StatelessWidget {
  const RatingsSection({
    super.key,
    required this.ratings,
  });

  final List<MovieRating> ratings;

  void _showAllRatingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AllRatingsSheet(ratings: ratings),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final recentRatings = ratings.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlixieSectionHeader(
          title: 'My ratings',
          uppercase: false,
          accentHeight: 22,
          titleStyle: TextStyle(
            color: context.colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
          trailingLabel: ratings.length > 6 ? 'See all' : null,
          trailingColor: FlixieColors.primary,
          onTrailingTap:
              ratings.length > 6 ? () => _showAllRatingsSheet(context) : null,
        ),
        if (recentRatings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No ratings yet.',
              style:
                  textTheme.bodySmall?.copyWith(color: context.colors.medium),
            ),
          )
        else ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recentRatings.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _RatingCard(rating: recentRatings[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.rating});

  final MovieRating rating;

  static const String _imgBase = 'https://image.tmdb.org/t/p/w185';

  @override
  Widget build(BuildContext context) {
    final movie = rating.movie;
    return GestureDetector(
      onTap: () => context.push(movieDetailPath(rating.movieId)),
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: movie?.posterPath != null
                      ? CachedNetworkImage(
                          imageUrl: '$_imgBase${movie!.posterPath}',
                          width: 100,
                          height: 150,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 100,
                          height: 150,
                          color: context.colors.tabBarBorder,
                          child: Icon(
                            Icons.movie,
                            color: context.colors.medium,
                            size: 40,
                          ),
                        ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: FlixiePill.label(
                      label: Text('${rating.rating}'),
                      avatar: Icon(Icons.star, color: context.colors.tertiary)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: Text(
                movie?.title ?? 'Unknown',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.light,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllRatingsSheet extends StatefulWidget {
  const _AllRatingsSheet({required this.ratings});
  final List<MovieRating> ratings;

  @override
  State<_AllRatingsSheet> createState() => _AllRatingsSheetState();
}

class _AllRatingsSheetState extends State<_AllRatingsSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<MovieRating> _filteredRatings = [];

  @override
  void initState() {
    super.initState();
    _filteredRatings = widget.ratings;
    _searchController.addListener(_filterRatings);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterRatings() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredRatings = widget.ratings;
      } else {
        _filteredRatings = widget.ratings
            .where((rating) =>
                rating.movie?.title.toLowerCase().contains(query) ?? false)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
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
                  'My Ratings',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                FlixiePill.label(label: Text('${widget.ratings.length}')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: context.colors.light),
              decoration: InputDecoration(
                hintText: 'Search ratings...',
                hintStyle: TextStyle(
                    color: context.colors.medium.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.search, color: context.colors.medium),
                filled: true,
                fillColor: context.colors.tabBarBorder.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filteredRatings.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'No ratings yet.'
                          : 'No ratings found.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: context.colors.medium,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: _filteredRatings.length,
                    itemBuilder: (_, i) =>
                        _RatingListTile(rating: _filteredRatings[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RatingListTile extends StatelessWidget {
  const _RatingListTile({required this.rating});

  final MovieRating rating;

  static const String _imgBase = 'https://image.tmdb.org/t/p/w92';

  @override
  Widget build(BuildContext context) {
    final movie = rating.movie;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          context.push(movieDetailPath(rating.movieId));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.tabBarBorder.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: movie?.posterPath != null
                    ? CachedNetworkImage(
                        imageUrl: '$_imgBase${movie!.posterPath}',
                        width: 50,
                        height: 75,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 50,
                        height: 75,
                        color: context.colors.tabBarBorder,
                        child: Icon(
                          Icons.movie,
                          color: context.colors.medium,
                          size: 24,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie?.title ?? 'Unknown',
                      style: TextStyle(
                        color: context.colors.light,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (movie?.releaseDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        movie!.releaseDate!.split('-')[0],
                        style: TextStyle(
                          color: context.colors.medium,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FlixiePill.label(
                  label: Text('${rating.rating}'),
                  avatar: Icon(Icons.star, color: context.colors.tertiary)),
            ],
          ),
        ),
      ),
    );
  }
}
