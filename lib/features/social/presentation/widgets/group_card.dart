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
    this.compact = false,
    this.onTap,
  });

  final bool compact;
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
    if (compact) {
      final description = group.description?.trim() ?? '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: context.colors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap ?? () => context.push('/groups/${group.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                GroupAvatar(group: group, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(group.name,
                          style: TextStyle(
                              color: context.colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      const SizedBox(height: 3),
                      Text(
                          [
                            if (count != null)
                              '$count member${count == 1 ? '' : 's'}',
                            if (description.isNotEmpty) description,
                          ].join(' · '),
                          style: TextStyle(
                              color: context.colors.light, fontSize: 13)),
                    ])),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    color: context.colors.primaryText),
              ]),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap ?? () => context.push('/groups/${group.id}'),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GroupAvatar(group: group, radius: 22),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(group.name,
                                  style: TextStyle(
                                      color: context.colors.white,
                                      fontSize: 15,
                                      height: 1.35,
                                      fontWeight: FontWeight.w700)),
                              if (count != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                    '${_formatCount(count)} member${count == 1 ? '' : 's'}',
                                    style: TextStyle(
                                        color: context.colors.light,
                                        fontSize: 12)),
                              ],
                              if (members.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _MemberAvatars(
                                    members: members, totalCount: count),
                              ],
                              if (statusLabel != null &&
                                  statusLabel != 'Community') ...[
                                const SizedBox(height: 6),
                                Text(statusLabel!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.colors.light)),
                              ],
                            ])),
                        const SizedBox(width: 8),
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Icon(Icons.chevron_right_rounded,
                                color: context.colors.primaryText, size: 22)),
                      ])))),
    );
  }
}

class _MemberAvatars extends StatelessWidget {
  const _MemberAvatars({required this.members, this.totalCount});

  final List<GroupMember> members;
  final int? totalCount;

  Widget _avatar(GroupMember member) => ProfileAvatarView(
        avatar: member.avatar,
        profileBadges: member.profileBadges,
        fallbackText: member.initials ??
            (member.username?.isNotEmpty == true
                ? member.username![0].toUpperCase()
                : '?'),
        fallbackColor: FlixieColors.primary,
        size: 32,
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
                  color: context.colors.tabBarBackgroundFocused,
                  border: Border.all(color: FlixieColors.primary, width: 2),
                ),
                child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('+$remaining',
                            style: TextStyle(
                                color: context.colors.primaryText,
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
