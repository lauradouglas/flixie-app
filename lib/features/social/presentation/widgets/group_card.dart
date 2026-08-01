import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_avatar.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.group,
    this.memberCount,
    this.members = const [],
    this.statusLabel,
    this.onTap,
  });

  final Group group;
  final int? memberCount;
  final List<GroupMember> members;
  final String? statusLabel;
  final VoidCallback? onTap;

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
      onTap: onTap ?? () => context.push('/groups/${group.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FlixieColors.tabBarBorder),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GroupAvatar(group: group, radius: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: FlixieColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const Icon(Icons.more_horiz_rounded,
                              color: FlixieColors.medium, size: 20),
                        ],
                      ),
                      if (count != null)
                        Text(
                          '${_formatCount(count)} member${count == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: FlixieColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (members.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        _MemberAvatars(members: members),
                      ],
                    ],
                  ),
                ),
                if (statusLabel != null && statusLabel!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 34),
                    child: _GroupInfoChip(
                      label: statusLabel!,
                      color: statusLabel == 'Invite pending'
                          ? FlixieColors.warning
                          : statusLabel == 'Community'
                              ? FlixieColors.medium
                              : FlixieColors.success,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: FlixieColors.tabBarBorder),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.description?.trim().isNotEmpty == true
                        ? group.description!.trim()
                        : statusLabel ?? 'Open group',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: FlixieColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberAvatars extends StatelessWidget {
  const _MemberAvatars({required this.members});

  final List<GroupMember> members;

  @override
  Widget build(BuildContext context) {
    final shown = members.where((member) => member.isAccepted).take(5).toList();
    return SizedBox(
      height: 34,
      child: Stack(
        children: [
          for (var index = 0; index < shown.length; index++)
            Positioned(
              left: index * 20,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: FlixieColors.primary, width: 1.2),
                ),
                child: ProfileAvatarView(
                  avatar: shown[index].avatar,
                  fallbackText: shown[index].initials ??
                      (shown[index].username?.isNotEmpty == true
                          ? shown[index].username![0].toUpperCase()
                          : '?'),
                  fallbackColor: FlixieColors.primary,
                  size: 26,
                  profileBadges: shown[index].profileBadges,
                ),
              ),
            ),
        ],
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
