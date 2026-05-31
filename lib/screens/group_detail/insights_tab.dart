import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/group_insights.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/skeleton.dart';

class GroupInsightsTab extends StatefulWidget {
  const GroupInsightsTab({
    super.key,
    required this.groupId,
  });

  final String groupId;

  @override
  State<GroupInsightsTab> createState() => _GroupInsightsTabState();
}

class _GroupInsightsTabState extends State<GroupInsightsTab> {
  bool _loading = true;
  String? _error;
  GroupInsightsResponse _insights = const GroupInsightsResponse();

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final insights = await GroupService.getGroupInsights(widget.groupId);
      if (!mounted) return;
      setState(() {
        _insights = insights;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Couldn\'t load group insights';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _InsightsLoadingState();

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insights_outlined,
                  color: FlixieColors.medium, size: 40),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadInsights,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_insights.isCompletelyEmpty) {
      return RefreshIndicator(
        onRefresh: _loadInsights,
        color: FlixieColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: const [
            SizedBox(height: 64),
            Icon(Icons.auto_graph_outlined,
                size: 52, color: FlixieColors.medium),
            SizedBox(height: 16),
            Text(
              'No group insights yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FlixieColors.light,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Start watching, rating, reviewing, or discussing movies with this group.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FlixieColors.medium,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInsights,
      color: FlixieColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          if (_insights.mostWatchedThisMonth.isNotEmpty) ...[
            const InsightSectionHeader(
              title: 'Most Watched This Month',
              icon: Icons.local_fire_department_outlined,
            ),
            const SizedBox(height: 10),
            HorizontalPosterRail(
              children: _insights.mostWatchedThisMonth
                  .map(
                    (movie) => InsightMovieCard(
                      movie: movie,
                      variant: InsightMovieCardVariant.mostWatched,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 18),
          ],
          if (_insights.mostDiscussedMovies.isNotEmpty) ...[
            const InsightSectionHeader(
              title: 'Most Discussed Movies',
              icon: Icons.forum_outlined,
            ),
            const SizedBox(height: 10),
            HorizontalPosterRail(
              children: _insights.mostDiscussedMovies
                  .map(
                    (movie) => InsightMovieCard(
                      movie: movie,
                      variant: InsightMovieCardVariant.mostDiscussed,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 18),
          ],
          if (_insights.highestRatedMovies.isNotEmpty) ...[
            const InsightSectionHeader(
              title: 'Highest Rated Movies',
              icon: Icons.star_rounded,
            ),
            const SizedBox(height: 10),
            HorizontalPosterRail(
              children: _insights.highestRatedMovies
                  .map(
                    (movie) => InsightMovieCard(
                      movie: movie,
                      variant: InsightMovieCardVariant.highestRated,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 18),
          ],
          if (_insights.recentReviews.isNotEmpty) ...[
            const InsightSectionHeader(
              title: 'Recent Reviews',
              icon: Icons.rate_review_outlined,
            ),
            const SizedBox(height: 10),
            ..._insights.recentReviews
                .map((review) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InsightReviewCard(review: review),
                    ))
                .toList(growable: false),
            const SizedBox(height: 8),
          ],
          if (_insights.mostActiveMembers.isNotEmpty) ...[
            const InsightSectionHeader(
              title: 'Most Active Members',
              icon: Icons.bolt_outlined,
            ),
            const SizedBox(height: 10),
            ..._insights.mostActiveMembers
                .map((member) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InsightMemberCard(member: member),
                    ))
                .toList(growable: false),
          ],
        ],
      ),
    );
  }
}

class InsightSectionHeader extends StatelessWidget {
  const InsightSectionHeader({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: FlixieColors.primary,
            boxShadow: [
              BoxShadow(
                color: FlixieColors.primary.withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: FlixieColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: FlixieColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

enum InsightMovieCardVariant {
  mostWatched,
  mostDiscussed,
  highestRated,
}

class InsightMovieCard extends StatelessWidget {
  const InsightMovieCard({
    super.key,
    required this.movie,
    required this.variant,
  });

  final GroupInsightMovie movie;
  final InsightMovieCardVariant variant;

  static const _posterBase = 'https://image.tmdb.org/t/p/w342';

  @override
  Widget build(BuildContext context) {
    final posterUrl = _resolvePosterUrl(movie.posterPath, _posterBase);
    final subtitle = switch (variant) {
      InsightMovieCardVariant.mostWatched =>
        '${movie.watchCount} ${movie.watchCount == 1 ? 'watch' : 'watches'}',
      InsightMovieCardVariant.mostDiscussed =>
        '${movie.discussionCount} ${movie.discussionCount == 1 ? 'message' : 'messages'}',
      InsightMovieCardVariant.highestRated =>
        '${movie.averageRating.toStringAsFixed(1)} group rating • ${movie.ratingCount} ${movie.ratingCount == 1 ? 'rating' : 'ratings'}',
    };

    return InkWell(
      onTap: movie.movieId != null
          ? () => context.push('/movies/${movie.movieId}')
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FlixieColors.surfaceElevated.withValues(alpha: 0.75),
              FlixieColors.surface.withValues(alpha: 0.95),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: FlixieColors.primary.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 150,
                height: 188,
                child: posterUrl == null
                    ? Container(
                        color: FlixieColors.tabBarBorder,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.movie_outlined,
                          color: FlixieColors.medium,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: FlixieColors.tabBarBorder,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.movie_outlined,
                            color: FlixieColors.medium,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.light,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.15,
              ),
            ),
            if ((movie.year ?? 0) > 0 ||
                (movie.releaseDate ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                movie.year?.toString() ?? _yearFromDate(movie.releaseDate),
                style: const TextStyle(
                  color: FlixieColors.medium,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (variant == InsightMovieCardVariant.mostDiscussed &&
                (movie.latestDiscussionSnippet ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                movie.latestDiscussionSnippet!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FlixieColors.medium,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (variant == InsightMovieCardVariant.mostWatched &&
                movie.watchers.isNotEmpty) ...[
              const SizedBox(height: 7),
              _WatcherAvatarStack(watchers: movie.watchers),
            ],
          ],
        ),
      ),
    );
  }
}

class InsightReviewCard extends StatelessWidget {
  const InsightReviewCard({
    super.key,
    required this.review,
  });

  final GroupInsightReview review;

  static const _posterBase = 'https://image.tmdb.org/t/p/w185';

  @override
  Widget build(BuildContext context) {
    final posterUrl = _resolvePosterUrl(review.moviePosterPath, _posterBase);

    return InkWell(
      onTap: review.userId != null && review.userId!.isNotEmpty
          ? () => context.push('/friends/${review.userId}')
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: _glassDecoration(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AvatarBubble(
                  name: review.reviewerName,
                  imageUrl: review.reviewerAvatarUrl,
                  size: 34,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.reviewerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (review.reviewerUsername.isNotEmpty)
                        Text(
                          '@${review.reviewerUsername}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  _relativeDate(review.createdAt),
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 50,
                    height: 72,
                    child: posterUrl == null
                        ? Container(
                            color: FlixieColors.tabBarBorder,
                            alignment: Alignment.center,
                            child: const Icon(Icons.movie_outlined,
                                size: 18, color: FlixieColors.medium),
                          )
                        : CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: FlixieColors.tabBarBorder,
                              alignment: Alignment.center,
                              child: const Icon(Icons.movie_outlined,
                                  size: 18, color: FlixieColors.medium),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: review.movieId != null
                            ? () => context.push('/movies/${review.movieId}')
                            : null,
                        child: Text(
                          review.movieTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.light,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: FlixieColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: FlixieColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          '${review.rating.toStringAsFixed(1)}/10',
                          style: const TextStyle(
                            color: FlixieColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (review.snippet.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                review.snippet.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FlixieColors.light,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InsightMemberCard extends StatelessWidget {
  const InsightMemberCard({
    super.key,
    required this.member,
  });

  final GroupInsightMember member;

  @override
  Widget build(BuildContext context) {
    final rankValue = member.rank > 0 ? member.rank : null;
    final displayHandle = member.username.trim().isNotEmpty
        ? '@${member.username.trim()}'
        : (member.name.trim().isNotEmpty ? member.name.trim() : '@user');
    final avatarSeed =
        member.username.trim().isNotEmpty ? member.username : member.name;

    return InkWell(
      onTap: member.id.isNotEmpty
          ? () => context.push('/friends/${member.id}')
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: _glassDecoration(),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (rankValue != null)
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FlixieColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: FlixieColors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '$rankValue',
                  style: const TextStyle(
                    color: FlixieColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            if (rankValue != null) const SizedBox(width: 10),
            _AvatarBubble(
              name: avatarSeed,
              imageUrl: member.avatarUrl,
              size: 38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayHandle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${member.activityCount}',
                  style: const TextStyle(
                    color: FlixieColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'activities',
                  style: TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 11,
                  ),
                ),
                if ((member.badge ?? '').isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: FlixieColors.tertiary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: FlixieColors.tertiary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      member.badge!,
                      style: const TextStyle(
                        color: FlixieColors.tertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HorizontalPosterRail extends StatelessWidget {
  const HorizontalPosterRail({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

class _WatcherAvatarStack extends StatelessWidget {
  const _WatcherAvatarStack({required this.watchers});

  final List<GroupInsightUser> watchers;

  @override
  Widget build(BuildContext context) {
    final shown = watchers.take(4).toList(growable: false);
    return SizedBox(
      height: 22,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 14,
              child: _AvatarBubble(
                name: shown[i].username,
                imageUrl: shown[i].avatarUrl,
                size: 22,
              ),
            ),
          if (watchers.length > shown.length)
            Positioned(
              left: shown.length * 14,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FlixieColors.surface,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: FlixieColors.tabBarBorder, width: 1.2),
                ),
                child: Text(
                  '+${watchers.length - shown.length}',
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({
    required this.name,
    required this.imageUrl,
    this.size = 24,
  });

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final isHttp = (imageUrl ?? '').startsWith('http');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: FlixieColors.tabBarBorder, width: 1),
      ),
      child: ClipOval(
        child: isHttp
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _initialAvatar(initial),
              )
            : _initialAvatar(initial),
      ),
    );
  }

  Widget _initialAvatar(String initial) {
    return Container(
      color: FlixieColors.primary.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: FlixieColors.light,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}

class _InsightsLoadingState extends StatelessWidget {
  const _InsightsLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        for (var i = 0; i < 3; i++) ...[
          const SkeletonBox(width: 180, height: 18, borderRadius: 6),
          const SizedBox(height: 10),
          SizedBox(
            height: 340,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => Container(
                width: 170,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FlixieColors.tabBarBackgroundFocused,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: FlixieColors.tabBarBorder),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 150, height: 188, borderRadius: 12),
                    SizedBox(height: 8),
                    SkeletonBox(width: double.infinity, height: 13),
                    SizedBox(height: 6),
                    SkeletonBox(width: 100, height: 10),
                    SizedBox(height: 6),
                    SkeletonBox(width: 120, height: 11),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

BoxDecoration _glassDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        FlixieColors.surfaceElevated.withValues(alpha: 0.72),
        FlixieColors.surface.withValues(alpha: 0.94),
      ],
    ),
    boxShadow: [
      BoxShadow(
        color: FlixieColors.primary.withValues(alpha: 0.1),
        blurRadius: 14,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

String _yearFromDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final parsed = DateTime.tryParse(iso);
  return parsed == null ? '' : '${parsed.year}';
}

String _relativeDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${dt.day}/${dt.month}/${dt.year}';
}

String? _resolvePosterUrl(String? poster, String baseUrl) {
  if (poster == null) return null;
  final value = poster.trim();
  if (value.isEmpty || value == 'null' || value == 'undefined') return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('//')) return 'https:$value';
  if (value.startsWith('/')) return '$baseUrl$value';
  return '$baseUrl/$value';
}
