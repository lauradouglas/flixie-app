import '../widgets/group_detail/group_detail_tabs.dart';
import '../widgets/group_detail/group_deletion_overlay.dart';
import 'dart:async';
import '../controllers/group_detail_controller.dart';
import '../widgets/group_detail/group_detail_title.dart';
import '../widgets/group_detail/group_detail_options.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/shared/watch_plan_components.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_watch_request.dart'
    hide WatchRequestFilter, WatchRequestStatus, WatchResponseDecision;
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_detail_activity_tab.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_tab.dart';
import 'package:flixie_app/features/social/presentation/widgets/insights_tab.dart';
import 'package:flixie_app/features/watch_plans/presentation/pages/group_watch_plan_v2_screen.dart';

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

  late GroupDetailController _detail;
  AuthProvider? _auth;
  bool _deletingGroup = false;
  String? _planBackdrop;
  int? _pendingCountOverride;
  Group? get _group => _detail.group;
  bool get _loadingGroup => _detail.loading;
  String? get _loadError => _detail.error;
  int get _memberCount => _detail.memberCount;
  List<GroupWatchRequest> get _watchRequests => _detail.requests;
  void _onPlanTabChanged() {
    if (mounted) setState(() {});
  }

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
      initialIndex: (widget.initialTab ?? 1).clamp(0, 3),
    );
    _tabController.addListener(_onPlanTabChanged);
  }

  @override
  void didUpdateWidget(covariant GroupDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) _bindOwner();
    final nextTab = widget.initialTab;
    if (nextTab != null &&
        nextTab != _tabController.index &&
        nextTab >= 0 &&
        nextTab < _tabController.length) {
      _tabController.animateTo(nextTab);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    if (_auth == null ||
        !identical(_auth, auth) ||
        _detail.accountId != auth.dbUser?.id) {
      _auth = auth;
      _bindOwner();
    }
  }

  void _bindOwner() {
    if (_auth == null) return;
    if (_hasOwner) {
      _detail.removeListener(_onDetailChanged);
      _detail.dispose();
    }
    final account = _auth!.dbUser?.id;
    final groupId = widget.groupId;
    _detail = GroupDetailController(
      groupId: groupId,
      accountId: account,
      isCurrent: () =>
          mounted && widget.groupId == groupId && _auth?.dbUser?.id == account,
      fetchRequests: context.read<WatchRequestCache>().refreshGroup,
    );
    _hasOwner = true;
    _planBackdrop = null;
    _pendingCountOverride = null;
    _deletingGroup = false;
    _detail.addListener(_onDetailChanged);
    unawaited(_detail.load());
  }

  bool _hasOwner = false;

  void _onDetailChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadGroup() async {
    final owner = _detail;
    await owner.load();
    if (mounted && identical(owner, _detail) && owner.current) {
      setState(() => _pendingCountOverride = null);
    }
  }

  @override
  void dispose() {
    _detail.removeListener(_onDetailChanged);
    _detail.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = _detail;
    final planBackdrop = _tabController.index == 2 ? _planBackdrop : null;

    return PopScope(
      canPop: !_deletingGroup,
      child: Stack(
        children: [
          if (planBackdrop != null)
            Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 560 + MediaQuery.paddingOf(context).top,
                child: WatchPlanBackdrop(path: planBackdrop)),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
              backgroundColor: planBackdrop == null
                  ? context.colors.background
                  : Colors.transparent,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              elevation: 0,
              leading: FlixieBackButton(enabled: !_deletingGroup),
              titleSpacing: 0,
              title: GroupDetailTitle(
                  group: _group,
                  loading: _loadingGroup,
                  memberCount: _memberCount),
              actions: [
                IconButton(
                  icon: Icon(Icons.more_vert, color: context.colors.light),
                  onPressed: _deletingGroup || _group == null
                      ? null
                      : () => _showGroupOptions(context),
                ),
              ],
              bottom: _loadingGroup
                  ? null
                  : GroupDetailTabs(
                      controller: _tabController,
                      pendingCount: _pendingRequestCount),
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
                        key: ObjectKey(owner),
                        controller: _tabController,
                        children: [
                          ListenableBuilder(
                            listenable: _tabController,
                            builder: (context, child) => GroupChatTab(
                              groupId: widget.groupId,
                              active: _tabController.index == 0 &&
                                  !_tabController.indexIsChanging,
                            ),
                          ),
                          GroupActivityTab(
                            active: _tabController.index == 1 &&
                                !_tabController.indexIsChanging,
                            group: _group,
                            memberCount: _memberCount,
                            groupId: widget.groupId,
                            initialRequests: _watchRequests,
                            initialActivity: const [],
                            groupLists: _detail.lists,
                            listsLoading: _detail.listsLoading,
                            listsFailed: _detail.listsFailed,
                            onRefresh: _loadGroup,
                          ),
                          GroupWatchPlanV2Screen(
                            groupId: widget.groupId,
                            groupName: _group?.name,
                            initialRequestId: widget.initialRequestId,
                            embedded: true,
                            onBackdropChanged: (path) {
                              if (mounted &&
                                  identical(owner, _detail) &&
                                  owner.current &&
                                  path != _planBackdrop) {
                                setState(() => _planBackdrop = path);
                              }
                            },
                            onCountChanged: (count) {
                              if (mounted &&
                                  identical(owner, _detail) &&
                                  owner.current) {
                                setState(() => _pendingCountOverride = count);
                              }
                            },
                          ),
                          GroupInsightsTab(groupId: widget.groupId),
                        ],
                      ),
          ),
          if (_deletingGroup)
            const Positioned.fill(child: GroupDeletionOverlay()),
        ],
      ),
    );
  }

  Future<void> _showGroupOptions(BuildContext pageContext) async {
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    final isOwner = _group?.ownerId == currentUserId;
    final owner = _detail;
    final action = await showGroupDetailOptions(pageContext, isOwner: isOwner);

    if (!mounted || !identical(owner, _detail) || !owner.current) return;
    if (action == 'members') {
      context.push(
        '/groups/${widget.groupId}/members',
        extra: _group?.name ?? 'Group',
      );
      return;
    }
    if (action != 'delete') return;

    final confirm = await showFlixiePromptSheet<bool>(
      context: context,
      builder: (dialogContext) => FlixiePromptSheetContent(
        title:
            Text('Delete Group', style: TextStyle(color: context.colors.light)),
        content: Text(
          'Permanently delete this group, its lists, requests, '
          'chat messages and shared chat images? This cannot be undone.',
          style: TextStyle(color: context.colors.medium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.danger,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true ||
        !mounted ||
        !identical(owner, _detail) ||
        !owner.current) {
      return;
    }

    setState(() => _deletingGroup = true);
    try {
      await GroupService.deleteGroup(owner.groupId);
      if (!mounted || !identical(owner, _detail) || !owner.current) return;
      final auth = context.read<AuthProvider>();
      final cachedGroups = auth.cachedGroups;
      if (cachedGroups != null) {
        auth.updateCachedGroups(cachedGroups
            .where((group) => group.id != widget.groupId)
            .toList(growable: false));
      }
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
          type: FlixieToastType.success,
          content: const Text('Group deleted permanently.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop(true);
    } catch (e) {
      logger.e('Delete group error: $e');
      if (mounted && identical(owner, _detail) && owner.current) {
        setState(() => _deletingGroup = false);
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content: const Text(
              'Could not delete the group. Nothing was removed. Please try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
