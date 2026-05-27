import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/trending_groups.dart';
import '../../theme/app_theme.dart';
import '../../utils/skeleton.dart';
import 'section_header.dart';

class TrendingGroupsSection extends StatelessWidget {
  const TrendingGroupsSection({
    super.key,
    required this.isLoading,
    required this.response,
    required this.onSeeAll,
    required this.onOpenGroup,
    required this.onOpenMovie,
    required this.onRetry,
    required this.onExploreGroups,
    this.errorMessage,
  });

  final bool isLoading;
  final TrendingGroupsResponse? response;
  final String? errorMessage;
  final VoidCallback onSeeAll;
  final ValueChanged<String> onOpenGroup;
  final ValueChanged<int> onOpenMovie;
  final VoidCallback onRetry;
  final VoidCallback onExploreGroups;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _TrendingGroupsLoadingState();
    }

    final groups = response?.groups ?? const <TrendingGroup>[];
    if (errorMessage != null) {
      return _TrendingGroupsErrorState(
        onRetry: onRetry,
        errorMessage: errorMessage!,
        onSeeAll: onSeeAll,
      );
    }

    if (groups.isEmpty) {
      return _TrendingGroupsEmptyState(
        onSeeAll: onSeeAll,
        onExploreGroups: onExploreGroups,
      );
    }

    final summary = response?.summary ??
        const TrendingSummary(
          totalActivities: 0,
          moviesDiscussed: 0,
          highlyRatedCount: 0,
          newGroupsThisWeek: 0,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Trending In Your Groups',
          onSeeAll: onSeeAll,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 360,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => SizedBox(
              width: 320,
              child: TrendingGroupCard(
                group: groups[index],
                onOpenGroup: onOpenGroup,
                onOpenMovie: onOpenMovie,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TrendingGroupsSummaryStats(summary: summary),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class TrendingGroupCard extends StatelessWidget {
  const TrendingGroupCard({
    super.key,
    required this.group,
    required this.onOpenGroup,
    required this.onOpenMovie,
  });

  final TrendingGroup group;
  final ValueChanged<String> onOpenGroup;
  final ValueChanged<int> onOpenMovie;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onOpenGroup(group.id),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: FlixieColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                _GroupAvatar(group: group),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${group.memberCount} members',
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                if (group.trendPercent != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: FlixieColors.success.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: FlixieColors.success.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '${group.trendPercent! >= 0 ? '↑' : '↓'} ${group.trendPercent!.abs().round()}%',
                      style: const TextStyle(
                        color: FlixieColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.bolt, color: FlixieColors.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.trendLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TrendingMoviePosterStrip(
              movies: group.trendingMovies,
              onOpenMovie: onOpenMovie,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: FlixieColors.tabBarBackgroundFocused,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bar_chart, color: FlixieColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${group.activityCount} activities',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: FlixieColors.medium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrendingMoviePosterStrip extends StatelessWidget {
  const TrendingMoviePosterStrip({
    super.key,
    required this.movies,
    required this.onOpenMovie,
  });

  final List<TrendingMovie> movies;
  final ValueChanged<int> onOpenMovie;

  @override
  Widget build(BuildContext context) {
    final displayed = movies.take(4).toList(growable: false);
    if (displayed.isEmpty) {
      return Container(
        height: 122,
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const Text(
          'No movies yet',
          style: TextStyle(color: FlixieColors.medium),
        ),
      );
    }

    return Row(
      children: [
        for (final movie in displayed) ...[
          Expanded(
            child: GestureDetector(
              onTap: () {
                final movieId = movie.tmdbId;
                if (movieId != null) onOpenMovie(movieId);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 0.74,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: movie.posterUrl != null
                          ? CachedNetworkImage(
                              imageUrl: movie.posterUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _PosterFallback(movie),
                            )
                          : _PosterFallback(movie),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    movie.title.isEmpty ? 'Unknown title' : movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.light,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (movie != displayed.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class TrendingGroupsSummaryStats extends StatelessWidget {
  const TrendingGroupsSummaryStats({super.key, required this.summary});

  final TrendingSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TrendingStatItem(
              icon: Icons.trending_up,
              value: summary.totalActivities,
              label: 'Total Activities',
              color: FlixieColors.primary,
            ),
          ),
          _divider(),
          Expanded(
            child: TrendingStatItem(
              icon: Icons.movie_filter_outlined,
              value: summary.moviesDiscussed,
              label: 'Movies Discussed',
              color: FlixieColors.success,
            ),
          ),
          _divider(),
          Expanded(
            child: TrendingStatItem(
              icon: Icons.star_border,
              value: summary.highlyRatedCount,
              label: 'Highly Rated',
              color: FlixieColors.tertiary,
            ),
          ),
          _divider(),
          Expanded(
            child: TrendingStatItem(
              icon: Icons.group_outlined,
              value: summary.newGroupsThisWeek,
              label: 'New This Week',
              color: Colors.lightBlueAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 64,
      color: Colors.white.withValues(alpha: 0.12),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class TrendingStatItem extends StatelessWidget {
  const TrendingStatItem({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: FlixieColors.light,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TrendingGroupsLoadingState extends StatelessWidget {
  const _TrendingGroupsLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(title: 'Trending In Your Groups'),
        const SizedBox(height: 12),
        SizedBox(
          height: 360,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 2,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => Container(
              width: 320,
              decoration: BoxDecoration(
                color: FlixieColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              padding: const EdgeInsets.all(14),
              child: const Column(
                children: [
                  SkeletonBox(height: 68, borderRadius: 14),
                  SizedBox(height: 14),
                  SkeletonBox(height: 26, borderRadius: 10),
                  SizedBox(height: 14),
                  SkeletonBox(height: 120, borderRadius: 14),
                  Spacer(),
                  SkeletonBox(height: 54, borderRadius: 14),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SkeletonBox(height: 94, borderRadius: 20),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _TrendingGroupsEmptyState extends StatelessWidget {
  const _TrendingGroupsEmptyState({
    required this.onSeeAll,
    required this.onExploreGroups,
  });

  final VoidCallback onSeeAll;
  final VoidCallback onExploreGroups;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Trending In Your Groups',
          onSeeAll: onSeeAll,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: FlixieColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No group trends yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Start watching, rating or adding movies with your groups.',
                  style: TextStyle(color: FlixieColors.light),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onExploreGroups,
                  child: const Text('Explore Groups'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _TrendingGroupsErrorState extends StatelessWidget {
  const _TrendingGroupsErrorState({
    required this.onRetry,
    required this.errorMessage,
    required this.onSeeAll,
  });

  final VoidCallback onRetry;
  final String errorMessage;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Trending In Your Groups',
          onSeeAll: onSeeAll,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: FlixieColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: FlixieColors.light),
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.group});

  final TrendingGroup group;

  @override
  Widget build(BuildContext context) {
    if (group.avatarUrl != null) {
      return SizedBox(
        width: 56,
        height: 56,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: group.avatarUrl!,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _initialsAvatar(),
          ),
        ),
      );
    }
    return _initialsAvatar();
  }

  Widget _initialsAvatar() {
    return CircleAvatar(
      radius: 28,
      backgroundColor: FlixieColors.primary.withValues(alpha: 0.35),
      child: Text(
        group.initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 26,
        ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback(this.movie);

  final TrendingMovie movie;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FlixieColors.tabBarBackgroundFocused,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: Text(
        movie.title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: FlixieColors.light,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
