import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/activity_list_item.dart';
import '../models/conversation.dart';
import '../models/group.dart';
import '../models/group_member.dart';
import '../models/group_watch_request.dart';
import '../providers/auth_provider.dart';
import '../screens/profile/activity_tile.dart';
import '../services/chat_service.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  Group? _group;
  bool _loadingGroup = true;
  int _memberCount = 0;
  List<GroupMember> _groupMembers = [];
  List<GroupWatchRequest> _watchRequests = [];
  List<ActivityListItem> _memberActivity = [];
  String? _conversationId;

  int get _pendingRequestCount {
    return _watchRequests.where((r) => r.isActive).length;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGroup();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroup() async {
    try {
      final coreResults = await Future.wait([
        GroupService.getGroup(widget.groupId),
        GroupService.getGroupMembers(widget.groupId),
      ]);

      final secondaryResults = await Future.wait([
        GroupService.getGroupWatchRequests(widget.groupId)
            .catchError((_) => <GroupWatchRequest>[]),
        GroupService.getGroupActivity(widget.groupId)
            .catchError((_) => <ActivityListItem>[]),
      ]);

      if (mounted) {
        setState(() {
          _group = coreResults[0] as Group;
          final members = coreResults[1] as List<GroupMember>;
          _memberCount = members.length;
          _groupMembers = members;
          _watchRequests = secondaryResults[0] as List<GroupWatchRequest>;
          _memberActivity = secondaryResults[1] as List<ActivityListItem>;
          _loadingGroup = false;
        });
        // Resolve the Firestore conversationId once group + members are known.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadConversationId();
        });
      }
    } catch (e) {
      logger.e('GroupDetail load group error: $e');
      if (mounted) setState(() => _loadingGroup = false);
    }
  }

  /// Resolve (or create) the Firestore conversation for this group so that
  /// conversation-scoped watch-request endpoints can be used.
  Future<void> _loadConversationId() async {
    if (_conversationId != null) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || _group == null || _groupMembers.isEmpty) return;
    try {
      final memberIds = _groupMembers.map((m) => m.memberId).toList();
      if (!memberIds.contains(userId)) memberIds.add(userId);
      final conv = await ChatService.getOrCreateGroupConversation(
        creatorId: userId,
        pgGroupId: widget.groupId,
        name: _group!.name,
        memberIds: memberIds,
      );
      if (mounted) setState(() => _conversationId = conv.id);
    } catch (e) {
      logger.e('Failed to resolve conversationId for watch requests: $e');
    }
  }

  static const List<Color> _palette = [
    FlixieColors.primary,
    FlixieColors.secondary,
    FlixieColors.tertiary,
    FlixieColors.success,
    FlixieColors.warning,
  ];

  Color _groupColor(String name) {
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    return _palette[hash % _palette.length];
  }

  String _groupAbbr(Group group) {
    if (group.abbreviation != null && group.abbreviation!.isNotEmpty) {
      return group.abbreviation!.toUpperCase();
    }
    final words = group.name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return group.name.isEmpty
        ? '?'
        : group.name.substring(0, group.name.length.clamp(1, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final groupName = _group?.name ?? '';
    final color =
        groupName.isNotEmpty ? _groupColor(groupName) : FlixieColors.primary;

    return Scaffold(
      backgroundColor: FlixieColors.background,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        elevation: 0,
        leading: _loadingGroup
            ? null
            : Padding(
                padding: const EdgeInsets.all(10),
                child: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.3),
                  child: Text(
                    _group != null ? _groupAbbr(_group!) : '',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
        title: _loadingGroup
            ? const Text('Loading…',
                style: TextStyle(color: FlixieColors.medium))
            : Text(
                _group?.name ?? 'Group',
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: FlixieColors.light),
            onPressed: () => _showGroupOptions(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: FlixieColors.primary,
          unselectedLabelColor: FlixieColors.medium,
          indicatorColor: FlixieColors.primary,
          tabs: [
            const Tab(text: 'Chat'),
            const Tab(text: 'Activity'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requests'),
                  if (_pendingRequestCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: FlixieColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_pendingRequestCount',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ChatTab(groupId: widget.groupId),
          _ActivityTab(
            group: _group,
            memberCount: _memberCount,
            groupId: widget.groupId,
            conversationId: _conversationId,
            initialRequests: _watchRequests,
            initialActivity: _memberActivity,
            onRefresh: _loadGroup,
          ),
          _RequestsTab(
            groupId: widget.groupId,
            conversationId: _conversationId,
            initialRequests: _watchRequests,
            currentUserId: context.read<AuthProvider>().dbUser?.id ?? '',
            isAdmin: () {
              final uid = context.read<AuthProvider>().dbUser?.id;
              if (uid == null) return false;
              if (_group?.ownerId == uid) return true;
              return _groupMembers
                  .any((m) => m.memberId == uid && (m.isAdmin || m.isOwner));
            }(),
            onCountChanged: (count) {
              if (mounted) setState(() => _watchRequests = _watchRequests);
            },
          ),
        ],
      ),
    );
  }

  void _showGroupOptions(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    final isOwner = _group?.ownerId == currentUserId;
    showModalBottomSheet(
      context: context,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FlixieColors.medium.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading:
                  const Icon(Icons.people_outline, color: FlixieColors.light),
              title: const Text('Members',
                  style: TextStyle(color: FlixieColors.light)),
              onTap: () {
                Navigator.pop(context);
                context.push(
                  '/groups/${widget.groupId}/members',
                  extra: _group?.name ?? 'Group',
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.info_outline, color: FlixieColors.light),
              title: const Text('Group Info',
                  style: TextStyle(color: FlixieColors.light)),
              onTap: () => Navigator.pop(context),
            ),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: FlixieColors.danger),
                title: const Text('Delete Group',
                    style: TextStyle(color: FlixieColors.danger)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: FlixieColors.tabBarBackgroundFocused,
                      title: const Text('Delete Group',
                          style: TextStyle(color: FlixieColors.light)),
                      content: const Text(
                        'Delete this group? This cannot be undone.',
                        style: TextStyle(color: FlixieColors.medium),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: FlixieColors.danger,
                              foregroundColor: Colors.white),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    try {
                      await GroupService.deleteGroup(widget.groupId);
                      if (mounted) context.pop();
                    } catch (e) {
                      logger.e('Delete group error: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Failed to delete group')),
                        );
                      }
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat tab
// ---------------------------------------------------------------------------

class _ChatTab extends StatefulWidget {
  const _ChatTab({required this.groupId});

  final String groupId;

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final TextEditingController _messageController = TextEditingController();
  String? _conversationId;
  bool _initLoading = true;
  bool _sending = false;
  String? _initError;
  AuthProvider? _authProvider;
  // userId → username, populated from the members subcollection
  Map<String, String> _memberUsernames = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_authProvider == null) {
      _authProvider = context.read<AuthProvider>();
      _authProvider!.addListener(_onAuthChanged);
    }
  }

  void _onAuthChanged() {
    // Retry init if we were waiting for the user to load
    if (_initLoading && _authProvider?.dbUser != null) {
      _initConversation();
    }
  }

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback so context is fully ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initConversation();
    });
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initConversation() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) {
      // dbUser not ready yet — listener will retry once it loads
      return;
    }
    if (!_initLoading) return; // already resolved
    try {
      final results = await Future.wait([
        GroupService.getGroup(widget.groupId),
        GroupService.getGroupMembers(widget.groupId),
      ]);
      final group = results[0] as Group;
      final members = results[1] as List<GroupMember>;
      final memberIds = members.map((m) => m.memberId).toList();
      if (!memberIds.contains(userId)) memberIds.add(userId);

      final conversation = await ChatService.getOrCreateGroupConversation(
        creatorId: userId,
        pgGroupId: widget.groupId,
        name: group.name,
        memberIds: memberIds,
      );

      if (mounted) {
        // Fetch member usernames from Firestore members subcollection
        final usernames =
            await ChatService.fetchMemberUsernames(conversation.id)
                .catchError((_) => <String, String>{});
        if (mounted) {
          setState(() {
            _conversationId = conversation.id;
            _memberUsernames = usernames;
            _initLoading = false;
          });
        }
        ChatService.markRead(conversation.id, userId).catchError((_) {});
      }
    } catch (e) {
      logger.e('Chat init error: $e');
      if (mounted) {
        setState(() {
          _initLoading = false;
          _initError = 'Could not load chat';
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
      logger.e('Send message error: $e');
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
    if (_initLoading) {
      return const Center(
          child: CircularProgressIndicator(color: FlixieColors.primary));
    }
    if (_initError != null) {
      return Center(
          child: Text(_initError!,
              style: const TextStyle(color: FlixieColors.medium)));
    }

    final conversationId = _conversationId!;
    final currentUserId = context.read<AuthProvider>().dbUser?.id;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: ChatService.messagesStream(conversationId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                    child:
                        CircularProgressIndicator(color: FlixieColors.primary));
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
              // Firestore returns newest-first (descending); reverse: true renders
              // newest at bottom like a standard chat layout.
              return ListView.builder(
                reverse: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i];
                  final isMe = msg.senderId == currentUserId;
                  // Prefer the username embedded in the message doc; fall back
                  // to the members subcollection map we fetched at init.
                  final _sid = msg.senderId;
                  final username = msg.senderUsername ??
                      _memberUsernames[_sid] ??
                      _sid.substring(0, _sid.length.clamp(0, 6));
                  return _ChatBubble(
                    message: msg.text,
                    senderUsername: username,
                    isMe: isMe,
                  );
                },
              );
            },
          ),
        ),
        _ChatInput(
          controller: _messageController,
          sending: _sending,
          onSend: _sendMessage,
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.senderUsername,
    required this.isMe,
  });

  final String message;
  final String senderUsername;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : 4,
              right: isMe ? 4 : 0,
              bottom: 3,
            ),
            child: Text(
              isMe ? 'You' : senderUsername,
              style: TextStyle(
                color: isMe
                    ? FlixieColors.primary.withValues(alpha: 0.8)
                    : FlixieColors.medium,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? FlixieColors.primary.withValues(alpha: 0.85)
                  : FlixieColors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.black : FlixieColors.light,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
      decoration: const BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        border: Border(
          top: BorderSide(color: FlixieColors.tabBarBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: FlixieColors.light),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: const TextStyle(color: FlixieColors.medium),
                  filled: true,
                  fillColor: FlixieColors.tabBarBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            sending
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: FlixieColors.primary),
                  )
                : IconButton(
                    onPressed: onSend,
                    icon: const Icon(Icons.send_rounded,
                        color: FlixieColors.primary),
                  ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity tab  — Group Dashboard
// ---------------------------------------------------------------------------

class _ActivityTab extends StatefulWidget {
  const _ActivityTab({
    required this.group,
    required this.memberCount,
    required this.groupId,
    this.conversationId,
    required this.initialRequests,
    required this.initialActivity,
    required this.onRefresh,
  });

  final Group? group;
  final int memberCount;
  final String groupId;
  final String? conversationId;
  final List<GroupWatchRequest> initialRequests;
  final List<ActivityListItem> initialActivity;
  final Future<void> Function() onRefresh;

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  late List<ActivityListItem> _activity;
  late List<GroupWatchRequest> _requests;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _activity = widget.initialActivity;
    _requests = widget.initialRequests;
  }

  @override
  void didUpdateWidget(_ActivityTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialActivity != oldWidget.initialActivity ||
        widget.initialRequests != oldWidget.initialRequests) {
      setState(() {
        _activity = widget.initialActivity;
        _requests = widget.initialRequests;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await widget.onRefresh();
    if (mounted) {
      setState(() {
        _activity = widget.initialActivity;
        _requests = widget.initialRequests;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final group = widget.group;
    final textTheme = Theme.of(context).textTheme;
    final currentUserId = context.read<AuthProvider>().dbUser?.id;

    // Pending requests only (no response from current user yet)
    final pendingRequests = _requests.where((r) {
      final myStatus = r.memberStatuses
          .where((s) => s.memberId == currentUserId)
          .map((s) => s.status)
          .firstOrNull;
      return myStatus == null || myStatus == 'PENDING';
    }).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      color: FlixieColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Hero banner ------------------------------------------------
            if (group != null)
              _GroupHeroBanner(group: group, memberCount: widget.memberCount),

            const SizedBox(height: 16),

            // ---- Recent Activity --------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: FlixieColors.tertiary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'RECENT ACTIVITY',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: FlixieColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: FlixieColors.success.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: FlixieColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_activity.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'No recent activity.',
                  style:
                      textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
                ),
              )
            else
              ...(_activity.take(5).map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ActivityTile(item: item),
                    ),
                  )),

            const SizedBox(height: 20),

            const SizedBox(height: 20),

            // ---- Pending Requests -------------------------------------------
            if (pendingRequests.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 22,
                      decoration: BoxDecoration(
                        color: FlixieColors.warning,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'PENDING REQUESTS (${pendingRequests.length})',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ...pendingRequests.take(3).map(
                    (req) => _PendingRequestPreviewTile(
                      request: req,
                      canRespond: req.userId != currentUserId,
                      onRespond: (status) async {
                        final userId = context.read<AuthProvider>().dbUser?.id;
                        if (userId == null) return;
                        // Use conversation-scoped endpoint when possible;
                        // fall back to legacy PUT endpoint.
                        final convId = widget.conversationId ?? req.groupId;
                        try {
                          try {
                            final decision =
                                WatchResponseDecision.fromString(status);
                            await GroupService.respondToWatchRequest(
                                convId, req.id, userId, decision);
                          } catch (e) {
                            logger.d(
                                'New respond endpoint failed, using legacy: $e');
                            await GroupService.updateWatchRequestForMember(
                                req.id, userId, '', status);
                          }
                          await _refresh();
                        } catch (e) {
                          logger.e('Respond to request error: $e');
                        }
                      },
                    ),
                  ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Group hero banner
// ---------------------------------------------------------------------------

class _GroupHeroBanner extends StatelessWidget {
  const _GroupHeroBanner({required this.group, required this.memberCount});

  final Group group;
  final int memberCount;

  static const List<Color> _palette = [
    FlixieColors.primary,
    FlixieColors.secondary,
    FlixieColors.tertiary,
    FlixieColors.success,
    FlixieColors.warning,
  ];

  Color get _color {
    final hash = group.name.codeUnits.fold(0, (a, b) => a + b);
    return _palette[hash % _palette.length];
  }

  String _formatCount(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: group identity card
          Expanded(
            flex: 3,
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.35),
                    FlixieColors.tabBarBackgroundFocused,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                border: Border.all(color: FlixieColors.tabBarBorder),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: FlixieColors.tertiary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ACTIVE COMMUNITY',
                      style: TextStyle(
                        color: FlixieColors.tertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    group.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // Right: member count card
          Container(
            width: 90,
            height: 110,
            decoration: const BoxDecoration(
              color: FlixieColors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border(
                top: BorderSide(color: FlixieColors.tabBarBorder),
                right: BorderSide(color: FlixieColors.tabBarBorder),
                bottom: BorderSide(color: FlixieColors.tabBarBorder),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatCount(memberCount),
                  style: const TextStyle(
                    color: FlixieColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'MEMBERS',
                  style: TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pending request preview tile (used in Activity dashboard)
// ---------------------------------------------------------------------------

class _PendingRequestPreviewTile extends StatelessWidget {
  const _PendingRequestPreviewTile({
    required this.request,
    required this.canRespond,
    required this.onRespond,
  });

  final GroupWatchRequest request;
  final bool canRespond;
  final void Function(String status) onRespond;

  @override
  Widget build(BuildContext context) {
    final abbr = (request.requesterUsername?.isNotEmpty == true)
        ? request.requesterUsername![0].toUpperCase()
        : 'R';
    final posterUrl = request.moviePosterPath != null
        ? 'https://image.tmdb.org/t/p/w185${request.moviePosterPath}'
        : null;
    return Container(
      clipBehavior: Clip.hardEdge,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: FlixieColors.primary, width: 3),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Text content
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          FlixieColors.primary.withValues(alpha: 0.2),
                      child: Text(
                        abbr,
                        style: const TextStyle(
                          color: FlixieColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            request.requesterUsername ?? 'Unknown',
                            style: const TextStyle(
                              color: FlixieColors.light,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (request.movieTitle != null)
                            Text(
                              request.movieTitle!,
                              style: const TextStyle(
                                  color: FlixieColors.medium, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (request.message != null &&
                              request.message!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: FlixieColors.primary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: FlixieColors.primary
                                        .withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.chat_bubble_outline,
                                      size: 11, color: FlixieColors.primary),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      request.message!,
                                      style: const TextStyle(
                                        color: FlixieColors.light,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (canRespond) ...[
                      IconButton(
                        onPressed: () => onRespond('DECLINED'),
                        icon: const Icon(Icons.close,
                            color: FlixieColors.danger, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => onRespond('ACCEPTED'),
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: FlixieColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.check,
                              color: FlixieColors.primary, size: 18),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Poster flush to right
            SizedBox(
              width: 80,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: FlixieColors.tabBarBorder,
                            child: const Icon(Icons.movie_outlined,
                                color: FlixieColors.medium),
                          ),
                        )
                      : Container(
                          color: FlixieColors.tabBarBorder,
                          child: const Icon(Icons.movie_outlined,
                              color: FlixieColors.medium),
                        ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          FlixieColors.tabBarBackgroundFocused,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.25],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RequestFilter { all, needsResponse, active, completed, byMe }

class _RequestsTab extends StatefulWidget {
  const _RequestsTab({
    required this.groupId,
    this.conversationId,
    this.initialRequests = const [],
    required this.currentUserId,
    this.isAdmin = false,
    this.onCountChanged,
  });

  final String groupId;
  final String? conversationId;
  final List<GroupWatchRequest> initialRequests;
  final String currentUserId;
  final bool isAdmin;
  final void Function(int count)? onCountChanged;

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  late List<GroupWatchRequest> _requests;
  bool _loading = false;
  final Map<String, bool> _processing = {};
  final Map<String, String> _myResponses = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _RequestFilter _filter = _RequestFilter.active;

  String get _emptyMessage {
    switch (_filter) {
      case _RequestFilter.active:
        return 'No active watch requests';
      case _RequestFilter.needsResponse:
        return 'No requests need your response';
      case _RequestFilter.completed:
        return 'No completed watches yet';
      case _RequestFilter.byMe:
        return "You haven't created any requests yet";
      case _RequestFilter.all:
        return 'No watch requests yet.';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _requests = widget.initialRequests;
    if (_requests.isEmpty) _load();
  }

  @override
  void didUpdateWidget(_RequestsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRequests != oldWidget.initialRequests &&
        widget.initialRequests.isNotEmpty) {
      setState(() => _requests = widget.initialRequests);
    }
    // Reload via the new endpoint as soon as a conversationId becomes available.
    if (widget.conversationId != null &&
        oldWidget.conversationId == null) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final List<GroupWatchRequest> requests;
      final conversationId = widget.conversationId;
      if (conversationId != null) {
        requests = await GroupService.getConversationWatchRequests(
          conversationId,
          userId: widget.currentUserId,
        );
      } else {
        requests = await GroupService.getGroupWatchRequests(widget.groupId);
      }
      if (mounted) {
        setState(() {
          _requests = requests;
          _loading = false;
        });
        widget.onCountChanged?.call(requests.length);
      }
    } catch (e) {
      logger.e('RequestsTab load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<GroupWatchRequest> get _filtered {
    final currentUserId = widget.currentUserId;
    var list = _requests;

    // Apply filter chip
    switch (_filter) {
      case _RequestFilter.active:
        // Active = open + scheduled; hide expired/cancelled by default
        list = list.where((r) => r.isActive).toList();
      case _RequestFilter.needsResponse:
        list = list.where((r) {
          if (!r.canRespond) return false;
          if (r.userId == currentUserId) return false;
          // Check local optimistic response first
          final localResponse = _myResponses[r.id];
          if (localResponse != null) return false;
          // Check server-side current user response
          if (r.currentUserResponse != null) return false;
          // Check memberStatuses
          return !r.memberStatuses.any((s) =>
              s.memberId == currentUserId &&
              (s.status == 'ACCEPTED' ||
                  s.status == 'DECLINED' ||
                  s.status == 'MAYBE'));
        }).toList();
      case _RequestFilter.completed:
        list = list
            .where((r) => r.status == WatchRequestStatus.completed)
            .toList();
      case _RequestFilter.byMe:
        list = list.where((r) => r.userId == currentUserId).toList();
      case _RequestFilter.all:
        // Show everything, including expired and cancelled
        break;
    }

    // Apply search
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) {
        return (r.movieTitle ?? '').toLowerCase().contains(q) ||
            (r.requesterUsername ?? '').toLowerCase().contains(q) ||
            (r.message ?? '').toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  Future<void> _respond(GroupWatchRequest req, String status) async {
    final userId = widget.currentUserId;
    if (userId.isEmpty) return;

    // Prefer the widget-level conversationId; fall back to the one embedded
    // in the request (set when loaded via getConversationWatchRequests).
    final convId = widget.conversationId ?? req.groupId;

    setState(() => _processing[req.id] = true);
    try {
      final decision = WatchResponseDecision.fromString(status);
      try {
        await GroupService.respondToWatchRequest(
            convId, req.id, userId, decision);
      } catch (e) {
        logger.d('New respond endpoint failed, using legacy: $e');
        await GroupService.updateWatchRequestForMember(
            req.id, userId, '', status);
      }
      if (mounted) setState(() => _myResponses[req.id] = status);
      await _load();
    } catch (e) {
      logger.e('Respond to watch request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update request')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(req.id));
    }
  }

  Future<void> _markWatched(GroupWatchRequest req) async {
    final userId = widget.currentUserId;
    final convId = widget.conversationId ?? req.groupId;
    setState(() => _processing[req.id] = true);
    try {
      await GroupService.completeWatchRequest(convId, req.id, userId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '"${req.movieTitle ?? 'Watch request'}" marked as watched!'),
            backgroundColor: FlixieColors.success,
          ),
        );
      }
    } catch (e) {
      logger.e('Mark watched error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark as watched')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(req.id));
    }
  }

  Future<void> _cancelRequest(GroupWatchRequest req) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FlixieColors.tabBarBackground,
        title: const Text('Cancel request?',
            style: TextStyle(color: FlixieColors.white)),
        content: Text(
          'Cancel the watch request for "${req.movieTitle ?? 'this movie'}"?',
          style: const TextStyle(color: FlixieColors.light),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No',
                style: TextStyle(color: FlixieColors.medium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel Request',
                style: TextStyle(color: FlixieColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final userId = widget.currentUserId;
    final convId = widget.conversationId ?? req.groupId;
    setState(() => _processing[req.id] = true);
    try {
      await GroupService.cancelWatchRequest(convId, req.id, userId);
      await _load();
    } catch (e) {
      logger.e('Cancel watch request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel request')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(req.id));
    }
  }

  Future<void> _delete(GroupWatchRequest req) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FlixieColors.tabBarBackground,
        title: const Text('Delete request?',
            style: TextStyle(color: FlixieColors.white)),
        content: Text(
          'Remove the watch request for "${req.movieTitle ?? 'this movie'}"?',
          style: const TextStyle(color: FlixieColors.light),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel',
                style: TextStyle(color: FlixieColors.medium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete',
                style: TextStyle(color: FlixieColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _processing[req.id] = true);
    try {
      await GroupService.deleteWatchRequest(widget.groupId, req.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Watch request for "${req.movieTitle ?? 'this movie'}" removed'),
            backgroundColor: FlixieColors.success,
          ),
        );
      }
    } catch (e) {
      logger.e('Delete watch request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete request. Please try again.'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(req.id));
    }
  }

  Widget _myStatusChip(String label, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Color _statusBorderColor(WatchRequestStatus status) {
    switch (status) {
      case WatchRequestStatus.open:
        return FlixieColors.primary;
      case WatchRequestStatus.scheduled:
        return FlixieColors.secondary;
      case WatchRequestStatus.completed:
        return FlixieColors.success;
      case WatchRequestStatus.expired:
        return FlixieColors.medium;
      case WatchRequestStatus.cancelled:
        return FlixieColors.danger;
    }
  }

  Widget _statusPill(WatchRequestStatus status) {
    final color = _statusBorderColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _filterChip(_RequestFilter f, String label) {
    final selected = _filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = f),
        selectedColor: FlixieColors.primary,
        backgroundColor: FlixieColors.tabBarBackgroundFocused,
        labelStyle: TextStyle(
          color: selected ? Colors.black : FlixieColors.light,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildMemberStatuses(List<GroupRequestMemberStatus> statuses) {
    if (statuses.isEmpty) return const SizedBox.shrink();
    final acceptedCount = statuses.where((s) => s.status == 'ACCEPTED').length;
    final declinedCount = statuses.where((s) => s.status == 'DECLINED').length;
    final maybeCount = statuses.where((s) => s.status == 'MAYBE').length;
    final pendingCount = statuses
        .where((s) =>
            s.status != 'ACCEPTED' &&
            s.status != 'DECLINED' &&
            s.status != 'MAYBE')
        .length;

    return Row(
      children: [
        if (acceptedCount > 0) ...[
          Icon(Icons.check_circle_outline,
              size: 13, color: FlixieColors.success),
          const SizedBox(width: 3),
          Text('$acceptedCount',
              style:
                  const TextStyle(color: FlixieColors.success, fontSize: 12)),
          const SizedBox(width: 10),
        ],
        if (declinedCount > 0) ...[
          Icon(Icons.cancel_outlined, size: 13, color: FlixieColors.danger),
          const SizedBox(width: 3),
          Text('$declinedCount',
              style: const TextStyle(color: FlixieColors.danger, fontSize: 12)),
          const SizedBox(width: 10),
        ],
        if (maybeCount > 0) ...[
          Semantics(
            label: 'Maybe responses',
            child: Icon(Icons.help_outline, size: 13, color: FlixieColors.warning),
          ),
          const SizedBox(width: 3),
          Text('$maybeCount',
              style:
                  const TextStyle(color: FlixieColors.warning, fontSize: 12)),
          const SizedBox(width: 10),
        ],
        if (pendingCount > 0) ...[
          Icon(Icons.schedule, size: 13, color: FlixieColors.medium),
          const SizedBox(width: 3),
          Text('$pendingCount',
              style: const TextStyle(color: FlixieColors.medium, fontSize: 12)),
        ],
      ],
    );
  }

  void _showMemberStatusSheet(BuildContext context, GroupWatchRequest req) {
    // Build a userId -> username map from all known requesters in the list
    final knownNames = <String, String>{};
    for (final r in _requests) {
      if (r.userId.isNotEmpty && r.requesterUsername != null) {
        knownNames[r.userId] = r.requesterUsername!;
      }
    }

    String _name(GroupRequestMemberStatus s) {
      if (s.username != null && s.username!.isNotEmpty) return s.username!;
      if (knownNames.containsKey(s.memberId)) return knownNames[s.memberId]!;
      return s.memberId.substring(0, s.memberId.length.clamp(0, 6));
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: FlixieColors.tabBarBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final accepted =
            req.memberStatuses.where((s) => s.status == 'ACCEPTED').toList();
        final declined =
            req.memberStatuses.where((s) => s.status == 'DECLINED').toList();
        final maybe =
            req.memberStatuses.where((s) => s.status == 'MAYBE').toList();
        final pending = req.memberStatuses
            .where((s) =>
                s.status != 'ACCEPTED' &&
                s.status != 'DECLINED' &&
                s.status != 'MAYBE')
            .toList();

        Widget section(String label, List<GroupRequestMemberStatus> members,
            Color color, IconData icon) {
          if (members.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              ...members.map((s) => Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Text(
                          _name(s).isNotEmpty ? _name(s)[0].toUpperCase() : '?',
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('@${_name(s)}',
                          style: const TextStyle(
                              color: FlixieColors.light, fontSize: 13)),
                    ]),
                  )),
              const SizedBox(height: 12),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FlixieColors.tabBarBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                req.movieTitle ?? 'Watch Request',
                style: const TextStyle(
                    color: FlixieColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text('Member responses',
                  style: const TextStyle(
                      color: FlixieColors.medium, fontSize: 12)),
              const SizedBox(height: 16),
              section('Accepted', accepted, FlixieColors.success,
                  Icons.check_circle_outline),
              section('Declined', declined, FlixieColors.danger,
                  Icons.cancel_outlined),
              section('Maybe', maybe, FlixieColors.warning, Icons.help_outline),
              section('Pending', pending, FlixieColors.medium, Icons.schedule),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) {
        return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
      }
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final displayed = _filtered;

    return RefreshIndicator(
      onRefresh: _load,
      color: FlixieColors.primary,
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: FlixieColors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by movie or member…',
                hintStyle:
                    const TextStyle(color: FlixieColors.medium, fontSize: 14),
                prefixIcon: const Icon(Icons.search,
                    color: FlixieColors.medium, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: FlixieColors.medium, size: 18),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        }),
                      )
                    : null,
                filled: true,
                fillColor: FlixieColors.tabBarBackgroundFocused,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _filterChip(_RequestFilter.active, 'Active'),
                _filterChip(_RequestFilter.needsResponse, 'Needs Response'),
                _filterChip(_RequestFilter.completed, 'Completed'),
                _filterChip(_RequestFilter.byMe, 'By Me'),
                _filterChip(_RequestFilter.all, 'All'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // List
          Expanded(
            child: displayed.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            label: _searchQuery.isNotEmpty
                                ? 'No requests match'
                                : _emptyMessage,
                            child: Icon(
                              _filter == _RequestFilter.completed
                                  ? Icons.movie_outlined
                                  : Icons.inbox_outlined,
                              color: FlixieColors.medium,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No requests match.'
                                : _emptyMessage,
                            style: const TextStyle(color: FlixieColors.medium),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: displayed.length,
                    itemBuilder: (_, i) {
                      final req = displayed[i];
                      final isProcessing = _processing[req.id] == true;
                      final currentUserId = widget.currentUserId;
                      final isMyRequest = req.userId == currentUserId;
                      final canDelete = isMyRequest || widget.isAdmin;
                      final canManage = isMyRequest || widget.isAdmin;

                      // Determine current user's existing status
                      final myStatus = _myResponses[req.id] ??
                          req.currentUserResponse?.apiValue ??
                          req.memberStatuses
                              .where((s) => s.memberId == currentUserId)
                              .map((s) => s.status)
                              .where((s) =>
                                  s == 'ACCEPTED' ||
                                  s == 'DECLINED' ||
                                  s == 'MAYBE')
                              .firstOrNull;

                      final posterUrl = req.moviePosterPath != null
                          ? 'https://image.tmdb.org/t/p/w185${req.moviePosterPath}'
                          : null;

                      return Container(
                        clipBehavior: Clip.hardEdge,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: FlixieColors.tabBarBackgroundFocused,
                          borderRadius: BorderRadius.circular(14),
                          border: Border(
                            left: BorderSide(
                                color: _statusBorderColor(req.status),
                                width: 3),
                          ),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Details (tappable for member status sheet)
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      _showMemberStatusSheet(context, req),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 12, 12, 10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Title + date
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                req.movieTitle ??
                                                    'Watch Request',
                                                style: const TextStyle(
                                                  color: FlixieColors.light,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textScaler:
                                                    TextScaler.noScaling,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatDate(req.createdAt),
                                              style: const TextStyle(
                                                  color: FlixieColors.medium,
                                                  fontSize: 11),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        // Status pill + creator
                                        Row(
                                          children: [
                                            _statusPill(req.status),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'By @${req.requesterUsername ?? 'Unknown'}',
                                                style: const TextStyle(
                                                    color: FlixieColors.medium,
                                                    fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (req.message != null &&
                                            req.message!.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: FlixieColors.primary
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: FlixieColors.primary
                                                      .withValues(alpha: 0.25)),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                    Icons.chat_bubble_outline,
                                                    size: 11,
                                                    color:
                                                        FlixieColors.primary),
                                                const SizedBox(width: 5),
                                                Expanded(
                                                  child: Text(
                                                    req.message!,
                                                    style: const TextStyle(
                                                      color: FlixieColors.light,
                                                      fontSize: 12,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (req.memberStatuses.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          _buildMemberStatuses(
                                              req.memberStatuses),
                                        ],
                                        const SizedBox(height: 10),
                                        // Member response row (for non-requesters on active requests)
                                        if (!isMyRequest && req.canRespond) ...[
                                          Builder(builder: (_) {
                                            if (myStatus == 'ACCEPTED') {
                                              return _myStatusChip(
                                                  'You accepted',
                                                  FlixieColors.success);
                                            }
                                            if (myStatus == 'DECLINED') {
                                              return _myStatusChip(
                                                  'You declined',
                                                  FlixieColors.danger);
                                            }
                                            if (myStatus == 'MAYBE') {
                                              return _myStatusChip(
                                                  'You said maybe',
                                                  FlixieColors.warning);
                                            }
                                            // No response yet — show buttons
                                            if (isProcessing) {
                                              return const Align(
                                                alignment: Alignment.centerLeft,
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: FlixieColors.primary,
                                                  ),
                                                ),
                                              );
                                            }
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Your response',
                                                  style: TextStyle(
                                                    color: FlixieColors.medium,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: OutlinedButton(
                                                        onPressed: () =>
                                                            _respond(req,
                                                                'DECLINED'),
                                                        style: OutlinedButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              FlixieColors
                                                                  .danger,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 7),
                                                          side: BorderSide(
                                                              color: FlixieColors
                                                                  .danger
                                                                  .withValues(
                                                                      alpha:
                                                                          0.45)),
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                          minimumSize:
                                                              Size.zero,
                                                          textStyle:
                                                              const TextStyle(
                                                                  fontSize: 12),
                                                        ),
                                                        child: const Text(
                                                            'Decline'),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: OutlinedButton(
                                                        onPressed: () =>
                                                            _respond(
                                                                req, 'MAYBE'),
                                                        style: OutlinedButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              FlixieColors
                                                                  .warning,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 7),
                                                          side: BorderSide(
                                                              color: FlixieColors
                                                                  .warning
                                                                  .withValues(
                                                                      alpha:
                                                                          0.45)),
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                          minimumSize:
                                                              Size.zero,
                                                          textStyle:
                                                              const TextStyle(
                                                                  fontSize: 12),
                                                        ),
                                                        child: const Text(
                                                            'Maybe'),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: ElevatedButton(
                                                        onPressed: () =>
                                                            _respond(req,
                                                                'ACCEPTED'),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              FlixieColors
                                                                  .primary,
                                                          foregroundColor:
                                                              Colors.black,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 7),
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                          minimumSize:
                                                              Size.zero,
                                                          textStyle:
                                                              const TextStyle(
                                                                  fontSize: 12),
                                                        ),
                                                        child: const Text(
                                                            'Accept'),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          }),
                                        ],
                                        // Creator / admin actions (active requests only)
                                        if (canManage && req.isActive) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              if (isProcessing)
                                                const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: FlixieColors.primary,
                                                  ),
                                                )
                                              else ...[
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    onPressed: () =>
                                                        _markWatched(req),
                                                    icon: const Icon(
                                                        Icons.check_circle_outline,
                                                        size: 14),
                                                    label: const Text(
                                                        'Mark Watched'),
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      foregroundColor:
                                                          FlixieColors.success,
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              vertical: 7),
                                                      side: BorderSide(
                                                          color: FlixieColors
                                                              .success
                                                              .withValues(
                                                                  alpha: 0.45)),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                      minimumSize: Size.zero,
                                                      textStyle:
                                                          const TextStyle(
                                                              fontSize: 12),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    onPressed: () =>
                                                        _cancelRequest(req),
                                                    icon: const Icon(
                                                        Icons.cancel_outlined,
                                                        size: 14),
                                                    label: const Text(
                                                        'Cancel'),
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      foregroundColor:
                                                          FlixieColors.danger,
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              vertical: 7),
                                                      side: BorderSide(
                                                          color: FlixieColors
                                                              .danger
                                                              .withValues(
                                                                  alpha: 0.45)),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                      minimumSize: Size.zero,
                                                      textStyle:
                                                          const TextStyle(
                                                              fontSize: 12),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Poster flush to right with fade
                              SizedBox(
                                width: 90,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    posterUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: posterUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) =>
                                                const _RequestPosterPlaceholder(),
                                            errorWidget: (_, __, ___) =>
                                                const _RequestPosterPlaceholder(),
                                          )
                                        : const _RequestPosterPlaceholder(),
                                    Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            FlixieColors
                                                .tabBarBackgroundFocused,
                                            Colors.transparent,
                                          ],
                                          stops: [0.0, 0.25],
                                        ),
                                      ),
                                    ),
                                    if (canDelete)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: isProcessing
                                              ? null
                                              : () => _delete(req),
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.55),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                                Icons.delete_outline,
                                                color: FlixieColors.danger,
                                                size: 16),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RequestPosterPlaceholder extends StatelessWidget {
  const _RequestPosterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FlixieColors.tabBarBackground,
      child: const Center(
        child: Icon(Icons.movie_outlined, color: FlixieColors.medium, size: 28),
      ),
    );
  }
}
