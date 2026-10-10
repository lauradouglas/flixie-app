import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Notification polling updates this action, not the Home carousels.
class HomeNotificationAction extends StatelessWidget {
  const HomeNotificationAction({super.key});
  @override
  Widget build(BuildContext context) {
    final count = context
        .select<AuthProvider, int>((auth) => auth.unreadNotificationCount);
    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: count < 100 ? Text('$count') : const Text('99+'),
        backgroundColor: FlixieColors.notificationBadge,
        textColor: FlixieColors.onNotificationBadge,
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        child: Icon(Icons.notifications_outlined, color: context.colors.light),
      ),
      onPressed: () async {
        final auth = context.read<AuthProvider>();
        await context.push('/notifications');
        if (context.mounted) await auth.refreshNotificationCount();
      },
    );
  }
}

class HomeUnreadUpdates extends StatelessWidget {
  const HomeUnreadUpdates({super.key});
  @override
  Widget build(BuildContext context) {
    final count = context
        .select<AuthProvider, int>((auth) => auth.unreadNotificationCount);
    if (count == 0) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.mark_chat_unread_outlined),
      title: const Text('Catch up on your Flixie'),
      subtitle: Text('$count unread updates'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/notifications'),
    );
  }
}

class HomeRefreshStatus extends StatelessWidget {
  const HomeRefreshStatus(
      {super.key, required this.secondaryError, required this.onRetry});
  final ValueNotifier<String?> secondaryError;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    final recoveryError =
        context.select<AuthProvider, String?>((auth) => auth.recoveryError);
    return ValueListenableBuilder<String?>(
      valueListenable: secondaryError,
      builder: (context, sectionError, _) {
        final error = recoveryError ?? sectionError;
        if (error == null) return const SizedBox.shrink();
        return ListTile(
            title: Text(error),
            trailing:
                TextButton(onPressed: onRetry, child: const Text('Retry')));
      },
    );
  }
}
