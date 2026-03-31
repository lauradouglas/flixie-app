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
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';

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
      backgroundColor: FlixieColors.background,
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
          _SegmentedToggle(
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
// Segmented toggle
// ---------------------------------------------------------------------------

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({
    required this.selectedIndex,
    required this.labels,
    required this.onChanged,
  });

  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: FlixieColors.tabBarBorder),
        ),
        child: Row(
          children: List.generate(labels.length, (i) {
            final selected = i == selectedIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: selected
                        ? FlixieColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(27),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: selected ? Colors.black : FlixieColors.medium,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
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
        child: Text(_error!,
            style: const TextStyle(color: FlixieColors.medium)),
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
              _SectionHeader(
                title: 'PENDING REQUESTS',
                badge: data.pendingFriends.length,
              ),
              const SizedBox(height: 8),
              ...data.pendingFriends.map(
                (f) => _PendingFriendCard(
                  friendship: f,
                  onAccept: () => _acceptRequest(f),
                  onDecline: () => _declineRequest(f),
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
            _SectionHeader(title: 'FRIENDS ACTIVITY'),
            const SizedBox(height: 8),
            if (_activity.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No recent activity.',
                  style: textTheme.bodySmall
                      ?.copyWith(color: FlixieColors.medium),
                ),
              )
            else
              ...(_activity.map((item) => ActivityTile(item: item))),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PendingFriendCard extends StatelessWidget {
  const _PendingFriendCard({
    required this.friendship,
    required this.onAccept,
    required this.onDecline,
  });

  final Friendship friendship;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  Color _avatarColor() {
    final hex =
        friendship.friendUser?.iconColor?['hexCode'] as String?;
    if (hex != null) {
      try {
        return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
      } catch (_) {}
    }
    return FlixieColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final user = friendship.friendUser;
    final color = _avatarColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlixieColors.tabBarBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.3),
            child: Text(
              user?.initials ??
                  (user?.username.isNotEmpty == true
                      ? user!.username[0].toUpperCase()
                      : '?'),
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user?.username ?? 'Unknown',
              style: const TextStyle(
                  color: FlixieColors.light, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: onDecline,
            style: TextButton.styleFrom(
              foregroundColor: FlixieColors.danger,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: const Text('Decline'),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: onAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: FlixieColors.primary,
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: const Text('Accept'),
          ),
        ],
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
  // groupId -> members with pending invite for current user
  final Map<String, GroupMember> _pendingInvites = {};
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
      final groups = await GroupService.getUserGroups(userId);

      // Check for pending invites in each group
      final pendingInvites = <String, GroupMember>{};
      for (final group in groups) {
        if (group.id == null) continue;
        try {
          final members = await GroupService.getGroupMembers(group.id!);
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
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _groups = groups;
          _pendingInvites
            ..clear()
            ..addAll(pendingInvites);
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
      await GroupService.updateMemberInviteStatus(
          group.id!, userId, status);
      if (mounted) {
        setState(() {
          _pendingInvites.remove(group.id);
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
        child: Text(_error!,
            style: const TextStyle(color: FlixieColors.medium)),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final pendingGroups =
        _groups.where((g) => _pendingInvites.containsKey(g.id)).toList();
    final myGroups =
        _groups.where((g) => !_pendingInvites.containsKey(g.id)).toList();

    return RefreshIndicator(
      onRefresh: _load,
      color: FlixieColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pending invitations
            if (pendingGroups.isNotEmpty) ...[
              _SectionHeader(
                title: 'PENDING INVITATIONS',
                badge: pendingGroups.length,
              ),
              const SizedBox(height: 8),
              ...pendingGroups.map(
                (g) => _InvitationCard(
                  group: g,
                  onAccept: () => _respondToInvite(g, 'ACCEPTED'),
                  onDecline: () => _respondToInvite(g, 'DECLINED'),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // My groups
            Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: FlixieColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'MY GROUPS',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _showCreateGroupSheet,
                  style: TextButton.styleFrom(
                    foregroundColor: FlixieColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: const Text(
                    'CREATE NEW +',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
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
                    style: textTheme.bodyMedium
                        ?.copyWith(color: FlixieColors.medium),
                  ),
                ),
              )
            else
              ...myGroups.map((g) => _GroupCard(group: g)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.group,
    required this.onAccept,
    required this.onDecline,
  });

  final Group group;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlixieColors.tabBarBorder),
      ),
      child: Row(
        children: [
          _GroupAvatar(group: group, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                      color: FlixieColors.light,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  'You have been invited',
                  style: const TextStyle(
                      color: FlixieColors.medium, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onDecline,
            style: TextButton.styleFrom(
              foregroundColor: FlixieColors.danger,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: const Text('Decline'),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: onAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: FlixieColors.primary,
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/groups/${group.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlixieColors.tabBarBorder),
        ),
        child: Row(
          children: [
            _GroupAvatar(group: group, radius: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      color: FlixieColors.light,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (group.memberCount != null)
                    Text(
                      '${group.memberCount} member${group.memberCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: FlixieColors.medium, fontSize: 12),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: FlixieColors.medium),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Group avatar helper
// ---------------------------------------------------------------------------

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.group, this.radius = 24});

  final Group group;
  final double radius;

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

  String get _abbr {
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
    return CircleAvatar(
      radius: radius,
      backgroundColor: _color.withValues(alpha: 0.3),
      child: Text(
        _abbr,
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
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
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _abbrController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;

    setState(() => _submitting = true);
    try {
      final group = await GroupService.createGroup({
        'name': _nameController.text.trim(),
        if (_abbrController.text.trim().isNotEmpty)
          'abbreviation': _abbrController.text.trim(),
        if (_descController.text.trim().isNotEmpty)
          'description': _descController.text.trim(),
        'visibility': _isPublic ? 'PUBLIC' : 'PRIVATE',
        'ownerId': userId,
      });
      widget.onCreated?.call(group);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      logger.e('Create group error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create group')),
        );
        setState(() => _submitting = false);
      }
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
      builder: (_, scrollController) => SingleChildScrollView(
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
                  _VisibilityChip(
                    label: 'Public',
                    selected: _isPublic,
                    onTap: () => setState(() => _isPublic = true),
                  ),
                  const SizedBox(width: 10),
                  _VisibilityChip(
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
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlixieColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Create Group',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
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
          borderSide:
              const BorderSide(color: FlixieColors.tabBarBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: FlixieColors.tabBarBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: FlixieColors.primary),
        ),
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? FlixieColors.primary
              : FlixieColors.tabBarBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? FlixieColors.primary
                : FlixieColors.tabBarBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : FlixieColors.medium,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.badge});

  final String title;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: FlixieColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: FlixieColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$badge',
              style: const TextStyle(
                  color: FlixieColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }
}
