import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/data/chat_service.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_bubble.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_input.dart';
import 'package:flixie_app/models/conversation.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/core/safety/safety_service.dart';

class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({super.key, required this.otherUserId});

  final String otherUserId;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  String? _conversationId;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  User? _otherUser;
  Map<String, String> _memberUsernames = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initConversation();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initConversation() async {
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    if (currentUserId == null) return;

    try {
      final results = await Future.wait([
        UserService.getUserById(widget.otherUserId),
        ChatService.getOrCreateDirectConversation(
          userId: currentUserId,
          otherUserId: widget.otherUserId,
        ),
      ]);
      final otherUser = results[0] as User?;
      final conversation = results[1] as Conversation;
      final memberUsernames = await ChatService.fetchMemberUsernames(
        conversation.id,
      ).catchError((_) => <String, String>{});

      if (!mounted) return;
      setState(() {
        _otherUser = otherUser;
        _conversationId = conversation.id;
        _memberUsernames = memberUsernames;
        _loading = false;
        _error = null;
      });

      ChatService.markRead(conversation.id, currentUserId).catchError((_) {});
    } catch (e) {
      logger.e('Direct chat init error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load chat';
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final conversationId = _conversationId;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (text.isEmpty || conversationId == null || userId == null) return;

    setState(() => _sending = true);
    _messageController.clear();
    try {
      await ChatService.sendMessage(
        conversationId: conversationId,
        senderId: userId,
        text: text,
      );
    } catch (e) {
      logger.e('Direct chat send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F081E),
        body: Center(
          child: CircularProgressIndicator(color: FlixieColors.primary),
        ),
      );
    }

    if (_error != null || _conversationId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F081E),
        appBar: AppBar(backgroundColor: const Color(0xFF0F081E)),
        body: Center(
          child: Text(
            _error ?? 'Could not open chat',
            style: const TextStyle(color: FlixieColors.medium),
          ),
        ),
      );
    }

    final conversationId = _conversationId!;
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    final otherUser = _otherUser;
    final title = otherUser?.username.isNotEmpty == true
        ? '@${otherUser!.username}'
        : 'Chat';

    return Scaffold(
      backgroundColor: const Color(0xFF0F081E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F081E),
        titleSpacing: 0,
        title: Row(
          children: [
            ProfileAvatarView(
              avatar: otherUser?.avatar,
              fallbackText: otherUser?.initials ??
                  (otherUser?.username.isNotEmpty == true
                      ? otherUser!.username[0].toUpperCase()
                      : '?'),
              fallbackColor: FlixieColors.primary,
              size: 34,
              profileBadges: otherUser?.profileBadges ?? const [],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatService.messagesStream(conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: FlixieColors.primary,
                    ),
                  );
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: TextStyle(color: FlixieColors.medium),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUserId;
                    if (!isMe && SafetyService.isBlocked(msg.senderId)) {
                      return const SizedBox.shrink();
                    }
                    return ChatBubble(
                      message: msg.text,
                      senderUsername: msg.senderUsername ??
                          _memberUsernames[msg.senderId] ??
                          (isMe ? 'You' : title),
                      isMe: isMe,
                      sentAt: msg.createdAt,
                      avatar: isMe ? null : otherUser?.avatar,
                      initials: isMe
                          ? null
                          : (otherUser?.initials ??
                              (otherUser?.username.isNotEmpty == true
                                  ? otherUser!.username[0].toUpperCase()
                                  : '?')),
                      profileBadges: isMe
                          ? const []
                          : (otherUser?.profileBadges ?? const []),
                    );
                  },
                );
              },
            ),
          ),
          ChatInput(
            controller: _messageController,
            sending: _sending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
