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

  List<GroupInsightMovie> get _allInsightMovies => [
        ..._insights.mostWatchedThisMonth,
        ..._insights.mostDiscussedMovies,
        ..._insights.highestRatedMovies,
      ];

  List<MapEntry<String, int>> get _topGenres {
    final counts = <String, int>{};
    for (final movie in _allInsightMovies) {
      for (final genre in movie.genres) {
        counts[genre] = (counts[genre] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(6).toList(growable: false);
  }

  List<GroupInsightMovie> get _mostDivisiveMovies {
    final movies = _allInsightMovies
        .where((movie) => movie.ratingSpread > 0)
        .toList(growable: false)
      ..sort((a, b) => b.ratingSpread.compareTo(a.ratingSpread));
    return movies.take(8).toList(growable: false);
  }

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
          InsightsPulseStrip(insights: _insights),
          const SizedBox(height: 18),
          InsightSignalsPanel(insights: _insights),
          const SizedBox(height: 22),
          if (_topGenres.isNotEmpty) ...[
            GenreTasteCloud(genres: _topGenres),
            const SizedBox(height: 22),
          ],
          if (_insights.mostWatchedThisMonth.isNotEmpty) ...[
            InsightSectionHeader(
              title: 'Most Watched This Month',
              icon: Icons.local_fire_department_outlined,
              meta: _countLabel(
                _insights.mostWatchedThisMonth.fold<int>(
                  0,
                  (total, movie) => total + movie.watchCount,
                ),
                'watch',
              ),
            ),
            const SizedBox(height: 10),
            HorizontalPosterRail(
              children: _insights.mostWatchedThisMonth
                  .asMap()
                  .entries
                  .map(
                    (entry) => InsightMovieCard(
                      movie: entry.value,
                      variant: InsightMovieCardVariant.mostWatched,
                      rank: entry.key + 1,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 22),
          ],
          if (_mostDivisiveMovies.isNotEmpty) ...[
            InsightSectionHeader(
              title: 'Most Divisive',
              icon: Icons.call_split_outlined,
              meta:
                  '${_mostDivisiveMovies.first.ratingSpread.toStringAsFixed(1)} spread',
            ),
            const SizedBox(height: 10),
            HorizontalPosterRail(
              children: _mostDivisiveMovies
                  .asMap()
                  .entries
                  .map(
                    (entry) => InsightMovieCard(
                      movie: entry.value,
                      variant: InsightMovieCardVariant.mostDivisive,
                      rank: entry.key + 1,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 22),
          ],
          if (_insights.mostDiscussedMovies.isNotEmpty) ...[
            InsightSectionHeader(
              title: 'Most Discussed Movies',
              icon: Icons.forum_outlined,
              meta: _countLabel(
                _insights.mostDiscussedMovies.fold<int>(
                  0,
                  (total, movie) => total + movie.discussionCount,
                ),
                'message',
              ),
            ),
            const SizedBox(height: 10),
            HorizontalPosterRail(
              children: _insights.mostDiscussedMovies
                  .asMap()
                  .entries
                  .map(
                    (entry) => InsightMovieCard(
                      movie: entry.value,
                      variant: InsightMovieCardVariant.mostDiscussed,
                      rank: entry.key + 1,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 22),
          ],
          if (_insights.highestRatedMovies.isNotEmpty) ...[
            InsightSectionHeader(
              title: 'Highest Rated Movies',
              icon: Icons.star_rounded,
              meta:
                  'Top ${_insights.highestRatedMovies.first.averageRating.toStringAsFixed(1)}',
            ),
            const SizedBox(height: 10),
            HorizontalPosterRail(
              children: _insights.highestRatedMovies
                  .asMap()
                  .entries
                  .map(
                    (entry) => InsightMovieCard(
                      movie: entry.value,
                      variant: InsightMovieCardVariant.highestRated,
                      rank: entry.key + 1,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 22),
          ],
          if (_insights.recentReviews.isNotEmpty) ...[
            const InsightSectionHeader(
              title: 'Recent Reviews',
              icon: Icons.rate_review_outlined,
            ),
            const SizedBox(height: 10),
            ..._insights.recentReviews.map((review) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InsightReviewCard(review: review),
                )),
            const SizedBox(height: 8),
          ],
          if (_insights.mostActiveMembers.isNotEmpty) ...[
            const InsightSectionHeader(
              title: 'Most Active Members',
              icon: Icons.bolt_outlined,
            ),
            const SizedBox(height: 10),
            ..._insights.mostActiveMembers.map((member) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InsightMemberCard(member: member),
                )),
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
    this.meta,
  });

  final String title;
  final IconData icon;
  final String? meta;

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
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        if ((meta ?? '').isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: FlixieColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: FlixieColors.primary.withValues(alpha: 0.28),
              ),
            ),
            child: Text(
              meta!,
              style: const TextStyle(
                color: FlixieColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class InsightsPulseStrip extends StatelessWidget {
  const InsightsPulseStrip({
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
    final ratedMovies = insights.highestRatedMovies
        .where((movie) => movie.ratingCount > 0 && movie.averageRating > 0)
        .toList(growable: false);
    final topRating = ratedMovies.isEmpty
        ? '-'
        : ratedMovies.first.averageRating.toStringAsFixed(1);

    return Row(
      children: [
        Expanded(
          child: _PulseTile(
            label: 'Watches',
            value: '$monthlyWatches',
            icon: Icons.visibility_outlined,
            color: FlixieColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PulseTile(
            label: 'Top score',
            value: topRating,
            icon: Icons.star_rounded,
            color: FlixieColors.warning,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PulseTile(
            label: 'Chat',
            value: '$discussionCount',
            icon: Icons.forum_outlined,
            color: FlixieColors.tertiary,
          ),
        ),
      ],
    );
  }
}

class _PulseTile extends StatelessWidget {
  const _PulseTile({
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: FlixieColors.surfaceElevated.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class InsightSignalsPanel extends StatelessWidget {
  const InsightSignalsPanel({
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
      _SignalData(
        label: 'Repeat watch',
        movie: topWatched,
        value: topWatched == null
            ? '-'
            : _countLabel(topWatched.watchCount, 'watch'),
        icon: Icons.replay_outlined,
        color: FlixieColors.primary,
      ),
      _SignalData(
        label: 'Crowd favorite',
        movie: topRated,
        value: topRated == null
            ? '-'
            : '${topRated.averageRating.toStringAsFixed(1)}/10',
        icon: Icons.auto_awesome_outlined,
        color: FlixieColors.warning,
      ),
      _SignalData(
        label: 'Conversation starter',
        movie: topDiscussed,
        value: topDiscussed == null
            ? '-'
            : _countLabel(topDiscussed.discussionCount, 'message'),
        icon: Icons.question_answer_outlined,
        color: FlixieColors.tertiary,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const InsightSectionHeader(
          title: 'Group Signals',
          icon: Icons.radar_outlined,
        ),
        const SizedBox(height: 10),
        Column(
          children: signals
              .map(
                (signal) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SignalTile(signal: signal),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class GenreTasteCloud extends StatelessWidget {
  const GenreTasteCloud({
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
        const InsightSectionHeader(
          title: 'Group Taste',
          icon: Icons.category_outlined,
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: _glassDecoration(),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: genres.map((genre) {
              final isTop = genre.value == topCount;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: (isTop ? FlixieColors.primary : FlixieColors.tertiary)
                      .withValues(alpha: isTop ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        (isTop ? FlixieColors.primary : FlixieColors.tertiary)
                            .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isTop) ...[
                      const Icon(Icons.auto_awesome,
                          color: FlixieColors.primary, size: 14),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      genre.key,
                      style: TextStyle(
                        color: isTop
                            ? FlixieColors.primary
                            : FlixieColors.tertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${genre.value}',
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _SignalData {
  const _SignalData({
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

class _SignalTile extends StatelessWidget {
  const _SignalTile({required this.signal});

  final _SignalData signal;

  @override
  Widget build(BuildContext context) {
    final movie = signal.movie;
    return InkWell(
      onTap: movie?.movieId != null
          ? () => context.push('/movies/${movie!.movieId}')
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated.withValues(alpha: 0.62),
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
                    style: const TextStyle(
                      color: FlixieColors.light,
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
              style: const TextStyle(
                color: FlixieColors.medium,
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

class InsightMovieCard extends StatelessWidget {
  const InsightMovieCard({
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
      InsightMovieCardVariant.highestRated =>
        '${movie.averageRating.toStringAsFixed(1)} group rating • ${movie.ratingCount} ${movie.ratingCount == 1 ? 'rating' : 'ratings'}',
      InsightMovieCardVariant.mostDivisive =>
        '${movie.ratingSpread.toStringAsFixed(1)} rating spread',
    };

    return InkWell(
      onTap: movie.movieId != null
          ? () => context.push('/movies/${movie.movieId}')
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
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: FlixieColors.primary.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Text(
                      '#$rank',
                      style: const TextStyle(
                        color: FlixieColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
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
                    style: const TextStyle(
                      color: FlixieColors.light,
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
                        _MiniMetaPill(
                          label: movie.year?.toString() ??
                              _yearFromDate(movie.releaseDate),
                          icon: Icons.calendar_today_outlined,
                          color: FlixieColors.medium,
                        ),
                      _MiniMetaPill(
                        label: subtitle,
                        icon: _variantIcon(variant),
                        color: _variantColor(variant),
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
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 11,
                        height: 1.25,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (variant == InsightMovieCardVariant.mostWatched &&
                      movie.watchers.isNotEmpty)
                    _WatcherAvatarStack(watchers: movie.watchers)
                  else
                    Text(
                      _variantFooter(variant, movie),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FlixieColors.medium,
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

class _MiniMetaPill extends StatelessWidget {
  const _MiniMetaPill({
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 158),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
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
            height: 146,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => Container(
                width: 268,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FlixieColors.tabBarBackgroundFocused,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: FlixieColors.tabBarBorder),
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

Color _variantColor(InsightMovieCardVariant variant) {
  switch (variant) {
    case InsightMovieCardVariant.mostWatched:
      return FlixieColors.primary;
    case InsightMovieCardVariant.mostDiscussed:
      return FlixieColors.tertiary;
    case InsightMovieCardVariant.highestRated:
      return FlixieColors.warning;
    case InsightMovieCardVariant.mostDivisive:
      return FlixieColors.danger;
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
