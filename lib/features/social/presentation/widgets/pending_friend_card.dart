import 'package:flutter/material.dart';

import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class PendingFriendCard extends StatelessWidget {
  const PendingFriendCard({
    super.key,
    required this.friendship,
    required this.onAccept,
    required this.onDecline,
    this.onTap,
  });

  final Friendship friendship;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onTap;

  Color _avatarColor() {
    final hex = friendship.friendUser?.iconColor?['hexCode'] as String?;
    if (hex != null) {
      try {
        return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
      } catch (_) {}
    }
    return FlixieColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final user = friendship.friendUser;
    final color = _avatarColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.tabBarBorder),
        ),
        child: Row(
          children: [
            ProfileAvatarView(
              avatar: user?.avatar,
              fallbackText: user?.initials ??
                  (user?.username.isNotEmpty == true
                      ? user!.username[0].toUpperCase()
                      : '?'),
              fallbackColor: color,
              size: 44,
              profileBadges: user?.profileBadges ?? const [],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user?.username ?? 'Unknown',
                style: TextStyle(
                    color: context.colors.light, fontWeight: FontWeight.w500),
              ),
            ),
            SizedBox(
              height: 34,
              child: OutlinedButton(
                onPressed: onDecline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.danger,
                  side: BorderSide(color: context.colors.danger),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              height: 34,
              child: ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlixieColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('Accept'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
