import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/features/social/data/chat_unread_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/data/chat_service.dart';
import 'package:flixie_app/features/social/presentation/utils/movie_share_payload.dart';
import 'package:flixie_app/models/conversation.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';

class ConversationsHub extends StatefulWidget {
  const ConversationsHub({super.key});

  @override
  State<ConversationsHub> createState() => _ConversationsHubState();
}

class _ConversationsHubState extends State<ConversationsHub> {
  final TextEditingController _search = TextEditingController();
  bool _safetyReady = false;
  bool _safetyFailed = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    SafetyService.changes.addListener(_onSearchChanged);
    _loadSafety();
  }

  Future<void> _loadSafety() async {
    try {
      await SafetyService.blockedUsers();
      if (mounted) {
        setState(() {
          _safetyReady = true;
          _safetyFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _safetyFailed = true;
        });
      }
    }
  }

  void _onSearchChanged() => setState(() {});

  @override
  void dispose() {
    SafetyService.changes.removeListener(_onSearchChanged);
    _search
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) return const SizedBox.shrink();
    if (!_safetyReady) {
      if (_safetyFailed) {
        return Center(
            child: TextButton.icon(
          onPressed: _loadSafety,
          icon: const Icon(Icons.refresh),
          label: const Text('Could not load chats. Retry'),
        ));
      }
      return const _ConversationLoading();
    }
    final friends = {
      for (final friendship
          in auth.cachedFriends?.friendships ?? const <Friendship>[])
        if (friendship.friendUser case final friend?) friend.id: friend,
    };
    final groups = {
      for (final group in auth.cachedGroups ?? const <Group>[])
        if (group.id case final id?) id: group,
    };

    return StreamBuilder<List<Conversation>>(
      stream: ChatService.conversationsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _ConversationLoading();
        }
        if (snapshot.hasError) {
          return const _ConversationEmpty(
            icon: Icons.cloud_off_rounded,
            title: 'Chats could not load',
            body: 'Check your connection and try again.',
          );
        }

        final query = _search.text.trim().toLowerCase();
        final conversations =
            (snapshot.data ?? const <Conversation>[]).where((conversation) {
          if (conversation.type != 'group' &&
              conversation.memberIds
                  .any((id) => id != userId && SafetyService.isBlocked(id))) {
            return false;
          }
          if (query.isEmpty) return true;
          return conversationTitle(
                conversation,
                currentUserId: userId,
                friends: friends,
                groups: groups,
              ).toLowerCase().contains(query) ||
              (!SafetyService.isBlocked(
                      conversation.lastMessageSenderId ?? '') &&
                  (conversation.lastMessage ?? '')
                      .toLowerCase()
                      .contains(query));
        }).toList(growable: false);

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          color: FlixieColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search conversations',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _search.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: context.colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: context.colors.tabBarBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: context.colors.tabBarBorder),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Text(
                    'Messages',
                    style: TextStyle(
                      color: context.colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${conversations.length} ${conversations.length == 1 ? 'chat' : 'chats'}',
                    style: const TextStyle(
                      color: FlixieColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (conversations.isEmpty)
                _ConversationEmpty(
                  icon: query.isEmpty
                      ? Icons.forum_outlined
                      : Icons.search_off_rounded,
                  title: query.isEmpty ? 'No chats yet' : 'No chats found',
                  body: query.isEmpty
                      ? 'Open a friend or group and send your first message.'
                      : 'Try another name or message.',
                )
              else
                ...conversations.map(
                  (conversation) => _ConversationRow(
                    conversation: conversation,
                    currentUserId: userId,
                    friend: _otherFriend(conversation, userId, friends),
                    group: conversation.pgGroupId == null
                        ? null
                        : groups[conversation.pgGroupId],
                    onTap: () => _openConversation(
                      context,
                      conversation,
                      userId,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openConversation(
    BuildContext context,
    Conversation conversation,
    String currentUserId,
  ) {
    if (conversation.type == 'group' && conversation.pgGroupId != null) {
      context.push('/groups/${conversation.pgGroupId}?tab=chat');
      return;
    }
    String? otherUserId;
    for (final memberId in conversation.memberIds) {
      if (memberId != currentUserId) {
        otherUserId = memberId;
        break;
      }
    }
    if (otherUserId != null) context.push('/chat/$otherUserId');
  }
}

FriendshipUser? _otherFriend(
  Conversation conversation,
  String currentUserId,
  Map<String, FriendshipUser> friends,
) {
  for (final memberId in conversation.memberIds) {
    if (memberId != currentUserId && friends[memberId] != null) {
      return friends[memberId];
    }
  }
  return null;
}

String conversationTitle(
  Conversation conversation, {
  required String currentUserId,
  required Map<String, FriendshipUser> friends,
  required Map<String, Group> groups,
}) {
  if (conversation.type == 'group') {
    return groups[conversation.pgGroupId]?.name ??
        conversation.name ??
        'Group chat';
  }
  return _otherFriend(conversation, currentUserId, friends)?.username ??
      conversation.name ??
      'Direct chat';
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.currentUserId,
    required this.friend,
    required this.group,
    required this.onTap,
  });

  final Conversation conversation;
  final String currentUserId;
  final FriendshipUser? friend;
  final Group? group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isGroup = conversation.type == 'group';
    final title = isGroup
        ? group?.name ?? conversation.name ?? 'Group chat'
        : friend?.username ?? conversation.name ?? 'Direct chat';
    final senderPrefix = conversation.lastMessageSenderId == currentUserId
        ? 'You: '
        : isGroup
            ? _groupSenderPrefix(context)
            : '';
    final preview = SafetyService.isBlocked(
            conversation.lastMessageSenderId ?? '')
        ? 'Message from a blocked user'
        : conversation.lastMessage?.trim().isNotEmpty == true
            ? '$senderPrefix${conversationMessagePreview(conversation.lastMessage)}'
            : 'Start the conversation';

    return Consumer<ChatUnreadController?>(
      builder: (context, controller, _) {
        final unread = controller?.countFor(conversation.id) ?? 0;
        return InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.colors.tabBarBorder),
              ),
            ),
            child: Row(
              children: [
                isGroup
                    ? _GroupChatAvatar(name: title)
                    : ProfileAvatarView(
                        avatar: friend?.avatar,
                        fallbackText:
                            title.isEmpty ? '?' : title[0].toUpperCase(),
                        fallbackColor: FlixieColors.primary,
                        size: 58,
                        profileBadges: friend?.profileBadges ?? const [],
                      ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.colors.white,
                                fontSize: 16,
                                fontWeight: unread > 0
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isGroup) ...[
                            const SizedBox(width: 8),
                            const FlixiePill.label(label: Text('Group')),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unread > 0
                              ? context.colors.light
                              : context.colors.medium,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      conversationTimeLabel(conversation.lastMessageAt),
                      style: TextStyle(
                        color: context.colors.medium,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (unread > 0)
                      Container(
                        constraints: const BoxConstraints(minWidth: 26),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: const BoxDecoration(
                          color: FlixieColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _groupSenderPrefix(BuildContext context) {
    final senderId = conversation.lastMessageSenderId;
    if (senderId == null) return '';
    final friends = context.read<AuthProvider>().cachedFriends?.friendships;
    for (final friendship in friends ?? const <Friendship>[]) {
      final user = friendship.friendUser;
      if (user?.id == senderId) return '${user!.username}: ';
    }
    return '';
  }
}

class _GroupChatAvatar extends StatelessWidget {
  const _GroupChatAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: FlixieColors.primary.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlixieColors.primary, width: 2),
      ),
      child: Icon(Icons.groups_2_outlined, color: context.colors.light),
    );
  }
}

String conversationTimeLabel(DateTime? date, {DateTime? now}) {
  if (date == null) return '';
  final current = now ?? DateTime.now();
  final difference = current.difference(date);
  if (difference.inMinutes < 1) return 'Now';
  if (difference.inHours < 1) return '${difference.inMinutes}m';
  if (difference.inHours < 24 && date.day == current.day) {
    return '${difference.inHours}h';
  }
  if (difference.inDays < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
  return '${date.day}/${date.month}/${date.year.toString().substring(2)}';
}

class _ConversationLoading extends StatelessWidget {
  const _ConversationLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 78,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

class _ConversationEmpty extends StatelessWidget {
  const _ConversationEmpty({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, color: FlixieColors.primary, size: 52),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: context.colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.medium, height: 1.4),
          ),
        ],
      ),
    );
  }
}
