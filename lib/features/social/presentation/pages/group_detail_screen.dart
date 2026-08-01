import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart'
    hide WatchRequestFilter, WatchRequestStatus, WatchResponseDecision;
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/data/chat_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_detail_activity_tab.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_tab.dart';
import 'package:flixie_app/features/social/presentation/widgets/insights_tab.dart';
import 'package:flixie_app/features/social/presentation/widgets/requests_tab.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/movie_list.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({
    super.key,
    required this.groupId,
    this.initialTab,
    this.initialRequestId,
  });

  final String groupId;

  /// 0=Chat, 1=Activity, 2=Requests, 3=Insights. Defaults to 1 (Activity).
  final int? initialTab;
  final String? initialRequestId;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  Group? _group;
  bool _loadingGroup = true;
  bool _deletingGroup = false;
  String? _loadError;
  int _memberCount = 0;
  List<GroupMember> _groupMembers = [];
  List<GroupWatchRequest> _watchRequests = [];
  List<ActivityListItem> _memberActivity = [];
  List<MovieList> _groupLists = [];
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
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    final requestCache = context.read<WatchRequestCache>();
    final cachedRequests = requestCache.forGroup(widget.groupId);
    setState(() {
      _loadingGroup = true;
      _loadError = null;
      if (cachedRequests.isNotEmpty) _watchRequests = cachedRequests;
    });
    try {
      final results = await Future.wait([
        GroupService.getGroup(widget.groupId),
        GroupService.getGroupMembers(widget.groupId),
        requestCache
            .refreshGroup(widget.groupId)
            .catchError((_) => <GroupWatchRequest>[]),
        GroupService.getGroupActivity(widget.groupId)
            .catchError((_) => <ActivityListItem>[]),
        if (currentUserId != null)
          UserService.getMovieLists(currentUserId)
              .then((lists) => lists
                  .where((list) => list.groupId == widget.groupId)
                  .toList(growable: false))
              .catchError((_) => <MovieList>[])
        else
          Future.value(<MovieList>[]),
      ]);

      if (mounted) {
        setState(() {
          _group = results[0] as Group;
          final members = results[1] as List<GroupMember>;
          _memberCount = members.where((m) => m.isAccepted).length;
          _groupMembers = members;
          _watchRequests = results[2] as List<GroupWatchRequest>;
          _memberActivity = results[3] as List<ActivityListItem>;
          _groupLists = results[4] as List<MovieList>;
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

    return PopScope(
      canPop: !_deletingGroup,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: FlixieColors.background,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: FlixieColors.light, size: 20),
                onPressed: _deletingGroup ? null : () => context.pop(),
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
                          child: SizedBox(
                            width: 27,
                            height: 27,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _group != null ? _groupAbbr(_group!) : '',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
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
                  onPressed:
                      _deletingGroup ? null : () => _showGroupOptions(context),
                ),
              ],
              bottom: _loadingGroup
                  ? null
                  : TabBar(
                      controller: _tabController,
                      isScrollable: false,
                      tabAlignment: TabAlignment.fill,
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                      labelPadding: EdgeInsets.zero,
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
                    child:
                        CircularProgressIndicator(color: FlixieColors.primary))
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
                            groupLists: _groupLists,
                            onRefresh: _loadGroup,
                          ),
                          GroupRequestsTab(
                            groupId: widget.groupId,
                            conversationId: _conversationId,
                            initialRequests: _watchRequests,
                            initialRequestId: widget.initialRequestId,
                            currentUserId:
                                context.read<AuthProvider>().dbUser?.id ?? '',
                            isAdmin: () {
                              final uid =
                                  context.read<AuthProvider>().dbUser?.id;
                              if (uid == null) return false;
                              if (_group?.ownerId == uid) return true;
                              return _groupMembers.any((m) =>
                                  m.memberId == uid &&
                                  (m.isAdmin || m.isOwner));
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
          ),
          if (_deletingGroup) ...[
            const Positioned.fill(
              child: ModalBarrier(
                dismissible: false,
                color: Color(0x99000000),
              ),
            ),
            const Positioned.fill(
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: FlixieColors.primary),
                        SizedBox(height: 14),
                        Text(
                          'Deleting group…',
                          style: TextStyle(
                            color: FlixieColors.light,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Removing lists, requests and messages',
                          style: TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showGroupOptions(BuildContext pageContext) async {
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    final isOwner = _group?.ownerId == currentUserId;
    final action = await showModalBottomSheet<String>(
      context: pageContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => SafeArea(
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
              onTap: () => Navigator.pop(modalContext, 'members'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.info_outline, color: FlixieColors.light),
              title: const Text('Group Info',
                  style: TextStyle(color: FlixieColors.light)),
              onTap: () => Navigator.pop(modalContext),
            ),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: FlixieColors.danger),
                title: const Text('Delete Group',
                    style: TextStyle(color: FlixieColors.danger)),
                onTap: () => Navigator.pop(modalContext, 'delete'),
              ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'members') {
      context.push(
        '/groups/${widget.groupId}/members',
        extra: _group?.name ?? 'Group',
      );
      return;
    }
    if (action != 'delete') return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Group',
            style: TextStyle(color: FlixieColors.light)),
        content: const Text(
          'Permanently delete this group, its lists, requests, '
          'chat messages and shared chat images? This cannot be undone.',
          style: TextStyle(color: FlixieColors.medium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: FlixieColors.danger,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _deletingGroup = true);
    try {
      await GroupService.deleteGroup(widget.groupId);
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final cachedGroups = auth.cachedGroups;
      if (cachedGroups != null) {
        auth.updateCachedGroups(cachedGroups
            .where((group) => group.id != widget.groupId)
            .toList(growable: false));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group deleted permanently.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop(true);
    } catch (e) {
      logger.e('Delete group error: $e');
      if (mounted) {
        setState(() => _deletingGroup = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not delete the group. Nothing was removed. Please try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
