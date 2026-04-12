import 'package:flutter/material.dart';

import '../../models/notification.dart';
import '../../theme/app_theme.dart';

/// Parses the `iconColor` map from a user object into a [Color].
Color _avatarColorFromIconColor(Map<String, dynamic>? iconColor,
    {Color fallback = FlixieColors.primary}) {
  if (iconColor == null) return fallback;
  final hex = ((iconColor['hexCode'] ?? iconColor['hex']) as String? ?? '')
      .replaceAll('#', '');
  return Color(int.tryParse('0xFF$hex') ?? fallback.value);
}

class NotificationActivityCard extends StatelessWidget {
  const NotificationActivityCard({
    super.key,
    required this.notification,
    required this.formatDate,
    required this.onClose,
  });

  final FlixieNotification notification;
  final String Function(String) formatDate;
  final VoidCallback onClose;

  Color get _accentColor {
    switch (notification.type) {
      case 'MOVIE_WATCH_REQUEST':
      case 'SHOW_WATCH_REQUEST':
        return FlixieColors.primary;
      case 'ALERT':
        return FlixieColors.tertiary;
      default:
        return FlixieColors.secondary;
    }
  }

  IconData get _icon {
    switch (notification.type) {
      case 'MOVIE_WATCH_REQUEST':
      case 'SHOW_WATCH_REQUEST':
        return Icons.play_circle_outline;
      case 'ALERT':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = notification.senderName;
    final initials = notification.senderInitials ?? '';
    final avatarBg = _avatarColorFromIconColor(
      notification.senderIconColor,
      fallback: _accentColor,
    );

    final dateStr = notification.receivedAt.isNotEmpty
        ? formatDate(notification.receivedAt)
        : '';

    return Container(
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _accentColor, width: 3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar or icon
          CircleAvatar(
            radius: 22,
            backgroundColor: avatarBg.withValues(alpha: 0.2),
            child: initials.isNotEmpty
                ? Text(
                    initials,
                    style: TextStyle(
                      color: avatarBg,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  )
                : Icon(_icon, color: avatarBg, size: 20),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            if (name.isNotEmpty)
                              TextSpan(
                                text: '$name ',
                                style: const TextStyle(
                                  color: FlixieColors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            TextSpan(
                              text: notification.message,
                              style: const TextStyle(
                                color: FlixieColors.light,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Close icon
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 20, color: FlixieColors.medium),
                      tooltip: 'Close',
                      onPressed: onClose,
                    ),
                    if (!notification.isRead)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: FlixieColors.tertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: FlixieColors.light,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
