import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity_list_item.dart';
import '../models/group.dart';
import '../models/group_watch_request.dart';
import '../providers/auth_provider.dart';
import '../screens/profile/activity_tile.dart';
import '../services/friend_service.dart';
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
      final group = await GroupService.getGroup(widget.groupId);
      if (mounted) setState(() {
        _group = group;
        _loadingGroup = false;
      });
    } catch (e) {
      logger.e('GroupDetail load group error: $e');
      if (mounted) setState(() => _loadingGroup = false);
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
        : group.name
            .substring(0, group.name.length.clamp(1, 2))
            .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final groupName = _group?.name ?? '';
    final color = groupName.isNotEmpty ? _groupColor(groupName) : FlixieColors.primary;

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
          tabs: const [
            Tab(text: 'Chat'),
            Tab(text: 'Activity'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ChatTab(groupId: widget.groupId),
          _ActivityTab(),
          _RequestsTab(groupId: widget.groupId),
        ],
      ),
    );
  }

  void _showGroupOptions(BuildContext context) {
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
              leading: const Icon(Icons.info_outline,
                  color: FlixieColors.light),
              title: const Text('Group Info',
                  style: TextStyle(color: FlixieColors.light)),
              onTap: () => Navigator.pop(context),
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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final raw = await GroupService.getGroupMessages(widget.groupId);
      if (mounted) {
        setState(() {
          _messages = raw
              .whereType<Map<String, dynamic>>()
              .toList();
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      logger.e('Load messages error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;

    setState(() => _sending = true);
    _messageController.clear();

    try {
      await GroupService.sendGroupMessage(
        widget.groupId,
        {'userId': userId, 'message': text},
      );
      await _loadMessages();
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
    final currentUserId = context.read<AuthProvider>().dbUser?.id;

    return Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'No messages yet. Start the conversation!',
                        style: TextStyle(color: FlixieColors.medium),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final msg = _messages[i];
                        final senderId =
                            msg['userId']?.toString() ?? '';
                        final isMe = senderId == currentUserId;
                        return _ChatBubble(
                          message: msg['message']?.toString() ?? '',
                          senderUsername:
                              msg['username']?.toString() ?? 'User',
                          isMe: isMe,
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
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                senderUsername,
                style: const TextStyle(
                    color: FlixieColors.medium, fontSize: 11),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? FlixieColors.primary.withValues(alpha: 0.85)
                  : FlixieColors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft:
                    Radius.circular(isMe ? 16 : 4),
                bottomRight:
                    Radius.circular(isMe ? 4 : 16),
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
                  hintStyle:
                      const TextStyle(color: FlixieColors.medium),
                  filled: true,
                  fillColor: FlixieColors.tabBarBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            sending
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FlixieColors.primary),
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
// Activity tab
// ---------------------------------------------------------------------------

class _ActivityTab extends StatefulWidget {
  const _ActivityTab();

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  List<ActivityListItem> _activity = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final items = await FriendService.getFriendsActivityLists(userId);
      if (mounted) {
        setState(() {
          _activity = items;
          _loading = false;
        });
      }
    } catch (e) {
      logger.e('ActivityTab load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_activity.isEmpty) {
      return const Center(
        child: Text('No activity yet.',
            style: TextStyle(color: FlixieColors.medium)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: FlixieColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _activity.length,
        itemBuilder: (_, i) => ActivityTile(item: _activity[i]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Requests tab
// ---------------------------------------------------------------------------

class _RequestsTab extends StatefulWidget {
  const _RequestsTab({required this.groupId});

  final String groupId;

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  List<GroupWatchRequest> _requests = [];
  bool _loading = true;
  // requestId -> status being applied
  final Map<String, bool> _processing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final requests =
          await GroupService.getGroupWatchRequests(widget.groupId);
      if (mounted) {
        setState(() {
          _requests = requests;
          _loading = false;
        });
      }
    } catch (e) {
      logger.e('RequestsTab load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(GroupWatchRequest req, String status) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;

    setState(() => _processing[req.id] = true);
    try {
      await GroupService.updateWatchRequestForMember(
          req.id, userId, '', status);
      await _load();
    } catch (e) {
      logger.e('Respond to watch request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update request')),
        );
        setState(() => _processing.remove(req.id));
      }
    }
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
      if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
    if (_requests.isEmpty) {
      return const Center(
        child: Text('No watch requests yet.',
            style: TextStyle(color: FlixieColors.medium)),
      );
    }

    final currentUserId = context.read<AuthProvider>().dbUser?.id;

    return RefreshIndicator(
      onRefresh: _load,
      color: FlixieColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _requests.length,
        itemBuilder: (_, i) {
          final req = _requests[i];
          final isProcessing = _processing[req.id] == true;

          // Determine current user's existing status
          final myStatus = req.memberStatuses
              .where((s) => s.memberId == currentUserId)
              .map((s) => s.status)
              .firstOrNull;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FlixieColors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FlixieColors.tabBarBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.movie_outlined,
                        color: FlixieColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        req.movieTitle ?? 'Movie request',
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(req.createdAt),
                      style: const TextStyle(
                          color: FlixieColors.medium, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'By ${req.requesterUsername ?? 'Unknown'}',
                  style: const TextStyle(
                      color: FlixieColors.medium, fontSize: 12),
                ),
                if (req.message != null && req.message!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    req.message!,
                    style: const TextStyle(
                        color: FlixieColors.light, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 10),
                if (myStatus == 'ACCEPTED')
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Chip(
                      label: Text('Accepted',
                          style: TextStyle(
                              color: FlixieColors.success,
                              fontSize: 12)),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(color: FlixieColors.success),
                      padding: EdgeInsets.zero,
                    ),
                  )
                else if (myStatus == 'DECLINED')
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Chip(
                      label: Text('Declined',
                          style: TextStyle(
                              color: FlixieColors.danger,
                              fontSize: 12)),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(color: FlixieColors.danger),
                      padding: EdgeInsets.zero,
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isProcessing)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FlixieColors.primary),
                        )
                      else ...[
                        TextButton(
                          onPressed: () =>
                              _respond(req, 'DECLINED'),
                          style: TextButton.styleFrom(
                            foregroundColor: FlixieColors.danger,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Decline'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () =>
                              _respond(req, 'ACCEPTED'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FlixieColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                            textStyle:
                                const TextStyle(fontSize: 13),
                          ),
                          child: const Text('Accept'),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
