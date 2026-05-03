import 'package:flutter/material.dart';

import '../../models/friendship.dart';
import '../../theme/app_theme.dart';

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
        CircleAvatar(
          radius: 38,
          backgroundColor: _avatarColor.withValues(alpha: 0.3),
          child: Text(
            user.initials ??
                (user.username.isNotEmpty
                    ? user.username[0].toUpperCase()
                    : '?'),
            style: TextStyle(
              color: _avatarColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
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
