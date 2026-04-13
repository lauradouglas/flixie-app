import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/group.dart';
import '../../theme/app_theme.dart';
import 'group_avatar.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.group, this.memberCount});

  final Group group;
  final int? memberCount;

  static String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}K';
    }
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    final count = memberCount ?? group.memberCount;
    return GestureDetector(
      onTap: () => context.push('/groups/${group.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlixieColors.tabBarBorder),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                GroupAvatar(group: group, radius: 26),
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: FlixieColors.success,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: FlixieColors.background, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      color: FlixieColors.light,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (count != null)
                    Text(
                      '${_formatCount(count)} MEMBER${count == 1 ? '' : 'S'}',
                      style: const TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  if (group.description != null &&
                      group.description!.isNotEmpty)
                    Text(
                      group.description!,
                      style: const TextStyle(
                          color: FlixieColors.medium, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: FlixieColors.medium),
          ],
        ),
      ),
    );
  }
}
