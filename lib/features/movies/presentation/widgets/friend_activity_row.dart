import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/movie_friend_activity.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class FriendActivityRow extends StatelessWidget {
  const FriendActivityRow({super.key, required this.activity});

  final MovieFriendActivity activity;

  @override
  Widget build(BuildContext context) {
    final hexCode = activity.iconColor?['hexCode'] as String?;
    Color avatarColor = FlixieColors.primary;
    if (hexCode != null) {
      final hex = hexCode.replaceFirst('#', '');
      final value = int.tryParse(
          hex.length == 6
              ? 'FF$hex'
              : hex.length == 8
                  ? hex
                  : 'FF$hex',
          radix: 16);
      if (value != null) avatarColor = Color(value);
    }

    final displayName = activity.username;
    final initial =
        activity.username.isNotEmpty ? activity.username[0].toUpperCase() : '?';

    final badges = <_ActivityBadge>[];
    if (activity.watched) {
      badges.add(const _ActivityBadge(
          icon: Icons.check_circle, label: 'Watched', color: Colors.green));
    }
    if (activity.onWatchlist) {
      badges.add(const _ActivityBadge(
          icon: Icons.bookmark, label: 'Watchlist', color: Colors.amber));
    }
    if (activity.favorited) {
      badges.add(const _ActivityBadge(
          icon: Icons.favorite, label: 'Favourite', color: Colors.red));
    }
    if (activity.rating != null) {
      badges.add(_ActivityBadge(
        icon: Icons.star_rounded,
        label: '${activity.rating}/10',
        color: FlixieColors.tertiary,
      ));
    }
    if (activity.reviewRecommended == true) {
      badges.add(const _ActivityBadge(
        icon: Icons.thumb_up_outlined,
        label: 'Recommends',
        color: FlixieColors.success,
      ));
    } else if (activity.reviewRecommended == false) {
      badges.add(const _ActivityBadge(
        icon: Icons.thumb_down_outlined,
        label: 'Not recommended',
        color: Colors.redAccent,
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FlixieColors.surfaceElevated.withValues(alpha: 0.62),
              FlixieColors.surface.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.push('/friends/${activity.userId}'),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: avatarColor.withValues(alpha: 0.25),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: avatarColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/friends/${activity.userId}'),
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FlixieColors.light,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: badges,
                    ),
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

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
