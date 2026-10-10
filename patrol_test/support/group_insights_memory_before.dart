// Frozen test-only pre-cleanup reference. Original SHA-256: 3f98078f6b4c0c86f15956c6733ba9ccaf353cf573ffb23c53cae16cbea0971d
import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';

import 'package:flixie_app/models/group_insights.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

class BeforeGroupInsightsTab extends StatefulWidget {
  const BeforeGroupInsightsTab({
    super.key,
    required this.groupId,
  });

  final String groupId;

  @override
  State<BeforeGroupInsightsTab> createState() => _MemoryBeforeGroupInsightsTabState();
}

class _MemoryBeforeGroupInsightsTabState extends State<BeforeGroupInsightsTab> {
  int _loadGeneration = 0;
  bool _loading = true;
  bool _allTime = false;
  String? _error;
  GroupInsightsResponse _insights = const GroupInsightsResponse();

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  @override
  void didUpdateWidget(covariant BeforeGroupInsightsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) _loadInsights();
  }

  Future<void> _loadInsights() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final insights = await GroupService.getGroupInsights(
        widget.groupId,
        timeWindow: _allTime ? 'all' : 'month',
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _insights = insights;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = 'Couldn\'t load group insights';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _MemoryBeforeInsightsLoadingState();

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insights_outlined,
                  color: context.colors.medium, size: 40),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: context.colors.light,
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
          children: [
            const SizedBox(height: 64),
            Icon(Icons.auto_graph_outlined,
                size: 52, color: context.colors.medium),
            const SizedBox(height: 16),
            Text(
              'No group insights yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.light,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Start watching, rating, reviewing, or discussing movies with this group.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.medium,
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
          _MemoryBeforeInsightsTimeToggle(
            allTime: _allTime,
            onChanged: (allTime) {
              if (_allTime == allTime) return;
              setState(() => _allTime = allTime);
              _loadInsights();
            },
          ),
          const SizedBox(height: 12),
          _MemoryBeforeInsightsPulseStrip(insights: _insights),
          const SizedBox(height: 18),
          if (_insights.mostWatchedThisMonth.isNotEmpty) ...[
            const _MemoryBeforeInsightSectionHeader(
              title: 'Highlights',
              icon: Icons.auto_awesome_rounded,
            ),
            const SizedBox(height: 10),
            _MemoryBeforeInsightHighlightCard(
              movie: _insights.mostWatchedThisMonth.first,
            ),
            const SizedBox(height: 22),
          ],
          if (_insights.recentReviews.isNotEmpty) ...[
            const _MemoryBeforeInsightSectionHeader(
              title: 'Recent Reviews',
              icon: Icons.rate_review_outlined,
            ),
            const SizedBox(height: 10),
            ..._insights.recentReviews.map((review) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MemoryBeforeInsightReviewCard(review: review),
                )),
            const SizedBox(height: 8),
          ],
          if (_insights.mostActiveMembers.isNotEmpty) ...[
            const _MemoryBeforeInsightSectionHeader(
              title: 'Top contributors',
              icon: Icons.bolt_outlined,
            ),
            const SizedBox(height: 10),
            ..._insights.mostActiveMembers.map((member) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MemoryBeforeInsightMemberCard(member: member),
                )),
          ],
        ],
      ),
    );
  }
}

class _MemoryBeforeInsightsTimeToggle extends StatelessWidget {
  const _MemoryBeforeInsightsTimeToggle({
    required this.allTime,
    required this.onChanged,
  });

  final bool allTime;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.tabBarBorder),
      ),
      child: Row(
        children: [
          _option(context, 'This month', false),
          _option(context, 'All time', true),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, String label, bool value) {
    final selected = allTime == value;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? FlixieColors.primary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: selected
                ? Border.all(
                    color: FlixieColors.primary.withValues(alpha: 0.48))
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? FlixieColors.primary : context.colors.medium,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoryBeforeInsightSectionHeader extends StatelessWidget {
  const _MemoryBeforeInsightSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.meta,
  });

  final String title;
  final IconData icon;
  final String? meta;

  @override
  Widget build(BuildContext context) =>
      FlixieSectionHeader(title: title, trailingLabel: meta);
}

class _MemoryBeforeInsightHighlightCard extends StatelessWidget {
  const _MemoryBeforeInsightHighlightCard({super.key, required this.movie});

  final GroupInsightMovie movie;

