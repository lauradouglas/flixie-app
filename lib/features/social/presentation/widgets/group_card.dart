import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_badges.dart';
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
        // Give the final status row the same comfortable clearance as the
        // top content; it was sitting too close to the card edge on phones.
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
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
                        _MemberAvatars(members: members, totalCount: count),
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
  const _MemberAvatars({required this.members, this.totalCount});

  final List<GroupMember> members;
  final int? totalCount;

  Widget _avatar(GroupMember member) => SpecialAvatarFrame(
        badges: member.profileBadges,
        frameWidth: 3,
        child: ProfileAvatarView(
          avatar: member.avatar,
          fallbackText: member.initials ??
              (member.username?.isNotEmpty == true
                  ? member.username![0].toUpperCase()
                  : '?'),
          fallbackColor: FlixieColors.primary,
          size: 26,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final accepted = members.where((member) => member.isAccepted).toList();
    final total =
        (totalCount ?? accepted.length).clamp(accepted.length, 1000000000);
    if (total <= 3) {
      return Wrap(
          spacing: 8, runSpacing: 8, children: accepted.map(_avatar).toList());
    }
    return LayoutBuilder(builder: (context, constraints) {
      const diameter = 32.0;
      const step = 24.0;
      // Reserve a full-size overflow circle; reduce the preview on narrow cards.
      final slots = ((constraints.maxWidth - diameter) / step).floor() + 1;
      var shownCount = accepted.length.clamp(0, 5);
      if (total > shownCount) {
        shownCount = shownCount.clamp(0, (slots - 1).clamp(0, 5));
      } else if (shownCount > slots) {
        shownCount = (slots - 1).clamp(0, shownCount);
      }
      final remaining = total - shownCount;
      final children = <Widget>[
        for (final member in accepted.take(shownCount)) _avatar(member),
        if (remaining > 0)
          Tooltip(
            message: '$remaining more members',
            child: Semantics(
              label: '$remaining more members',
              child: Container(
                width: diameter,
                height: diameter,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FlixieColors.tabBarBackgroundFocused,
                  border: Border.all(color: FlixieColors.primary, width: 2),
                ),
                child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('+$remaining',
                            style: const TextStyle(
                                color: FlixieColors.primaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)))),
              ),
            ),
          ),
      ];
      return SizedBox(
        width: children.isEmpty ? 0 : diameter + step * (children.length - 1),
        height: diameter,
        child: Stack(clipBehavior: Clip.none, children: [
          for (var index = 0; index < children.length; index++)
            Positioned(left: index * step, top: 0, child: children[index]),
        ]),
      );
    });
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
