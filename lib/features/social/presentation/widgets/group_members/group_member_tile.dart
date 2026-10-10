import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class GroupMemberTile extends StatelessWidget {
  const GroupMemberTile({
    super.key,
    required this.member,
    required this.isMe,
    required this.showChevron,
    this.onTap,
  });

  final GroupMember member;
  final bool isMe;
  final bool showChevron;
  final VoidCallback? onTap;

  String _roleLabel() {
    if (member.isOwner) return 'OWNER';
    if (member.isAdmin) return 'ADMIN';
    return 'MEMBER';
  }

  Color _avatarColor() {
    final hex = member.iconColor?['hexCode'] as String?;
    if (hex != null) {
      try {
        return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
      } catch (_) {}
    }
    return FlixieColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor();
    final initials = member.initials ??
        (member.username?.isNotEmpty == true
            ? member.username![0].toUpperCase()
            : '?');
    return ListTile(
      onTap: onTap,
      leading: ProfileAvatarView(
        avatar: member.avatar,
        fallbackText: initials,
        fallbackColor: color,
        size: 44,
        profileBadges: member.profileBadges,
      ),
      title: Wrap(
        children: [
          Text(
            member.displayName,
            style: TextStyle(
              color: isMe ? FlixieColors.primary : context.colors.light,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            Text('(you)',
                style: TextStyle(color: context.colors.medium, fontSize: 12)),
          ],
        ],
      ),
      subtitle: member.isPending
          ? Text('Invite pending',
              style: TextStyle(color: context.colors.warning, fontSize: 12))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlixiePill.label(label: Text(_roleLabel())),
          if (showChevron) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: context.colors.medium, size: 16),
          ],
        ],
      ),
    );
  }
}
