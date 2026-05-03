import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/group.dart';
import '../../models/group_member.dart';
import '../../models/notification.dart';
import '../../providers/auth_provider.dart';
import '../../services/group_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import 'create_group_sheet.dart';
import 'group_card.dart';
import 'invitation_card.dart';
import 'section_header.dart';

class GroupsSubView extends StatefulWidget {
  const GroupsSubView();

  @override
  State<GroupsSubView> createState() => _GroupsSubViewState();
}

class _GroupsSubViewState extends State<GroupsSubView> {
  bool _loading = true;
  List<Group> _groups = [];
  final Map<String, GroupMember> _pendingInvites = {};
  final Map<String, int> _memberCounts = {};
  final Map<String, FlixieNotification> _inviteNotifications = {};
  int _innerTab = 0;
  String? _error;

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
      // Fetch groups and notifications in parallel
      final topResults = await Future.wait<Object>([
        GroupService.getUserGroups(userId),
        NotificationService.getNotifications(userId)
            .catchError((_) => <FlixieNotification>[]),
      ]);
      final groups = topResults[0] as List<Group>;
      final allNotifications = topResults[1] as List<FlixieNotification>;

      // Build map of groupId -> pending GROUP_INVITE notification.
      final inviteNotifs = <String, FlixieNotification>{};
      final notifOnlyGroups = <Group>[];
      for (final notif in allNotifications) {
        if (notif.type == FlixieNotification.groupInvite &&
            notif.action != FlixieNotification.actionAccepted &&
            notif.action != FlixieNotification.actionDeclined) {
          final groupId = notif.groupInviteGroupId;
          if (groupId == null) continue;
          inviteNotifs[groupId] = notif;
          if (!groups.any((g) => g.id == groupId)) {
            final name = notif.groupInviteGroupName ?? 'Invited Group';
            notifOnlyGroups.add(Group(id: groupId, name: name, ownerId: ''));
          }
        }
      }

      // Combine confirmed groups with notification-only invited groups.
      final allGroups = [...groups, ...notifOnlyGroups];

      final pendingInvites = <String, GroupMember>{
        for (final g in notifOnlyGroups)
          g.id!: GroupMember(
            groupId: g.id!,
            memberId: userId,
            role: 'MEMBER',
            inviteStatus: 'PENDING',
          ),
      };
      final memberCounts = <String, int>{};
      final groupsWithId = groups.where((g) => g.id != null).toList();
      final memberResults = await Future.wait(
        groupsWithId.map(
          (g) => GroupService.getGroupMembers(g.id!)
              .catchError((_) => <GroupMember>[]),
        ),
      );
      for (var i = 0; i < groupsWithId.length; i++) {
        final group = groupsWithId[i];
        final members = memberResults[i];
        memberCounts[group.id!] = members.where((m) => m.isAccepted).length;
        final myMembership = members.firstWhere(
          (m) => m.memberId == userId,
          orElse: () => GroupMember(
            groupId: group.id!,
            memberId: userId,
            role: 'MEMBER',
            inviteStatus: null,
          ),
        );
        if (myMembership.isPending) {
          pendingInvites[group.id!] = myMembership;
        }
      }