  @override
  Widget build(BuildContext context) {
    final posterUrl =
        _resolvePosterUrl(movie.posterPath, 'https://image.tmdb.org/t/p/w342');
    return InkWell(
      onTap: movie.movieId == null
          ? null
          : () => context.push(movieDetailPath(movie.movieId!)),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 188,
        padding: const EdgeInsets.all(12),
        decoration: _glassDecoration(context),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 118,
                height: double.infinity,
                child: posterUrl == null
                    ? Container(
                        color: context.colors.surfaceElevated,
                        child: Icon(Icons.movie_outlined,
                            color: context.colors.medium),
                      )
                    : CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: context.colors.surfaceElevated,
                          child: Icon(Icons.movie_outlined,
                              color: context.colors.medium),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 20,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const FlixiePill.label(label: Text('#1 in your group')),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 5,
                    children: [
                      Text('${movie.watchCount} watches',
                          style: TextStyle(
                              color: context.colors.light, fontSize: 11)),
                      Text('${movie.discussionCount} discussions',
                          style: TextStyle(
                              color: context.colors.light, fontSize: 11)),
                      if (movie.averageRating > 0 &&
                          !hideMovieRatings(context, movie.movieId))
                        Text('${movie.averageRating.toStringAsFixed(1)}/10',
                            style: TextStyle(
                                color: context.colors.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                    ],
                  ),
                  if (movie.watchers.isNotEmpty) ...[
                    const SizedBox(height: 11),
                    _MemoryBeforeWatcherAvatarStack(watchers: movie.watchers),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryBeforeInsightsPulseStrip extends StatelessWidget {
  const _MemoryBeforeInsightsPulseStrip({
    super.key,
    required this.insights,
  });

  final GroupInsightsResponse insights;

  @override
  Widget build(BuildContext context) {
    final monthlyWatches = insights.mostWatchedThisMonth.fold<int>(
      0,
      (total, movie) => total + movie.watchCount,
    );
    final discussionCount = insights.mostDiscussedMovies.fold<int>(
      0,
      (total, movie) => total + movie.discussionCount,
    );
    final ratingCount = insights.highestRatedMovies.fold<int>(
      0,
      (total, movie) => total + movie.ratingCount,
    );

    final tiles = [
      _MemoryBeforePulseTile(
        label: 'Watches',
        value: '$monthlyWatches',
        icon: Icons.visibility_outlined,
        color: FlixieColors.primary,
      ),
      _MemoryBeforePulseTile(
        label: 'Ratings',
        value: '$ratingCount',
        icon: Icons.star_rounded,
        color: context.colors.warning,
      ),
      _MemoryBeforePulseTile(
        label: 'Reviews',
        value: '${insights.recentReviews.length}',
        icon: Icons.rate_review_outlined,
        color: context.colors.tertiary,
      ),
      _MemoryBeforePulseTile(
        label: 'Messages',
        value: '$discussionCount',
        icon: Icons.forum_outlined,
        color: const Color(0xFF70A7FF),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: _glassDecoration(context),
      child: Row(
        children: [
          for (var index = 0; index < tiles.length; index++) ...[
            Expanded(child: tiles[index]),
            if (index != tiles.length - 1)
              SizedBox(
                height: 58,
                child: VerticalDivider(
                    width: 1, color: context.colors.tabBarBorder),
              ),
          ],
        ],
      ),
    );
  }
}

class _MemoryBeforePulseTile extends StatelessWidget {
  const _MemoryBeforePulseTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: context.colors.medium,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MemoryBeforeInsightSignalsPanel extends StatelessWidget {
  const _MemoryBeforeInsightSignalsPanel({
    super.key,
    required this.insights,
  });

  final GroupInsightsResponse insights;

  @override
  Widget build(BuildContext context) {
    final topWatched = insights.mostWatchedThisMonth.isEmpty
        ? null
        : insights.mostWatchedThisMonth.first;
    final topDiscussed = insights.mostDiscussedMovies.isEmpty
        ? null
        : insights.mostDiscussedMovies.first;
    final topRated = insights.highestRatedMovies.isEmpty
        ? null
        : insights.highestRatedMovies.first;

    final signals = [
      _MemoryBeforeSignalData(
        label: 'Repeat watch',
        movie: topWatched,
        value: topWatched == null
            ? '-'
            : _countLabel(topWatched.watchCount, 'watch'),
        icon: Icons.replay_outlined,
        color: FlixieColors.primary,
      ),
      _MemoryBeforeSignalData(
        label: 'Crowd favorite',
        movie: topRated,
        value: topRated == null
            ? '-'
            : hideMovieRatings(context, topRated.movieId)
                ? 'Rate to see score'
                : '${topRated.averageRating.toStringAsFixed(1)}/10',
        icon: Icons.auto_awesome_outlined,
        color: context.colors.warning,
      ),
      _MemoryBeforeSignalData(
        label: 'Conversation starter',
        movie: topDiscussed,
        value: topDiscussed == null
            ? '-'
            : _countLabel(topDiscussed.discussionCount, 'message'),
        icon: Icons.question_answer_outlined,
        color: context.colors.tertiary,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MemoryBeforeInsightSectionHeader(
          title: 'Group Signals',
          icon: Icons.radar_outlined,
        ),
        const SizedBox(height: 10),
        Column(
          children: signals
              .map(
                (signal) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MemoryBeforeSignalTile(signal: signal),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _MemoryBeforeGenreTasteCloud extends StatelessWidget {
  const _MemoryBeforeGenreTasteCloud({
    super.key,
    required this.genres,
  });

  final List<MapEntry<String, int>> genres;

  @override
  Widget build(BuildContext context) {
    final topCount = genres.isEmpty ? 1 : genres.first.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MemoryBeforeInsightSectionHeader(
          title: 'Group Taste',
          icon: Icons.category_outlined,
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: _glassDecoration(context),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: genres.map((genre) {
              final isTop = genre.value == topCount;
              return FlixiePill.label(
                  colorKey: genre.key,
                  label: Text('${genre.key}  ${genre.value}'),
                  avatar: isTop ? const Icon(Icons.auto_awesome) : null);
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _MemoryBeforeSignalData {
  const _MemoryBeforeSignalData({
    required this.label,
    required this.movie,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final GroupInsightMovie? movie;
  final String value;
  final IconData icon;
  final Color color;
}

class _MemoryBeforeSignalTile extends StatelessWidget {
  const _MemoryBeforeSignalTile({required this.signal});

  final _MemoryBeforeSignalData signal;

  @override
  Widget build(BuildContext context) {
    final movie = signal.movie;
    return InkWell(
      onTap: movie?.movieId != null
          ? () => context.push(movieDetailPath(movie!.movieId!))
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: signal.color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: signal.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: signal.color.withValues(alpha: 0.3)),
              ),
              child: Icon(signal.icon, color: signal.color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signal.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: signal.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    movie?.title ?? 'Waiting for more data',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.light,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              signal.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.medium,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum InsightMovieCardVariant {
  mostWatched,
  mostDiscussed,
  highestRated,
  mostDivisive,
}

class _MemoryBeforeInsightMovieCard extends StatelessWidget {
  const _MemoryBeforeInsightMovieCard({
    super.key,
    required this.movie,
    required this.variant,
    required this.rank,
  });

  final GroupInsightMovie movie;
  final InsightMovieCardVariant variant;
  final int rank;

  static const _posterBase = 'https://image.tmdb.org/t/p/w185';

  @override
  Widget build(BuildContext context) {
    final posterUrl = _resolvePosterUrl(movie.posterPath, _posterBase);
    final subtitle = switch (variant) {
      InsightMovieCardVariant.mostWatched =>
        '${movie.watchCount} ${movie.watchCount == 1 ? 'watch' : 'watches'}',
      InsightMovieCardVariant.mostDiscussed =>
        '${movie.discussionCount} ${movie.discussionCount == 1 ? 'message' : 'messages'}',
      InsightMovieCardVariant.highestRated => hideMovieRatings(
              context, movie.movieId)
          ? 'Rate to see scores'
          : '${movie.averageRating.toStringAsFixed(1)} group rating • ${movie.ratingCount} ${movie.ratingCount == 1 ? 'rating' : 'ratings'}',
      InsightMovieCardVariant.mostDivisive =>
        hideMovieRatings(context, movie.movieId)
            ? 'Rate to see scores'
            : '${movie.ratingSpread.toStringAsFixed(1)} rating spread',
    };

    return InkWell(
      onTap: movie.movieId != null
          ? () => context.push(movieDetailPath(movie.movieId!))
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 268,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.surfaceElevated.withValues(alpha: 0.75),
              context.colors.surface.withValues(alpha: 0.95),
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
        padding: const EdgeInsets.all(9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 74,
                    height: double.infinity,
                    child: posterUrl == null
                        ? Container(
                            color: context.colors.tabBarBorder,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.movie_outlined,
                              color: context.colors.medium,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: context.colors.tabBarBorder,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.movie_outlined,
                                color: context.colors.medium,
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: FlixiePill.label(label: Text('#$rank')),
                ),
              ],
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.light,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if ((movie.year ?? 0) > 0 ||
                          (movie.releaseDate ?? '').isNotEmpty)
                        _MemoryBeforeMiniMetaPill(
                          label: movie.year?.toString() ??
                              _yearFromDate(movie.releaseDate),
                          icon: Icons.calendar_today_outlined,
                          color: context.colors.medium,
                        ),
                      _MemoryBeforeMiniMetaPill(
                        label: subtitle,
                        icon: _variantIcon(variant),
                        color: _variantColor(context, variant),
                      ),
                    ],
                  ),
                  if (variant == InsightMovieCardVariant.mostDiscussed &&
                      (movie.latestDiscussionSnippet ?? '').isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      movie.latestDiscussionSnippet!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.medium,
                        fontSize: 11,
                        height: 1.25,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (variant == InsightMovieCardVariant.mostWatched &&
                      movie.watchers.isNotEmpty)
                    _MemoryBeforeWatcherAvatarStack(watchers: movie.watchers)
                  else
                    Text(
                      _variantFooter(variant, movie),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.medium,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryBeforeMiniMetaPill extends StatelessWidget {
  const _MemoryBeforeMiniMetaPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return FlixiePill.label(
        label: Text(label), avatar: Icon(icon, color: color));
  }
}

class _MemoryBeforeInsightReviewCard extends StatefulWidget {
  const _MemoryBeforeInsightReviewCard({
    super.key,
    required this.review,
  });

  final GroupInsightReview review;

  @override
  State<_MemoryBeforeInsightReviewCard> createState() => _MemoryBeforeInsightReviewCardState();
}

class _MemoryBeforeInsightReviewCardState extends State<_MemoryBeforeInsightReviewCard> {
  static const _posterBase = 'https://image.tmdb.org/t/p/w185';
  bool _spoilerRevealed = false;

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final posterUrl = _resolvePosterUrl(review.moviePosterPath, _posterBase);
    final handle = review.reviewerUsername.trim().isEmpty
        ? review.reviewerName
        : '@${review.reviewerUsername.trim()}';
    final profileAction = review.userId != null && review.userId!.isNotEmpty
        ? () => context.push('/friends/${review.userId}')
        : null;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: FlixieColors.primary.withValues(alpha: 0.18),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: review.movieId != null
                ? () => context.push(movieDetailPath(review.movieId!))
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 62,
                height: 92,
                child: posterUrl == null
                    ? Container(
                        color: context.colors.tabBarBorder,
                        alignment: Alignment.center,
                        child: Icon(Icons.movie_outlined,
                            size: 20, color: context.colors.medium),
                      )
                    : CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: context.colors.tabBarBorder,
                          alignment: Alignment.center,
                          child: Icon(Icons.movie_outlined,
                              size: 20, color: context.colors.medium),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: profileAction,
                      child: ProfileAvatarView(
                        avatar: review.reviewerAvatar,
                        fallbackText: review.reviewerName.isEmpty
                            ? '?'
                            : review.reviewerName[0].toUpperCase(),
                        fallbackColor: FlixieColors.primary,
                        size: 28,
                        profileBadges: review.reviewerProfileBadges,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: profileAction,
                        child: Text(
                          handle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.light,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      _relativeDate(review.createdAt),
                      style: TextStyle(
                        color: context.colors.medium,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                GestureDetector(
                  onTap: review.movieId != null
                      ? () => context.push(movieDetailPath(review.movieId!))
                      : null,
                  child: Text(
                    review.movieTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.light,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 16, color: Color(0xFFFFC34D)),
                    const SizedBox(width: 3),
                    Text(
                      hideMovieRatings(context, review.movieId,
                              ownerId: review.userId)
                          ? 'Rate to see score'
                          : '${review.rating.toStringAsFixed(1)}/10',
                      style: TextStyle(
                        color: context.colors.light,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    if (review.recommended != null) ...[
                      const SizedBox(width: 10),
                      Icon(
                        review.recommended!
                            ? Icons.thumb_up_alt_rounded
                            : Icons.thumb_down_alt_rounded,
                        size: 14,
                        color: review.recommended!
                            ? const Color(0xFF55D69E)
                            : context.colors.medium,
                      ),
                    ],
                    if (review.containsSpoilers) ...[
                      const Spacer(),
                      const Text(
                        'SPOILER',
                        style: TextStyle(
                          color: Color(0xFFFFC34D),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .7,
                        ),
                      ),
                    ],
                  ],
                ),
                if (review.snippet.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: review.containsSpoilers && !_spoilerRevealed
                        ? () => setState(() => _spoilerRevealed = true)
                        : null,
                    child: Text(
                      review.containsSpoilers && !_spoilerRevealed
                          ? 'Tap to reveal review'
                          : review.snippet.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: review.containsSpoilers && !_spoilerRevealed
                            ? FlixieColors.primary
                            : context.colors.medium,
                        height: 1.25,
                        fontSize: 12,
                        fontStyle: review.containsSpoilers && !_spoilerRevealed
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryBeforeInsightMemberCard extends StatelessWidget {
  const _MemoryBeforeInsightMemberCard({
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
        decoration: _glassDecoration(context),
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
            ProfileAvatarView(
              avatar: member.avatar,
              profileBadges: member.profileBadges,
              fallbackText: avatarSeed.trim().isEmpty
                  ? '?'
                  : avatarSeed.trim().characters.first,
              fallbackColor: FlixieColors.primary,
              size: 38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayHandle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.light,
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
                Text(
                  'activities',
                  style: TextStyle(
                    color: context.colors.medium,
                    fontSize: 11,
                  ),
                ),
                if ((member.badge ?? '').isNotEmpty)
                  FlixiePill.label(label: Text(member.badge!)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryBeforeHorizontalPosterRail extends StatelessWidget {
  const _MemoryBeforeHorizontalPosterRail({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 146,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

class _MemoryBeforeWatcherAvatarStack extends StatelessWidget {
  const _MemoryBeforeWatcherAvatarStack({required this.watchers});

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
              child: _MemoryBeforeAvatarBubble(
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
                  color: context.colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: context.colors.tabBarBorder, width: 1.2),
                ),
                child: Text(
                  '+${watchers.length - shown.length}',
                  style: TextStyle(
                    color: context.colors.medium,
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

class _MemoryBeforeAvatarBubble extends StatelessWidget {
  const _MemoryBeforeAvatarBubble({
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
        border: Border.all(color: context.colors.tabBarBorder, width: 1),
      ),
      child: ClipOval(
        child: isHttp
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _initialAvatar(context, initial),
              )
            : _initialAvatar(context, initial),
      ),
    );
  }

  Widget _initialAvatar(BuildContext context, String initial) {
    return Container(
      color: FlixieColors.primary.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: context.colors.light,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}

class _MemoryBeforeInsightsLoadingState extends StatelessWidget {
  const _MemoryBeforeInsightsLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        for (var i = 0; i < 3; i++) ...[
          const SkeletonBox(width: 180, height: 18, borderRadius: 6),
          const SizedBox(height: 10),
          SizedBox(
            height: 146,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => Container(
                width: 268,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.tabBarBackgroundFocused,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.tabBarBorder),
                ),
                child: const Row(
                  children: [
                    SkeletonBox(width: 74, height: 124, borderRadius: 10),
                    SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: double.infinity, height: 16),
                          SizedBox(height: 7),
                          SkeletonBox(width: 96, height: 18, borderRadius: 10),
                          SizedBox(height: 7),
                          SkeletonBox(width: 130, height: 18, borderRadius: 10),
                          Spacer(),
                          SkeletonBox(width: 90, height: 12),
                        ],
                      ),
                    ),
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

BoxDecoration _glassDecoration(BuildContext context) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        context.colors.surfaceElevated.withValues(alpha: 0.72),
        context.colors.surface.withValues(alpha: 0.94),
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

String _countLabel(int count, String singular) {
  return '$count ${count == 1 ? singular : '${singular}s'}';
}

IconData _variantIcon(InsightMovieCardVariant variant) {
  switch (variant) {
    case InsightMovieCardVariant.mostWatched:
      return Icons.visibility_outlined;
    case InsightMovieCardVariant.mostDiscussed:
      return Icons.forum_outlined;
    case InsightMovieCardVariant.highestRated:
      return Icons.star_rounded;
    case InsightMovieCardVariant.mostDivisive:
      return Icons.call_split_outlined;
  }
}

Color _variantColor(BuildContext context, InsightMovieCardVariant variant) {
  switch (variant) {
    case InsightMovieCardVariant.mostWatched:
      return FlixieColors.primary;
    case InsightMovieCardVariant.mostDiscussed:
      return context.colors.tertiary;
    case InsightMovieCardVariant.highestRated:
      return context.colors.warning;
    case InsightMovieCardVariant.mostDivisive:
      return context.colors.danger;
  }
}

String _variantFooter(
    InsightMovieCardVariant variant, GroupInsightMovie movie) {
  switch (variant) {
    case InsightMovieCardVariant.mostWatched:
      return movie.watchers.isEmpty ? 'No member detail yet' : '';
    case InsightMovieCardVariant.mostDiscussed:
      return movie.latestDiscussionSnippet == null
          ? 'Recent group conversation'
          : 'Latest discussion';
    case InsightMovieCardVariant.highestRated:
      return _countLabel(movie.ratingCount, 'rating');
    case InsightMovieCardVariant.mostDivisive:
      return 'Mixed reactions';
  }
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
