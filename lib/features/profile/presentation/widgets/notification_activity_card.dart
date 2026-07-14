import 'package:flutter/material.dart';

import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/color_utils.dart';

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
    final avatarBg = avatarColorFromIconColor(
      notification.senderIconColor,
      fallback: _accentColor,
    );

    final dateStr = notification.receivedAt.isNotEmpty
        ? formatDate(notification.receivedAt)
        : '';
    final isUnread = !notification.isRead;

    return Container(
      decoration: BoxDecoration(
        color: isUnread
            ? FlixieColors.tabBarBackgroundFocused
            : FlixieColors.tabBarBackgroundFocused.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isUnread ? _accentColor : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
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
                              style: TextStyle(
                                color: FlixieColors.light,
                                fontSize: 14,
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Notification actions',
                      color: FlixieColors.tabBarBackgroundFocused,
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        size: 20,
                        color: FlixieColors.medium,
                      ),
                      onSelected: (value) {
                        if (value == 'dismiss') onClose();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'dismiss',
                          child: Text('Dismiss'),
                        ),
                      ],
                    ),
                    if (!notification.isRead)
                      Padding(
                        padding: const EdgeInsets.only(left: 2, top: 8),
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
                      color: FlixieColors.medium,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
