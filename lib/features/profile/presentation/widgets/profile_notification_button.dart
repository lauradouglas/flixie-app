import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Notification-only updates do not invalidate Profile's header and tab content.
class ProfileNotificationButton extends StatelessWidget {
  const ProfileNotificationButton({super.key});
  @override
  Widget build(BuildContext context) {
    final count = context
        .select<AuthProvider, int>((auth) => auth.unreadNotificationCount);
    return IconButton(
        tooltip: 'Notifications',
        icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count < 100 ? '$count' : '99+'),
            backgroundColor: FlixieColors.notificationBadge,
            textColor: FlixieColors.onNotificationBadge,
            textStyle:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            child: const Icon(Icons.notifications_outlined)),
        onPressed: () async {
          final auth = context.read<AuthProvider>();
          await context.push('/notifications');
          if (context.mounted) auth.refreshNotificationCount();
        });
  }
}
