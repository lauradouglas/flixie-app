import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/activity_list_item.dart';
import '../models/friendship.dart';
import '../models/group.dart';
import '../models/group_member.dart';
import '../providers/auth_provider.dart';
import '../screens/profile/activity_tile.dart';
import '../screens/profile/friends_row.dart';
import '../services/friend_service.dart';
import '../models/notification.dart';
import '../services/group_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import 'social/group_card.dart';
import 'social/invitation_card.dart';
import 'social/pending_friend_card.dart';
import 'social/section_header.dart';
import 'social/segmented_toggle.dart';
import 'social/visibility_chip.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  int _selectedTab = 0; // 0 = Friends, 1 = Groups

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        elevation: 0,
        title: const Text(
          'Social',
          style: TextStyle(
            color: FlixieColors.light,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          SocialSegmentedToggle(
            selectedIndex: _selectedTab,
            labels: const ['Friends', 'Groups'],
            onChanged: (i) => setState(() => _selectedTab = i),
          ),
          Expanded(
            child: _selectedTab == 0
                ? const _FriendsSubView()
                : const _GroupsSubView(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Friends sub-view
// ---------------------------------------------------------------------------

class _FriendsSubView extends StatefulWidget {
  const _FriendsSubView();

  @override
  State<_FriendsSubView> createState() => _FriendsSubViewState();
}

class _FriendsSubViewState extends State<_FriendsSubView> {
  bool _loading = true;
  FriendsData? _friendsData;
  List<ActivityListItem> _activity = [];
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
      final results = await Future.wait([
        FriendService.getFriends(userId),
        FriendService.getFriendsActivityLists(userId),
      ]);
      if (mounted) {
        setState(() {
          _friendsData = results[0] as FriendsData;
          _activity = results[1] as List<ActivityListItem>;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      logger.e('FriendsSubView load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load friends.';
        });
      }
    }
  }

  Future<void> _acceptRequest(Friendship friendship) async {
    try {
      await FriendService.updateRequest(friendship.id, 'ACCEPTED');
      if (mounted) {
        final updated = _friendsData!.copyWith(
          pendingFriends: _friendsData!.pendingFriends
              .where((f) => f.id != friendship.id)
              .toList(),
          friendships: [
            ..._friendsData!.friendships,
            Friendship(
              id: friendship.id,
              friend: friendship.friendUser,
              createdAt: '',
              updatedAt: '',
            ),
          ],
        );
        setState(() => _friendsData = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Now friends with ${friendship.friendUser?.username ?? 'user'}')),
        );
        // Repoll friends activity now that we have a new friend.
        final userId = context.read<AuthProvider>().dbUser?.id;
        if (userId != null) {
          FriendService.getFriendsActivityLists(userId).then((activity) {
            if (mounted) setState(() => _activity = activity);
          }).catchError((_) {});
        }
      }
    } catch (e) {
      logger.e('Accept request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to accept friend request')),
        );
      }
    }
  }

  Future<void> _declineRequest(Friendship friendship) async {
    try {
      await FriendService.updateRequest(friendship.id, 'DECLINED');
      if (mounted) {
        setState(() {
          _friendsData = _friendsData!.copyWith(
            pendingFriends: _friendsData!.pendingFriends
                .where((f) => f.id != friendship.id)
                .toList(),
          );
        });
      }
    } catch (e) {
      logger.e('Decline request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to decline friend request')),
        );
      }
    }
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

    final data = _friendsData;
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _load,
      color: FlixieColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pending requests section
            if (data != null && data.pendingFriends.isNotEmpty) ...[
              SocialSectionHeader(
                title: 'PENDING REQUESTS',
                badge: data.pendingFriends.length,
              ),
              const SizedBox(height: 8),
              ...data.pendingFriends.map(
                (f) => PendingFriendCard(
                  friendship: f,
                  onAccept: () => _acceptRequest(f),
                  onDecline: () => _declineRequest(f),
                  onTap: () {
                    final userId = f.friendUser?.id;
                    if (userId != null) context.push('/friends/$userId');
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Friends section
            if (data != null) ...[
              FriendsRow(
                data: data,
                onFriendsChanged: (updated) =>
                    setState(() => _friendsData = updated),
              ),
              const SizedBox(height: 16),
            ],

            // Activity section
            const SocialSectionHeader(title: 'FRIENDS ACTIVITY'),
            const SizedBox(height: 8),
            if (_activity.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No recent activity.',
                  style:
                      textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activity.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => ActivityTile(item: _activity[i]),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Groups sub-view
// ---------------------------------------------------------------------------

class _GroupsSubView extends StatefulWidget {
  const _GroupsSubView();

  @override
  State<_GroupsSubView> createState() => _GroupsSubViewState();
}

class _GroupsSubViewState extends State<_GroupsSubView> {
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
      builder: (_) => _CreateGroupSheet(
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

// ---------------------------------------------------------------------------
// Create group bottom sheet
// ---------------------------------------------------------------------------

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({this.onCreated});

  final void Function(Group)? onCreated;

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _abbrController = TextEditingController();
  final _descController = TextEditingController();
  bool _isPublic = true;

  // Step 1 — add members (before creation)
  int _step = 0;
  List<FriendshipUser> _friends = [];
  final List<String> _selectedFriendIds = [];
  bool _loadingFriends = false;
  bool _inviting = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _abbrController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    _loadFriendsForInvite(userId);
    setState(() => _step = 1);
  }

  Future<void> _createGroupWithMembers() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    setState(() => _inviting = true);
    try {
      final members = [
        {'memberId': userId, 'role': 'OWNER', 'inviteStatus': 'ACCEPTED'},
        ..._selectedFriendIds.map((id) => {
              'memberId': id,
              'role': 'MEMBER',
              'inviteStatus': 'PENDING',
            }),
      ];
      final group = await GroupService.createGroup({
        'name': _nameController.text.trim(),
        if (_abbrController.text.trim().isNotEmpty)
          'abbreviation': _abbrController.text.trim(),
        if (_descController.text.trim().isNotEmpty)
          'description': _descController.text.trim(),
        'visibility': _isPublic ? 'PUBLIC' : 'PRIVATE',
        'ownerId': userId,
        'members': members,
      });
      widget.onCreated?.call(group);
    } catch (e) {
      logger.e('Create group error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create group')),
        );
        setState(() => _inviting = false);
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _loadFriendsForInvite(String userId) async {
    if (mounted) setState(() => _loadingFriends = true);
    try {
      final data = await FriendService.getFriends(userId);
      if (mounted) {
        setState(() {
          _friends = data.friendships
              .map((f) => f.friendUser)
              .whereType<FriendshipUser>()
              .toList();
          _loadingFriends = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => _step == 0
          ? _buildFormStep(scrollController, textTheme)
          : _buildInviteStep(scrollController),
    );
  }

  Widget _buildFormStep(
      ScrollController scrollController, TextTheme textTheme) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlixieColors.medium.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Create Group',
              style:
                  textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _inputField(
              controller: _nameController,
              label: 'Group Name *',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            _inputField(
              controller: _abbrController,
              label: 'Abbreviation (optional, max 4 chars)',
              maxLength: 4,
            ),
            const SizedBox(height: 14),
            _inputField(
              controller: _descController,
              label: 'Description (optional)',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Visibility',
              style: textTheme.bodyMedium
                  ?.copyWith(color: FlixieColors.light, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                VisibilityChip(
                  label: 'Public',
                  selected: _isPublic,
                  onTap: () => setState(() => _isPublic = true),
                ),
                const SizedBox(width: 10),
                VisibilityChip(
                  label: 'Private',
                  selected: !_isPublic,
                  onTap: () => setState(() => _isPublic = false),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlixieColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Next',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteStep(ScrollController scrollController) {
    final query = _searchController.text.toLowerCase();
    final filtered = _friends.where((f) {
      return f.username.toLowerCase().contains(query) ||
          (f.firstName?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: FlixieColors.medium.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Members',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'to "${_nameController.text}"',
                      style: const TextStyle(
                          color: FlixieColors.medium, fontSize: 13),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _inviting ? null : _createGroupWithMembers,
                child: const Text('Skip',
                    style: TextStyle(color: FlixieColors.medium)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: FlixieColors.light),
            decoration: InputDecoration(
              hintText: 'Search friends…',
              hintStyle: const TextStyle(color: FlixieColors.medium),
              prefixIcon: const Icon(Icons.search, color: FlixieColors.medium),
              filled: true,
              fillColor: FlixieColors.tabBarBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loadingFriends
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Text(
                        _friends.isEmpty
                            ? 'No friends to invite yet'
                            : 'No matches',
                        style: const TextStyle(color: FlixieColors.medium),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final friend = filtered[i];
                        final selected = _selectedFriendIds.contains(friend.id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (val) => setState(() {
                            if (val == true) {
                              _selectedFriendIds.add(friend.id);
                            } else {
                              _selectedFriendIds.remove(friend.id);
                            }
                          }),
                          title: Text(friend.username,
                              style:
                                  const TextStyle(color: FlixieColors.light)),
                          subtitle: friend.firstName != null
                              ? Text(friend.firstName!,
                                  style: const TextStyle(
                                      color: FlixieColors.medium, fontSize: 12))
                              : null,
                          activeColor: FlixieColors.primary,
                          checkColor: Colors.black,
                          secondary: CircleAvatar(
                            backgroundColor:
                                FlixieColors.primary.withValues(alpha: 0.2),
                            child: Text(
                              friend.username[0].toUpperCase(),
                              style: const TextStyle(
                                color: FlixieColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _inviting ? null : _createGroupWithMembers,
              style: ElevatedButton.styleFrom(
                backgroundColor: FlixieColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _inviting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      _selectedFriendIds.isEmpty
                          ? 'Create Group'
                          : 'Create & Invite ${_selectedFriendIds.length}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    int? maxLength,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: FlixieColors.light),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: FlixieColors.medium, fontSize: 13),
        counterStyle: const TextStyle(color: FlixieColors.medium),
        filled: true,
        fillColor: FlixieColors.tabBarBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FlixieColors.tabBarBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FlixieColors.tabBarBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FlixieColors.primary),
        ),
      ),
    );
  }
}
