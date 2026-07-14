import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_avatar.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.group,
    this.memberCount,
    this.statusLabel,
  });

  final Group group;
  final int? memberCount;
  final String? statusLabel;

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
            GroupAvatar(group: group, radius: 26),
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
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (count != null)
                        _GroupInfoChip(
                          label:
                              '${_formatCount(count)} member${count == 1 ? '' : 's'}',
                          color: FlixieColors.primary,
                        ),
                      if (statusLabel != null && statusLabel!.isNotEmpty)
                        _GroupInfoChip(
                          label: statusLabel!,
                          color: statusLabel == 'Invite pending'
                              ? FlixieColors.warning
                              : FlixieColors.success,
                        ),
                    ],
                  ),
                  if (group.description != null &&
                      group.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      group.description!,
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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

class _GroupInfoChip extends StatelessWidget {
  const _GroupInfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
