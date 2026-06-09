import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/activity_list_item.dart';
import '../models/group.dart';
import '../models/group_member.dart';
import '../models/group_watch_request.dart'
    hide WatchRequestFilter, WatchRequestStatus, WatchResponseDecision;
import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../utils/skeleton.dart';
import 'group_detail/activity_tab.dart';
import 'group_detail/chat_tab.dart';
import 'group_detail/insights_tab.dart';
import 'group_detail/requests_tab.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId, this.initialTab});

  final String groupId;

  /// 0=Chat, 1=Activity, 2=Requests, 3=Insights. Defaults to 1 (Activity).
  final int? initialTab;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  Group? _group;
  bool _loadingGroup = true;
  String? _loadError;
  int _memberCount = 0;
  List<GroupMember> _groupMembers = [];
  List<GroupWatchRequest> _watchRequests = [];
  List<ActivityListItem> _memberActivity = [];
  String? _conversationId;
  // Set by _RequestsTab when it refreshes — overrides the initial computed count.
  int? _pendingCountOverride;

  int get _pendingRequestCount {
    if (_pendingCountOverride != null) return _pendingCountOverride!;
    final userId =
        _group != null ? context.read<AuthProvider>().dbUser?.id : null;
    return _watchRequests.where((r) {
      if (!r.canRespond) return false;
      if (r.userId == userId) return false;
      if (r.currentUserResponse != null) return false;
      if (userId != null &&
          r.memberStatuses.any((s) =>
              s.memberId == userId &&
              (s.status == 'ACCEPTED' ||
                  s.status == 'DECLINED' ||
                  s.status == 'MAYBE'))) {
        return false;
      }
      return true;
    }).length;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab ?? 1,
    );
    _loadGroup();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroup() async {
    setState(() {
      _loadingGroup = true;
      _loadError = null;
    });
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
          _memberCount = members.where((m) => m.isAccepted).length;
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
      if (mounted) {
        setState(() {
          _loadingGroup = false;
          _loadError = 'Couldn\'t load group. Check your connection.';
        });
      }
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: FlixieColors.light, size: 20),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: _loadingGroup
            ? const Text('Loading...',
                style: TextStyle(color: FlixieColors.medium))
            : Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: color.withValues(alpha: 0.24),
                    child: Text(
                      _group != null ? _groupAbbr(_group!) : '',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _group?.name ?? 'Group',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.light,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '$_memberCount member${_memberCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: FlixieColors.light),
            onPressed: () => _showGroupOptions(context),
          ),
        ],
        bottom: _loadingGroup
            ? null
            : TabBar(
                controller: _tabController,
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                indicator: BoxDecoration(
                  color: FlixieColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: FlixieColors.primary.withValues(alpha: 0.45),
                  ),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.white.withValues(alpha: 0.08),
                labelColor: FlixieColors.primary,
                unselectedLabelColor: FlixieColors.medium,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
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
                  const Tab(text: 'Insights'),
                ],
              ),
      ),
      body: _loadingGroup
          ? const Center(
              child: CircularProgressIndicator(color: FlixieColors.primary))
          : _loadError != null
              ? ErrorRetryWidget(
                  message: _loadError!,
                  onRetry: _loadGroup,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    GroupChatTab(groupId: widget.groupId),
                    GroupActivityTab(
                      group: _group,
                      memberCount: _memberCount,
                      groupId: widget.groupId,
                      conversationId: _conversationId,
                      initialRequests: _watchRequests,
                      initialActivity: _memberActivity,
                      onRefresh: _loadGroup,
                    ),
                    GroupRequestsTab(
                      groupId: widget.groupId,
                      conversationId: _conversationId,
                      initialRequests: _watchRequests,
                      currentUserId:
                          context.read<AuthProvider>().dbUser?.id ?? '',
                      isAdmin: () {
                        final uid = context.read<AuthProvider>().dbUser?.id;
                        if (uid == null) return false;
                        if (_group?.ownerId == uid) return true;
                        return _groupMembers.any((m) =>
                            m.memberId == uid && (m.isAdmin || m.isOwner));
                      }(),
                      onCountChanged: (count) {
                        if (mounted) {
                          setState(() => _pendingCountOverride = count);
                        }
                      },
                    ),
                    GroupInsightsTab(groupId: widget.groupId),
                  ],
                ),
    );
  }

  void _showGroupOptions(BuildContext sheetContext) {
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    final isOwner = _group?.ownerId == currentUserId;
    showModalBottomSheet(
      context: sheetContext,
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
                Navigator.pop(sheetContext);
                sheetContext.push(
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
              onTap: () => Navigator.pop(sheetContext),
            ),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: FlixieColors.danger),
                title: const Text('Delete Group',
                    style: TextStyle(color: FlixieColors.danger)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
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
