import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/features/social/presentation/widgets/watch_request_chat_card.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_read_observer.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/data/chat_service.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_bubble.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_input.dart';
import 'package:flixie_app/features/social/presentation/utils/activity_reply_payload.dart';
import 'package:flixie_app/models/conversation.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/core/safety/safety_service.dart';

class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({
    super.key,
    required this.otherUserId,
    this.initialActivityReply,
  });

  final String otherUserId;
  final ActivityReplyPayload? initialActivityReply;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  String? _conversationId;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  User? _otherUser;
  Map<String, String> _memberUsernames = {};
  ActivityReplyPayload? _activityReply;
  final Map<String, GroupWatchRequest> _watchPlans = {};
  final Set<String> _friendPlanIds = {};
  final Map<String, String> _messagePlanIds = {};
  final Set<String> _requestedPlanIds = {};
  final Set<String> _respondingPlanIds = {};
  bool _loadingPlans = false;
  bool _plansRefreshQueued = false;

  Future<void> _loadWatchPlans() async {
    final conversationId = _conversationId;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (conversationId == null || userId == null) return;
    if (_loadingPlans) {
      _plansRefreshQueued = true;
      return;
    }
    _loadingPlans = true;
    try {
      final plans = <GroupWatchRequest>[];
      try {
        plans.addAll(await GroupService.getConversationWatchRequests(
            conversationId,
            filter: WatchRequestFilter.all,
            userId: userId));
      } catch (error) {
        logger.w('Could not load conversation watch plans: $error');
      }
      for (final id in _friendPlanIds.toList()) {
        try {
          plans.add(await RequestService.getChatWatchPlan(id, userId));
        } catch (error) {
          logger.w('Could not load direct watch plan $id: $error');
        }
      }
      if (!mounted) return;
      setState(() {
        for (final plan in plans) {
          _watchPlans[plan.id] = plan;
          if (plan.linkedMessageId != null) {
            _messagePlanIds[plan.linkedMessageId!] = plan.id;
          }
          if (plan.databaseRequestId != null) {
            _watchPlans[plan.databaseRequestId!] = plan;
          }
        }
      });
    } catch (error) {
      logger.w('Could not refresh chat watch plans: $error');
    } finally {
      _loadingPlans = false;
      if (_plansRefreshQueued && mounted) {
        _plansRefreshQueued = false;
        _loadWatchPlans();
      }
    }
  }

  Future<void> _respondToPlan(
      GroupWatchRequest plan, WatchResponseDecision decision) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final conversationId = _conversationId;
    if (userId == null ||
        conversationId == null ||
        _respondingPlanIds.contains(plan.id)) {
      return;
    }
    setState(() => _respondingPlanIds.add(plan.id));
    try {
      if (_friendPlanIds.contains(plan.id)) {
        await RequestService.updateRequest(
            plan.id, decision.apiValue.toLowerCase());
      } else {
        await GroupService.respondToWatchRequest(
            conversationId, plan.id, userId, decision);
      }
      await _loadWatchPlans();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save your reply. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _respondingPlanIds.remove(plan.id));
    }
  }

  @override
  void initState() {
    super.initState();
    _activityReply = widget.initialActivityReply;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initConversation();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
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

      if (_activityReply != null) {
        _messageFocusNode.requestFocus();
      }
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

    final outgoingText = _activityReply?.withMessage(text) ?? text;
    setState(() => _sending = true);
    _messageController.clear();
    try {
      await ChatService.sendMessage(
        conversationId: conversationId,
        senderId: userId,
        text: outgoingText,
      );
      if (mounted) setState(() => _activityReply = null);
    } catch (e) {
      logger.e('Direct chat send error: $e');
      if (mounted) {
        if (_messageController.text.isEmpty) {
          _messageController.text = text;
          _messageController.selection = TextSelection.collapsed(
            offset: text.length,
          );
        }
        ScaffoldMessenger.of(
          context,
        ).showFlixieToast(FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Failed to send message')));
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
        title: Semantics(
          button: true,
          label: 'Open $title profile',
          child: InkWell(
            onTap: () => context.push('/friends/${widget.otherUserId}'),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              child: Row(
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
          ),
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
                return ChatReadObserver(
                    conversationId: conversationId,
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 8,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (_, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == currentUserId;
                        // The list is reverse-rendered, so the visually first
                        // bubble in a sender run is the next item in data order.
                        final startsSenderRun = index == messages.length - 1 ||
                            messages[index + 1].senderId != msg.senderId;
                        if (!isMe && SafetyService.isBlocked(msg.senderId)) {
                          return const SizedBox.shrink();
                        }
                        if (msg.type == 'watch_request') {
                          final metadata = msg.watchRequestPayload?['metadata'];
                          if (metadata is Map &&
                              metadata['requestType'] != null &&
                              msg.watchRequestId != null) {
                            _friendPlanIds.add(msg.watchRequestId!);
                          }
                          final planId =
                              msg.watchRequestId ?? _messagePlanIds[msg.id];
                          final plan = _watchPlans[planId] ??
                              _watchPlans[_messagePlanIds[msg.id]];
                          if (_requestedPlanIds.add(planId ?? msg.id)) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _loadWatchPlans();
                            });
                          }
                          return WatchRequestChatCard(
                            msg: msg,
                            senderAvatar: isMe
                                ? context.read<AuthProvider>().dbUser?.avatar
                                : otherUser?.avatar,
                            senderProfileBadges: isMe
                                ? context
                                        .read<AuthProvider>()
                                        .dbUser
                                        ?.profileBadges ??
                                    const []
                                : otherUser?.profileBadges ?? const [],
                            cachedRequest: plan,
                            currentUserId: currentUserId,
                            memberUsernames: _memberUsernames,
                            isResponding: _respondingPlanIds.contains(plan?.id),
                            onAccept: plan == null
                                ? null
                                : () => _respondToPlan(
                                    plan, WatchResponseDecision.accepted),
                            onDecline: plan == null
                                ? null
                                : () => _respondToPlan(
                                    plan, WatchResponseDecision.declined),
                            onTap: () async {
                              if (planId != null) {
                                await context.push(
                                    '/watch-requests/${Uri.encodeComponent(plan?.databaseRequestId ?? planId)}');
                              } else {
                                await context.push('/watch-requests');
                              }
                              if (mounted) await _loadWatchPlans();
                            },
                          );
                        }
                        return ChatBubble(
                          currentUserId: currentUserId,
                          currentUsername:
                              context.read<AuthProvider>().dbUser?.username,
                          message: msg.text,
                          senderUsername: msg.senderUsername ??
                              _memberUsernames[msg.senderId] ??
                              (isMe ? 'You' : title),
                          isMe: isMe,
                          sentAt: msg.createdAt,
                          avatar: isMe
                              ? context.read<AuthProvider>().dbUser?.avatar
                              : otherUser?.avatar,
                          initials: isMe
                              ? context.read<AuthProvider>().dbUser?.initials
                              : (otherUser?.initials ??
                                  (otherUser?.username.isNotEmpty == true
                                      ? otherUser!.username[0].toUpperCase()
                                      : '?')),
                          profileBadges: isMe
                              ? context
                                      .read<AuthProvider>()
                                      .dbUser
                                      ?.profileBadges ??
                                  const []
                              : (otherUser?.profileBadges ?? const []),
                          showSenderLabel: !isMe && startsSenderRun,
                          onSenderTap: isMe
                              ? null
                              : () => context.push('/friends/${msg.senderId}'),
                        );
                      },
                    ));
              },
            ),
          ),
          if (_activityReply != null)
            _ActivityReplyComposerBanner(
              payload: _activityReply!,
              onCancel: () => setState(() => _activityReply = null),
            ),
          ChatInput(
            controller: _messageController,
            focusNode: _messageFocusNode,
            sending: _sending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _ActivityReplyComposerBanner extends StatelessWidget {
  const _ActivityReplyComposerBanner({
    required this.payload,
    required this.onCancel,
  });

  final ActivityReplyPayload payload;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlixieColors.primary.withValues(alpha: .55)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              color: FlixieColors.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to @${payload.username}’s ${payload.activityLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlixieColors.primaryTint,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  payload.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlixieColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel reply',
            onPressed: onCancel,
            icon: const Icon(Icons.close, color: FlixieColors.medium, size: 19),
          ),
        ],
      ),
    );
  }
}
