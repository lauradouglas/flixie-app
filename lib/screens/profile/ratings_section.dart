import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/movie_rating.dart';
import '../../theme/app_theme.dart';

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
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
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
                'MY RATINGS',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (ratings.length > 6)
                TextButton(
                  onPressed: () => _showAllRatingsSheet(context),
                  child: const Text(
                    'See All',
                    style: TextStyle(color: FlixieColors.primary),
                  ),
                ),
            ],
          ),
        ),
        if (recentRatings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No ratings yet.',
              style: textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
            ),
          )
        else
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
      onTap: () => context.push('/movies/${rating.movieId}'),
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
                          color: FlixieColors.tabBarBorder,
                          child: const Icon(
                            Icons.movie,
                            color: FlixieColors.medium,
                            size: 40,
                          ),
                        ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: FlixieColors.tertiary,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${rating.rating}',
                          style: const TextStyle(
                            color: FlixieColors.light,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                style: const TextStyle(
                  color: FlixieColors.light,
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
                  'My Ratings',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FlixieColors.tertiary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.ratings.length}',
                    style: const TextStyle(
                      color: FlixieColors.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: FlixieColors.light),
              decoration: InputDecoration(
                hintText: 'Search ratings...',
                hintStyle: TextStyle(
                    color: FlixieColors.medium.withValues(alpha: 0.6)),
                prefixIcon:
                    const Icon(Icons.search, color: FlixieColors.medium),
                filled: true,
                fillColor: FlixieColors.tabBarBorder.withValues(alpha: 0.3),
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
                        color: FlixieColors.medium,
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
          context.push('/movies/${rating.movieId}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlixieColors.tabBarBorder.withValues(alpha: 0.2),
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
                        color: FlixieColors.tabBarBorder,
                        child: const Icon(
                          Icons.movie,
                          color: FlixieColors.medium,
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
                      style: const TextStyle(
                        color: FlixieColors.light,
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
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: FlixieColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      color: FlixieColors.tertiary,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${rating.rating}',
                      style: const TextStyle(
                        color: FlixieColors.light,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
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
