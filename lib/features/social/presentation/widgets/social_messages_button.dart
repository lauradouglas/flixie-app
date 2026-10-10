import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/chat_unread_controller.dart';

/// Only the message badge rebuilds when live unread counts change.
class SocialMessagesButton extends StatelessWidget {
  const SocialMessagesButton({super.key});
  @override
  Widget build(BuildContext context) {
    final unread = context.select<ChatUnreadController?, int>(
        (controller) => controller?.total ?? 0);
    return TextButton.icon(
        onPressed: () => context.push('/messages'),
        icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.chat_bubble_outline, size: 20)),
        label: const Text('Messages'));
  }
}
