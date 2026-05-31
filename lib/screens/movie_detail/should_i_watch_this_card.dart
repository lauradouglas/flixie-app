import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/friend_recommendation.dart';
import '../../theme/app_theme.dart';

/// Compact cinematic card shown on the Movie Detail page.
///
/// States:
///   - loading  : shows a shimmer-like placeholder
///   - error    : compact retry button
///   - empty    : "No friend recommendations yet" message
///   - data     : recommendation % + up to 3 friend rows
class ShouldIWatchThisCard extends StatelessWidget {
  const ShouldIWatchThisCard({
    super.key,
    required this.isLoading,
    this.data,
    this.error,
    this.onRetry,
    this.onSeeAll,
  });

  final bool isLoading;
  final FriendRecommendationResponse? data;
  final Object? error;
  final VoidCallback? onRetry;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Should I Watch This?',
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
              : data == null || data!.friendCount == 0
                  ? _buildEmpty()
                  : _buildContent(context, data!),
    );
  }

  Widget _buildLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _shimmer(width: 80, height: 36),
        const SizedBox(height: 6),
        _shimmer(width: 200, height: 14),
        const SizedBox(height: 16),
        _shimmer(width: double.infinity, height: 42),
        const SizedBox(height: 8),
        _shimmer(width: double.infinity, height: 42),
        const SizedBox(height: 8),
        _shimmer(width: double.infinity, height: 42),
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

  Widget _buildError(BuildContext context) {
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

  Widget _buildEmpty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'No friend recommendations yet.',
          style: TextStyle(
            color: FlixieColors.light,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Be the first to rate it.',
          style: TextStyle(color: FlixieColors.medium, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildContent(
      BuildContext context, FriendRecommendationResponse data) {
    final watchedFriends = data.friends.where((f) => f.watched).toList();
    final preview = watchedFriends.take(3).toList();
    final hasMore = watchedFriends.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recommendation percentage
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
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'of your friends recommend this',
          style: TextStyle(
            color: FlixieColors.light,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (data.averageFriendRating != null) ...[
          const SizedBox(height: 4),
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
        const SizedBox(height: 14),
        const Divider(
            height: 1, thickness: 1, color: FlixieColors.tabBarBorder),
        const SizedBox(height: 12),
        ...preview.map((f) => _FriendRecommendRow(
              item: f,
              onTap: () => context.push('/friends/${f.userId}'),
            )),
        if (hasMore) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onSeeAll,
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
    );
  }
}

class _FriendRecommendRow extends StatelessWidget {
  const _FriendRecommendRow({
    required this.item,
    required this.onTap,
  });

  final FriendRecommendationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = item.displayName ?? item.username;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: FlixieColors.primary.withValues(alpha: 0.18),
              backgroundImage: item.avatarUrl != null
                  ? CachedNetworkImageProvider(item.avatarUrl!)
                  : null,
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
            // Name
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
            // Star rating
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
    // Convert a 0–10 rating to 0–5 stars.
    final stars = (rating / 2).round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < stars ? Icons.star_rounded : Icons.star_border_rounded,
          color: i < stars ? FlixieColors.warning : FlixieColors.medium,
          size: 14,
        );
      }),
    );
  }
}
