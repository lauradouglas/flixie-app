import 'package:flixie_app/core/widgets/flixie_refresh.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/social/data/chat_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/profile/data/notification_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_card.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_avatar.dart';
import 'package:flixie_app/features/social/presentation/widgets/invitation_card.dart';
import 'package:flixie_app/features/social/presentation/widgets/social_section_header.dart';

import '../controllers/social_groups_controller.dart';
import 'social_group_controls.dart';
import 'create_group_sheet.dart';

class SocialGroupsView extends StatefulWidget {
  const SocialGroupsView({super.key});

  @override
  State<SocialGroupsView> createState() => _SocialGroupsViewState();
}

class _SocialGroupsViewState extends State<SocialGroupsView> {
  final TextEditingController _searchController = TextEditingController();
  late final SocialGroupsController _controller;
  bool get _loading => _controller.loading;
  List<Group> get _groups => _controller.groups;
  Map<String, GroupMember> get _pendingInvites => _controller.pendingInvites;
  Map<String, int> get _memberCounts => _controller.memberCounts;
  Map<String, List<GroupMember>> get _groupMembers => _controller.groupMembers;
  Map<String, FlixieNotification> get _inviteNotifications =>
      _controller.inviteNotifications;
  String? get _error => _controller.error;
  int _innerTab = 0;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_changed);
    _controller = SocialGroupsController(auth: context.read<AuthProvider>());
    _controller.addListener(_changed);
    _controller.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() => _controller.load();

  Future<void> _respondToInvite(Group group, String status) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || group.id == null || !_busy.add(group.id!)) return;
    bool owns() => mounted && context.read<AuthProvider>().dbUser?.id == userId;
    final notif = _inviteNotifications[group.id];
    final analytics = context.read<AnalyticsController>();
    try {
      await GroupService.updateMemberInviteStatus(group.id!, userId, status);
      if (!owns()) return;
      if (status == 'ACCEPTED') {
        await analytics.groupJoined(
          groupType: group.visibility?.toLowerCase() ?? 'unknown',
          source: 'group',
        );
      }

      // Keep Firestore members in sync immediately after accepting an invite.
      if (status == 'ACCEPTED') {
        try {
          final members = await GroupService.getGroupMembers(group.id!);
          if (!owns()) return;
          final memberIds = members
              .where((m) => m.isAccepted)
              .map((m) => m.memberId)
              .toSet()
              .toList();
          if (!memberIds.contains(userId)) memberIds.add(userId);
          await ChatService.getOrCreateGroupConversation(
            creatorId: userId,
            pgGroupId: group.id!,
            name: group.name,
            memberIds: memberIds,
          );
        } catch (e) {
          logger.w('Invite accepted but Firestore sync failed: $e');
        }
      }

      // Also update the associated GROUP_INVITE notification so it reflects
      // the accept/decline on the notifications screen.
      if (!owns()) return;
      if (notif?.id != null) {
        final action = status == 'ACCEPTED'
            ? FlixieNotification.actionAccepted
            : FlixieNotification.actionDeclined;
        NotificationService.updateNotification(
          notif!.id!,
          action: action,
          read: true,
        ).catchError((e) {
          logger.w('Failed to update GROUP_INVITE notification: $e');
          return const FlixieNotification(userId: '', type: '', message: '');
        });
      }
      if (mounted && owns()) {
        _controller.resolveInvite(group.id!, accepted: status == 'ACCEPTED');
      }
    } catch (e) {
      logger.e('Respond to invite error: $e');
      if (mounted && owns()) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to update invitation')),
        );
      }
    } finally {
      _busy.remove(group.id);
    }
  }

  void _showCreateGroupSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: context.colors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CreateGroupSheet(
        onCreated: (group) {
          if (mounted) _controller.addCreated(group);
        },
      ),
    );
  }

  List<Group> _sortGroups(List<Group> groups) {
    return [...groups]..sort((a, b) {
        final aUpdated = DateTime.tryParse(a.updatedAt ?? '');
        final bUpdated = DateTime.tryParse(b.updatedAt ?? '');
        if (aUpdated != null && bUpdated != null) {
          final byRecent = bUpdated.compareTo(aUpdated);
          if (byRecent != 0) return byRecent;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  List<Group> _filterGroups(List<Group> groups) {
    final query = _searchController.text.trim().toLowerCase();
    final sorted = _sortGroups(groups);
    if (query.isEmpty) return sorted;
    return sorted.where((group) {
      return group.name.toLowerCase().contains(query) ||
          (group.abbreviation ?? '').toLowerCase().contains(query) ||
          (group.description ?? '').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ContentListSkeleton();
    }

    if (_error != null) {
      return FlixieRefresh(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(_error!,
                    style: TextStyle(color: context.colors.medium)),
              ),
            ),
          ],
        ),
      );
    }

    final pendingGroups =
        _groups.where((g) => _pendingInvites.containsKey(g.id)).toList();
    final myGroups =
        _groups.where((g) => !_pendingInvites.containsKey(g.id)).toList();

    return Column(
      children: [
        Expanded(
          child: FlixieRefresh(
            onRefresh: _load,
            color: FlixieColors.primary,
            child: _innerTab == 1
                ? _buildRequestsTab(pendingGroups)
                : _buildMyGroupsTab(pendingGroups, myGroups),
          ),
        ),
      ],
    );
  }

  Widget _buildMyGroupsTab(List<Group> pendingGroups, List<Group> myGroups) {
    final sortedGroups = _sortGroups(myGroups);
    final displayedGroups = _filterGroups(myGroups);
    final recentGroups = sortedGroups.take(8).toList();
    final isSearching = _searchController.text.trim().isNotEmpty;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final actions = <Widget>[
              OutlinedButton.icon(
                onPressed: _showCreateGroupSheet,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Create'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.primaryText,
                  side: const BorderSide(color: FlixieColors.primary),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: pendingGroups.isNotEmpty,
                label: Text(pendingGroups.length > 99
                    ? '99+'
                    : '${pendingGroups.length}'),
                backgroundColor: FlixieColors.notificationBadge,
                textColor: FlixieColors.onNotificationBadge,
                textStyle:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                child: IconButton.filledTonal(
                  onPressed: () => setState(() => _innerTab = 1),
                  icon: const Icon(Icons.notifications_none_rounded),
                  color: context.colors.light,
                  style: IconButton.styleFrom(
                    backgroundColor: context.colors.surfaceElevated,
                    minimumSize: const Size(50, 50),
                  ),
                ),
              ),
            ];
            final reflow = constraints.maxWidth < 280 ||
                (constraints.maxWidth < 420 &&
                    MediaQuery.textScalerOf(context).scale(14) > 18);
            if (reflow) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GroupSearchField(controller: _searchController),
                    const SizedBox(height: 10),
                    Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: actions),
                  ]);
            }
            return Row(children: [
              Expanded(child: GroupSearchField(controller: _searchController)),
              const SizedBox(width: 10),
              ...actions,
            ]);
          }),
          const SizedBox(height: 18),
          if (recentGroups.isNotEmpty) ...[
            const SocialSectionHeader(title: 'RECENT GROUPS'),
            const SizedBox(height: 8),
            SizedBox(
              height: 80 + MediaQuery.textScalerOf(context).scale(11) * 3,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentGroups.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final g = recentGroups[i];
                  return GestureDetector(
                    onTap: () async {
                      final deleted =
                          await context.push<bool>('/groups/${g.id}');
                      if (mounted && deleted == true) await _load();
                    },
                    child: Column(
                      children: [
                        GroupAvatar(group: g, radius: 34),
                        const SizedBox(height: 7),
                        SizedBox(
                          width: 72,
                          child: Text(
                            g.abbreviation?.isNotEmpty == true
                                ? g.abbreviation!
                                : g.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.colors.medium,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (pendingGroups.isNotEmpty) ...[
            GroupInviteBanner(
              group: pendingGroups.first,
              count: pendingGroups.length,
              onView: () => setState(() => _innerTab = 1),
            ),
            const SizedBox(height: 20),
          ],
          const Row(
            children: [
              Expanded(
                child: SocialSectionHeader(title: 'YOUR GROUPS'),
              ),
              FlixiePill.label(label: Text('Most active')),
            ],
          ),
          const SizedBox(height: 8),
          if (displayedGroups.isEmpty)
            NoGroupsCard(
              isSearching: isSearching,
              onCreateGroup: _showCreateGroupSheet,
            )
          else
            ...displayedGroups.map((g) => GroupCard(
                  group: g,
                  memberCount: _memberCounts[g.id],
                  members: _groupMembers[g.id] ?? const [],
                  statusLabel: _pendingInvites.containsKey(g.id)
                      ? 'Invite pending'
                      : _groupFreshnessLabel(g),
                  onTap: () async {
                    final deleted = await context.push<bool>('/groups/${g.id}');
                    if (mounted && deleted == true) await _load();
                  },
                )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRequestsTab(List<Group> pendingGroups) {
    if (pendingGroups.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: NoGroupInvitesCard(onCreateGroup: _showCreateGroupSheet),
      );
    }
    final sortedPending = _sortGroups(pendingGroups);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _innerTab = 0),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Your groups'),
          ),
          const SizedBox(height: 8),
          PendingGroupInviteSummary(count: sortedPending.length),
          const SizedBox(height: 12),
          ...sortedPending.map((g) => GroupInvitationCard(
                group: g,
                invitedByUsername: _inviteNotifications[g.id]?.senderName,
                onAccept: () => _respondToInvite(g, 'ACCEPTED'),
                onDecline: () => _respondToInvite(g, 'DECLINED'),
              )),
        ],
      ),
    );
  }

  String _groupFreshnessLabel(Group group) {
    final updated = DateTime.tryParse(group.updatedAt ?? '');
    if (updated == null) return 'Community';
    final diff = DateTime.now().difference(updated);
    if (diff.inHours < 24) return 'Active today';
    if (diff.inDays < 7) return 'Active this week';
    return 'Community';
  }
}
