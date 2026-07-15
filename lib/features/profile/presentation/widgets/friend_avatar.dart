import 'package:flutter/material.dart';

import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class FriendAvatar extends StatelessWidget {
  const FriendAvatar({super.key, required this.user});
  final FriendshipUser user;

  Color get _avatarColor {
    final hex = user.iconColor?['hexCode'] as String?;
    if (hex != null) {
      try {
        return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
      } catch (_) {}
    }
    return FlixieColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileAvatarView(
          avatar: user.avatar,
          fallbackText: user.initials ??
              (user.username.isNotEmpty ? user.username[0].toUpperCase() : '?'),
          fallbackColor: _avatarColor,
          size: 76,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 76,
          child: Text(
            user.username,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}
