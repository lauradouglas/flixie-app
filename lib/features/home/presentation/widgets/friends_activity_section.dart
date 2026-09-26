import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'section_header.dart';

class FriendsActivitySection extends StatelessWidget {
  const FriendsActivitySection(
      {super.key,
      required this.activity,
      required this.expanded,
      required this.onExpand});
  final List<ActivityListItem> activity;
  final bool expanded;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) return const SizedBox.shrink();
    final previewCount = expanded ? 8 : 3;
    final items = activity.take(previewCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Friends’ activity',
          onSeeAll: () => context.push('/friends-activity'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (final item in items) ...[
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: ProfileAvatarView(
                        avatar: item.avatar,
                        profileBadges: item.profileBadges,
                        fallbackText: item.username.isEmpty
                            ? '?'
                            : item.username[0].toUpperCase(),
                        fallbackColor: context.colors.surfaceElevated,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(item.username,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
                ActivityTile(
                  item: item,
                  compact: true,
                  detailSource: DetailSource.friendActivity,
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        if (activity.length > 3) ...[
          if (!expanded)
            Center(
              child: TextButton.icon(
                onPressed: onExpand,
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.primaryText,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                label: Text(
                  'Show ${(activity.length - 3).clamp(0, 5)} more',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}