      if (mounted) {
        setState(() {
          _groups = allGroups;
          _pendingInvites
            ..clear()
            ..addAll(pendingInvites);
          _memberCounts
            ..clear()
            ..addAll(memberCounts);
          _inviteNotifications
            ..clear()
            ..addAll(inviteNotifs);
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      logger.e('GroupsSubView load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load groups.';
        });
      }
    }
  }

  Future<void> _respondToInvite(Group group, String status) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || group.id == null) return;
    try {
      await GroupService.updateMemberInviteStatus(group.id!, userId, status);
      // Also update the associated GROUP_INVITE notification so it reflects
      // the accept/decline on the notifications screen.
      final notif = _inviteNotifications[group.id];
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
      if (mounted) {
        setState(() {
          _pendingInvites.remove(group.id);
          _inviteNotifications.remove(group.id);
          if (status == 'DECLINED') {
            _groups.removeWhere((g) => g.id == group.id);
          }
        });
      }
    } catch (e) {
      logger.e('Respond to invite error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update invitation')),
        );
      }
    }
  }

  void _showCreateGroupSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CreateGroupSheet(
        onCreated: (group) {
          if (mounted) setState(() => _groups.add(group));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child:
            Text(_error!, style: const TextStyle(color: FlixieColors.medium)),
      );
    }

    final pendingGroups =
        _groups.where((g) => _pendingInvites.containsKey(g.id)).toList();
    final myGroups =
        _groups.where((g) => !_pendingInvites.containsKey(g.id)).toList();

    return Column(
      children: [
        _GroupsTabBar(
          selectedIndex: _innerTab,
          pendingCount: pendingGroups.length,
          onChanged: (i) => setState(() => _innerTab = i),
        ),
        Expanded(
          child: _innerTab == 1
              ? _buildDiscoverTab()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: FlixieColors.primary,
                  child: _innerTab == 2
                      ? _buildRequestsTab(pendingGroups)
                      : _buildMyGroupsTab(pendingGroups, myGroups),
                ),
        ),
      ],
    );
  }

  Widget _buildMyGroupsTab(List<Group> pendingGroups, List<Group> myGroups) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pendingGroups.isNotEmpty) ...[
            SocialSectionHeader(
              title: 'PENDING INVITATIONS',
              rightLabel: '${pendingGroups.length} REQUESTS',
            ),
            const SizedBox(height: 10),
            ...pendingGroups.map((g) => GroupInvitationCard(
                  group: g,
                  invitedByUsername: _inviteNotifications[g.id]?.senderName,
                  onAccept: () => _respondToInvite(g, 'ACCEPTED'),
                  onDecline: () => _respondToInvite(g, 'DECLINED'),
                )),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              const Expanded(
                child: SocialSectionHeader(title: 'MY COMMUNITIES'),
              ),
              TextButton(
                onPressed: _showCreateGroupSheet,
                style: TextButton.styleFrom(
                  foregroundColor: FlixieColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: const Text(
                  'CREATE NEW +',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (myGroups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  "You're not in any groups yet.",
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: FlixieColors.medium),
                ),
              ),
            )
          else
            ...myGroups.map((g) => GroupCard(
                  group: g,
                  memberCount: _memberCounts[g.id],
                )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Discover groups\ncoming soon',
          textAlign: TextAlign.center,
          style: TextStyle(color: FlixieColors.medium, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildRequestsTab(List<Group> pendingGroups) {
    if (pendingGroups.isEmpty) {
      return const Center(
        child: Text(
          'No pending invitations',
          style: TextStyle(color: FlixieColors.medium),
        ),
      );
    }
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: pendingGroups
            .map((g) => GroupInvitationCard(
                  group: g,
                  invitedByUsername: _inviteNotifications[g.id]?.senderName,
                  onAccept: () => _respondToInvite(g, 'ACCEPTED'),
                  onDecline: () => _respondToInvite(g, 'DECLINED'),
                ))
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Groups inner tab bar
// ---------------------------------------------------------------------------

class _GroupsTabBar extends StatelessWidget {
  const _GroupsTabBar({
    required this.selectedIndex,
    required this.pendingCount,
    required this.onChanged,
  });

  final int selectedIndex;
  final int pendingCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          _tab(0, 'My Groups'),
          const SizedBox(width: 8),
          _tab(1, 'Discover'),
          const SizedBox(width: 8),
          _tab(2, 'Requests'),
        ],
      ),
    );
  }

  Widget _tab(int index, String label) {
    final selected = index == selectedIndex;
    final showBadge = index == 2 && pendingCount > 0;
    return GestureDetector(
      onTap: () => onChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? FlixieColors.primary
              : FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? FlixieColors.primary : FlixieColors.tabBarBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : FlixieColors.medium,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (showBadge) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: FlixieColors.success,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pendingCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
