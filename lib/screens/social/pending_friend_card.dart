import 'package:flutter/material.dart';

import '../../models/friendship.dart';
import '../../theme/app_theme.dart';

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
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlixieColors.tabBarBorder),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.3),
              child: Text(
                user?.initials ??
                    (user?.username.isNotEmpty == true
                        ? user!.username[0].toUpperCase()
                        : '?'),
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user?.username ?? 'Unknown',
                style: const TextStyle(
                    color: FlixieColors.light, fontWeight: FontWeight.w500),
              ),
            ),
            SizedBox(
              height: 34,
              child: OutlinedButton(
                onPressed: onDecline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: FlixieColors.danger,
                  side: const BorderSide(color: FlixieColors.danger),
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
                  foregroundColor: Colors.black,
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
