import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/friend_recommendation.dart';
import 'package:flixie_app/models/friend_summary.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Compact cinematic card showing a high-level summary of how the current
/// user's friends have interacted with a movie.
///
/// States:
///   - loading  : shimmer-like placeholder
///   - error    : compact retry button
///   - empty    : "No friend summary yet" message
///   - data     : stat tiles + highest / lowest rated friend
class FriendSummarySection extends StatelessWidget {
  const FriendSummarySection({
    super.key,
    required this.isLoading,
    this.data,
    this.error,
    this.onRetry,
    this.recommendationLoading = false,
    this.recommendationData,
    this.recommendationError,
    this.onRecommendationRetry,
    this.onSeeAllRecommendations,
  });

  final bool isLoading;
  final FriendSummaryResponse? data;
  final Object? error;
  final VoidCallback? onRetry;
  final bool recommendationLoading;
  final FriendRecommendationResponse? recommendationData;
  final Object? recommendationError;
  final VoidCallback? onRecommendationRetry;
  final VoidCallback? onSeeAllRecommendations;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Friend Summary',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: FlixieColors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        _buildCard(context),
      ],
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlixieColors.primary.withValues(alpha: 0.14),
            FlixieColors.surfaceElevated.withValues(alpha: 0.72),
            FlixieColors.surface.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FlixieColors.primary.withValues(alpha: 0.28),
        ),
      ),
      child: isLoading
          ? _buildLoading()
          : error != null && data == null
              ? _buildError(context)
              : _hasNoFriendData
                  ? _buildEmpty()
                  : _buildContent(context, data),
    );
  }

  bool get _hasNoFriendData {
    final hasSummary = data != null && data!.friendCount > 0;
    final hasRecommendation =
        recommendationData != null && recommendationData!.friendCount > 0;
    return !hasSummary && !hasRecommendation && !recommendationLoading;
  }

  // ---- Loading --------------------------------------------------------------

  Widget _buildLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _shimmer(width: 140, height: 16),
        const SizedBox(height: 12),
        _shimmer(width: 80, height: 40),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _shimmer(width: double.infinity, height: 56)),
            const SizedBox(width: 8),
            Expanded(child: _shimmer(width: double.infinity, height: 56)),
            const SizedBox(width: 8),
            Expanded(child: _shimmer(width: double.infinity, height: 56)),
          ],
        ),
        const SizedBox(height: 14),
        _shimmer(width: double.infinity, height: 44),
        const SizedBox(height: 8),
        _shimmer(width: double.infinity, height: 44),
      ],
    );
  }

  Widget _shimmer({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  // ---- Error ----------------------------------------------------------------

  Widget _buildError(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: FlixieColors.medium, size: 18),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Could not load friend summary.',
            style: TextStyle(color: FlixieColors.medium, fontSize: 13),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: FlixieColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }

  // ---- Empty ----------------------------------------------------------------

  Widget _buildEmpty() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No friend summary yet.',
          style: TextStyle(
            color: FlixieColors.light,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Your friends have not interacted with this movie yet.',
          style: TextStyle(color: FlixieColors.medium, fontSize: 13),
        ),
      ],
    );
  }

  // ---- Content -------------------------------------------------------------

  Widget _buildContent(BuildContext context, FriendSummaryResponse? data) {
    final ratingGroups =
        data == null ? const <_RatingGroup>[] : _ratingGroups(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRecommendationBlock(context),
        if (data != null && data.friendCount > 0) ...[
          const SizedBox(height: 16),
          const Divider(
              height: 1, thickness: 1, color: FlixieColors.tabBarBorder),
          const SizedBox(height: 16),
        ],
        if (data == null || data.friendCount == 0)
          const SizedBox.shrink()
        else ...[
          // Friend count + average rating row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data.friendCount} ${data.friendCount == 1 ? 'friend' : 'friends'} interacted',
                    style: const TextStyle(
                      color: FlixieColors.light,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (data.averageRating != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          data.averageRating!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: FlixieColors.primary,
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            letterSpacing: -1,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6, left: 4),
                          child: Text(
                            '/ 10',
                            style: TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Average Rating',
                      style: TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              if (data.averageRating != null) ...[
                const Spacer(),
                const Icon(Icons.star_rounded,
                    color: FlixieColors.warning, size: 36),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Stat tiles row
          Row(
            children: [
              _StatTile(
                icon: Icons.check_circle_outline_rounded,
                label: 'Watched',
                value: '${data.watchedCount}',
                color: FlixieColors.success,
              ),
              const SizedBox(width: 8),
              _StatTile(
                icon: Icons.favorite_border_rounded,
                label: 'Favourited',
                value: '${data.favouriteCount}',
                color: FlixieColors.danger,
              ),
              const SizedBox(width: 8),
              _StatTile(
                icon: Icons.bookmark_border_rounded,
                label: 'Watchlisted',
                value: '${data.watchlistCount}',
                color: FlixieColors.warning,
              ),
            ],
          ),
          // Highest / lowest rated
          if (ratingGroups.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(
                height: 1, thickness: 1, color: FlixieColors.tabBarBorder),
            const SizedBox(height: 12),
            ...ratingGroups.map((group) {
              final isHighest = group.kind == _RatingGroupKind.highest;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: group == ratingGroups.last ? 0 : 8,
                ),
                child: _RatedFriendRow(
                  label: group.label,
                  names: _formatNames(group.names),
                  rating: group.rating,
                  accentColor:
                      isHighest ? FlixieColors.success : FlixieColors.tertiary,
                  icon: isHighest
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  onTap: group.userIds.length == 1
                      ? () => context.push('/friends/${group.userIds.first}')
                      : null,
                ),
              );
            }),
          ],
        ],
      ],
    );
  }

  List<_RatingGroup> _ratingGroups(FriendSummaryResponse data) {
    final highestItems = data.highestRatings.isNotEmpty
        ? data.highestRatings
        : [
            if (data.highestRating != null) data.highestRating!,
          ];
    final lowestItems = data.lowestRatings.isNotEmpty
        ? data.lowestRatings
        : [
            if (data.lowestRating != null) data.lowestRating!,
          ];

    final groups = <_RatingGroup>[
      if (highestItems.isNotEmpty)
        _ratingGroupFromItems(
          kind: _RatingGroupKind.highest,
          label: 'Highest Rating',
          items: highestItems,
        ),
      if (lowestItems.isNotEmpty)
        _ratingGroupFromItems(
          kind: _RatingGroupKind.lowest,
          label: 'Lowest Rating',
          items: lowestItems,
        ),
    ];

    if (groups.length == 2 &&
        groups.first.rating == groups.last.rating &&
        groups.first.userIds.join('|') == groups.last.userIds.join('|')) {
      return [
        _RatingGroup(
          kind: _RatingGroupKind.highest,
          label: 'Friend Rating',
          rating: groups.first.rating,
          names: groups.first.names,
          userIds: groups.first.userIds,
        ),
      ];
    }
    return groups;
  }

  _RatingGroup _ratingGroupFromItems({
    required _RatingGroupKind kind,
    required String label,
    required List<FriendSummaryRating> items,
  }) {
    return _RatingGroup(
      kind: kind,
      label: label,
      rating: items.first.rating,
      names: items.map(_ratingDisplayName).toList(),
      userIds: items.map((item) => item.userId).toList(),
    );
  }

  String _ratingDisplayName(FriendSummaryRating item) {
    if (item.username.trim().isNotEmpty) return item.username;
    return item.displayName?.trim().isNotEmpty == true
        ? item.displayName!.trim()
        : 'Unknown';
  }

  String _formatNames(List<String> names) {
    if (names.isEmpty) return 'Unknown';
    if (names.length == 1) return names.single;
    if (names.length == 2) return '${names.first} and ${names.last}';
    return '${names.take(names.length - 1).join(', ')} and ${names.last}';
  }

  Widget _buildRecommendationBlock(BuildContext context) {
    if (recommendationLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmer(width: 120, height: 38),
          const SizedBox(height: 8),
          _shimmer(width: 220, height: 14),
        ],
      );
    }

    if (recommendationError != null && recommendationData == null) {
      return _buildRecommendationError(context);
    }

    final data = recommendationData;
    if (data == null || data.friendCount == 0) {
      return const Text(
        'No friend recommendations yet.',
        style: TextStyle(color: FlixieColors.medium, fontSize: 13),
      );
    }

    final watchedFriends = data.friends.where((friend) => friend.watched);
    final preview = watchedFriends.take(3).toList();
    final hasMore = watchedFriends.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${data.recommendPercent}%',
              style: const TextStyle(
                color: FlixieColors.primary,
                fontSize: 42,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text(
                  'recommend this',
                  style: TextStyle(
                    color: FlixieColors.light,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (data.averageFriendRating != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.star_rounded,
                  color: FlixieColors.warning, size: 14),
              const SizedBox(width: 4),
              Text(
                'Avg friend rating: ${data.averageFriendRating!.toStringAsFixed(1)}',
                style:
                    const TextStyle(color: FlixieColors.medium, fontSize: 12),
              ),
            ],
          ),
        ],
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...preview.map(
            (friend) => _FriendRecommendRow(
              item: friend,
              onTap: () => context.push('/friends/${friend.userId}'),
            ),
          ),
          if (hasMore && onSeeAllRecommendations != null) ...[
            const SizedBox(height: 2),
            GestureDetector(
              onTap: onSeeAllRecommendations,
              child: Row(
                children: [
                  Text(
                    'See all ${watchedFriends.length} friends',
                    style: const TextStyle(
                      color: FlixieColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      color: FlixieColors.primary, size: 16),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildRecommendationError(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: FlixieColors.medium, size: 18),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Could not load friend recommendations.',
            style: TextStyle(color: FlixieColors.medium, fontSize: 13),
          ),
        ),
        if (onRecommendationRetry != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRecommendationRetry,
            style: TextButton.styleFrom(
              foregroundColor: FlixieColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stat tile
// ---------------------------------------------------------------------------

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recommendation preview row
// ---------------------------------------------------------------------------

class _FriendRecommendRow extends StatelessWidget {
  const _FriendRecommendRow({
    required this.item,
    required this.onTap,
  });

  final FriendRecommendationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = item.username;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: FlixieColors.primary.withValues(alpha: 0.18),
              backgroundImage:
                  item.avatarUrl != null ? NetworkImage(item.avatarUrl!) : null,
              child: item.avatarUrl == null
                  ? Text(
                      initial,
                      style: const TextStyle(
                        color: FlixieColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.rating != null) _StarRating(rating: item.rating!),
          ],
        ),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final stars = (rating / 2).round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < stars ? Icons.star_rounded : Icons.star_border_rounded,
          color: index < stars ? FlixieColors.warning : FlixieColors.medium,
          size: 14,
        );
      }),
    );
  }
}

enum _RatingGroupKind { highest, lowest }

class _RatingGroup {
  const _RatingGroup({
    required this.kind,
    required this.label,
    required this.rating,
    required this.names,
    required this.userIds,
  });

  final _RatingGroupKind kind;
  final String label;
  final double rating;
  final List<String> names;
  final List<String> userIds;
}

// ---------------------------------------------------------------------------
// Rated friend row
// ---------------------------------------------------------------------------

class _RatedFriendRow extends StatelessWidget {
  const _RatedFriendRow({
    required this.label,
    required this.names,
    required this.rating,
    required this.accentColor,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String names;
  final double rating;
  final Color accentColor;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial = names.isNotEmpty ? names[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    names,
                    style: const TextStyle(
                      color: FlixieColors.light,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: accentColor, size: 14),
                const SizedBox(width: 3),
                Text(
                  '${rating.toStringAsFixed(0)}/10',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
