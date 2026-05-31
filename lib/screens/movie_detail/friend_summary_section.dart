import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/friend_summary.dart';
import '../../theme/app_theme.dart';

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
  });

  final bool isLoading;
  final FriendSummaryResponse? data;
  final Object? error;
  final VoidCallback? onRetry;

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
              : data == null || data!.friendCount == 0
                  ? _buildEmpty()
                  : _buildContent(context, data!),
    );
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

  Widget _buildContent(BuildContext context, FriendSummaryResponse data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        if (data.highestRating != null || data.lowestRating != null) ...[
          const SizedBox(height: 16),
          const Divider(
              height: 1, thickness: 1, color: FlixieColors.tabBarBorder),
          const SizedBox(height: 12),
          if (data.highestRating != null)
            _RatedFriendRow(
              label: 'Highest Rating',
              item: data.highestRating!,
              accentColor: FlixieColors.success,
              icon: Icons.arrow_upward_rounded,
              onTap: () =>
                  context.push('/friends/${data.highestRating!.userId}'),
            ),
          if (data.highestRating != null && data.lowestRating != null)
            const SizedBox(height: 8),
          if (data.lowestRating != null)
            _RatedFriendRow(
              label: 'Lowest Rating',
              item: data.lowestRating!,
              accentColor: FlixieColors.tertiary,
              icon: Icons.arrow_downward_rounded,
              onTap: () =>
                  context.push('/friends/${data.lowestRating!.userId}'),
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
// Rated friend row
// ---------------------------------------------------------------------------

class _RatedFriendRow extends StatelessWidget {
  const _RatedFriendRow({
    required this.label,
    required this.item,
    required this.accentColor,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final FriendSummaryRating item;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = item.displayName ?? item.username;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

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
                    displayName,
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
                  '${item.rating.toStringAsFixed(0)}/10',
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
