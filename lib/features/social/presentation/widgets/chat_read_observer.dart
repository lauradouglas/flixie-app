import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/data/chat_service.dart';
import 'package:flixie_app/features/social/data/chat_unread_controller.dart';

/// Acknowledge messages only after their chat has rendered in the foreground.
class ChatReadObserver extends StatefulWidget {
  const ChatReadObserver(
      {super.key,
      required this.conversationId,
      required this.child,
      this.active = true});
  final String conversationId;
  final Widget child;
  final bool active;
  @override
  State<ChatReadObserver> createState() => _ChatReadObserverState();
}

class _ChatReadObserverState extends State<ChatReadObserver> {
  Timer? _timer;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _read());
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  Future<void> _read() async {
    if (!mounted ||
        _saving ||
        !widget.active ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final userId = context.read<AuthProvider>().dbUser?.id;
    final count = context
            .read<ChatUnreadController?>()
            ?.countFor(widget.conversationId) ??
        0;
    if (userId == null || count == 0) return;
    _saving = true;
    try {
      await ChatService.markRead(widget.conversationId, userId);
    } catch (_) {
      // Keep the unread indicator and retry while the conversation is visible.
    } finally {
      _saving = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
