import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/friendship.dart';
import '../models/group_member.dart';
import '../providers/auth_provider.dart';
import '../services/friend_service.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';

class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final String groupId;
  final String groupName;

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  List<GroupMember> _members = [];
  bool _loading = true;
  String? _currentUserId;
  GroupMember? _myMembership;

  @override
  void initState() {
    super.initState();
    _currentUserId = context.read<AuthProvider>().dbUser?.id;
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await GroupService.getGroupMembers(widget.groupId);
      if (mounted) {
        setState(() {
          _members = members;
          _myMembership = members.cast<GroupMember?>().firstWhere(
                (m) => m?.memberId == _currentUserId,
                orElse: () => null,
              );
          _loading = false;
        });
      }
    } catch (e) {
      logger.e('Members load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isOwner => _myMembership?.isOwner ?? false;
  bool get _isAdmin => _myMembership?.isAdmin ?? false;
  bool get _canManage => _isOwner || _isAdmin;

  Future<void> _changeRole(GroupMember member, String newRole) async {
    try {
      await GroupService.updateRoleOfMemberInGroup(
          widget.groupId, member.memberId, newRole);
      await _load();
    } catch (e) {
      logger.e('Change role error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update role')),
        );
      }
    }
  }

  Future<void> _transferOwnership(GroupMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: FlixieColors.tabBarBackgroundFocused,
        title: const Text('Transfer Ownership',
            style: TextStyle(color: FlixieColors.light)),
        content: Text(
          'Transfer ownership to ${member.displayName}? You will become an admin.',
          style: const TextStyle(color: FlixieColors.medium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: FlixieColors.primary,
                foregroundColor: Colors.black),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await Future.wait([
        GroupService.updateRoleOfMemberInGroup(
            widget.groupId, _currentUserId!, 'ADMIN'),
        GroupService.updateRoleOfMemberInGroup(
            widget.groupId, member.memberId, 'OWNER'),
      ]);
      await _load();
    } catch (e) {
      logger.e('Transfer ownership error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to transfer ownership')),
        );
      }
    }
  }

  Future<void> _removeMember(GroupMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: FlixieColors.tabBarBackgroundFocused,
        title: const Text('Remove Member',
            style: TextStyle(color: FlixieColors.light)),
        content: Text(
          'Remove ${member.displayName} from the group?',
          style: const TextStyle(color: FlixieColors.medium),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await GroupService.removeMember(widget.groupId, member.memberId);
      await _load();
    } catch (e) {
      logger.e('Remove member error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove member')),
        );
      }
    }
  }

  void _showInviteSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InviteMembersSheet(
        groupId: widget.groupId,
        currentMemberIds: _members.map((m) => m.memberId).toList(),
        onInvited: _load,
      ),
    );
  }

  void _showMemberActions(GroupMember member) {
    if (member.memberId == _currentUserId) return;
    final canPromote = _canManage && member.role == 'MEMBER';
    final canDemote = _canManage && member.role == 'ADMIN' && !member.isOwner;
    final canTransfer = _isOwner && member.isAdmin;
    // Owner can remove anyone non-owner; admin can remove plain members
    final canRemove = _isOwner ||
        (_isAdmin && member.role == 'MEMBER');

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
            const SizedBox(height: 4),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                member.displayName,
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (canPromote)
              ListTile(
                leading: const Icon(Icons.arrow_upward,
                    color: FlixieColors.primary),
                title: const Text('Promote to Admin',
                    style: TextStyle(color: FlixieColors.light)),
                onTap: () {
                  Navigator.pop(context);
                  _changeRole(member, 'ADMIN');
                },
              ),
            if (canDemote)
              ListTile(
                leading: const Icon(Icons.arrow_downward,
                    color: FlixieColors.warning),
                title: const Text('Demote to Member',
                    style: TextStyle(color: FlixieColors.light)),
                onTap: () {
                  Navigator.pop(context);
                  _changeRole(member, 'MEMBER');
                },
              ),
            if (canTransfer)
              ListTile(
                leading: const Icon(Icons.swap_horiz,
                    color: FlixieColors.secondary),
                title: const Text('Transfer Ownership',
                    style: TextStyle(color: FlixieColors.light)),
                onTap: () {
                  Navigator.pop(context);
                  _transferOwnership(member);
                },
              ),
            if (canRemove)
              ListTile(
                leading: const Icon(Icons.person_remove_outlined,
                    color: FlixieColors.danger),
                title: const Text('Remove from Group',
                    style: TextStyle(color: FlixieColors.danger)),
                onTap: () {
                  Navigator.pop(context);
                  _removeMember(member);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlixieColors.background,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: FlixieColors.light),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: const TextStyle(
                  color: FlixieColors.light,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            const Text(
              'Members',
              style:
                  TextStyle(color: FlixieColors.medium, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (_canManage)
            TextButton.icon(
              onPressed: _showInviteSheet,
              icon: const Icon(Icons.person_add_outlined,
                  color: FlixieColors.primary, size: 18),
              label: const Text('Invite',
                  style: TextStyle(color: FlixieColors.primary)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? const Center(
                  child: Text('No members found',
                      style: TextStyle(color: FlixieColors.medium)),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: FlixieColors.primary,
                  child: ListView.separated(
                    itemCount: _members.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: FlixieColors.tabBarBorder,
                      indent: 72,
                    ),
                    itemBuilder: (_, i) {
                      final member = _members[i];
                      final isMe = member.memberId == _currentUserId;
                      final canTap =
                          _canManage && !isMe && !member.isOwner;
                      return _MemberTile(
                        member: member,
                        isMe: isMe,
                        showChevron: canTap,
                        onTap: canTap
                            ? () => _showMemberActions(member)
                            : null,
                      );
                    },
                  ),
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Member tile
// ---------------------------------------------------------------------------

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.showChevron,
    this.onTap,
  });

  final GroupMember member;
  final bool isMe;
  final bool showChevron;
  final VoidCallback? onTap;

  Color _roleColor() {
    if (member.isOwner) return FlixieColors.warning;
    if (member.isAdmin) return FlixieColors.primary;
    return FlixieColors.medium;
  }

  String _roleLabel() {
    if (member.isOwner) return 'OWNER';
    if (member.isAdmin) return 'ADMIN';
    return 'MEMBER';
  }

  Color _avatarColor() {
    final hex = member.iconColor?['hexCode'] as String?;
    if (hex != null) {
      try {
        return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
      } catch (_) {}
    }
    return FlixieColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor();
    final initials = member.initials ??
        (member.username?.isNotEmpty == true
            ? member.username![0].toUpperCase()
            : '?');
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: color.withValues(alpha: 0.25),
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            member.displayName,
            style: TextStyle(
              color: isMe ? FlixieColors.primary : FlixieColors.light,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            const Text('(you)',
                style: TextStyle(
                    color: FlixieColors.medium, fontSize: 12)),
          ],
        ],
      ),
      subtitle: member.isPending
          ? const Text('Invite pending',
              style: TextStyle(
                  color: FlixieColors.warning, fontSize: 12))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _roleColor().withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _roleLabel(),
              style: TextStyle(
                color: _roleColor(),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: FlixieColors.medium, size: 16),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invite members sheet
// ---------------------------------------------------------------------------

class _InviteMembersSheet extends StatefulWidget {
  const _InviteMembersSheet({
    required this.groupId,
    required this.currentMemberIds,
    required this.onInvited,
  });

  final String groupId;
  final List<String> currentMemberIds;
  final VoidCallback onInvited;

  @override
  State<_InviteMembersSheet> createState() => _InviteMembersSheetState();
}

class _InviteMembersSheetState extends State<_InviteMembersSheet> {
  List<FriendshipUser> _friends = [];
  final List<String> _selected = [];
  final TextEditingController _search = TextEditingController();
  bool _loading = true;
  bool _inviting = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await FriendService.getFriends(userId);
      if (mounted) {
        setState(() {
          _friends = data.friendships
              .map((f) => f.friendUser)
              .whereType<FriendshipUser>()
              .where((u) => !widget.currentMemberIds.contains(u.id))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite() async {
    if (_selected.isEmpty) return;
    setState(() => _inviting = true);
    try {
      await GroupService.addMembersToGroup(
        widget.groupId,
        _selected
            .map((id) => {
                  'memberId': id,
                  'role': 'MEMBER',
                  'inviteStatus': 'PENDING',
                })
            .toList(),
      );
      widget.onInvited();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      logger.e('Invite members error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send invitations')),
        );
        setState(() => _inviting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase();
    final filtered = _friends.where((f) {
      return f.username.toLowerCase().contains(query) ||
          (f.firstName?.toLowerCase().contains(query) ?? false);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
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
                const Text(
                  'Invite Friends',
                  style: TextStyle(
                    color: FlixieColors.light,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                if (_selected.isNotEmpty)
                  ElevatedButton(
                    onPressed: _inviting ? null : _invite,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlixieColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: _inviting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black),
                          )
                        : Text('Invite (${_selected.length})'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              style: const TextStyle(color: FlixieColors.light),
              decoration: InputDecoration(
                hintText: 'Search friends…',
                hintStyle:
                    const TextStyle(color: FlixieColors.medium),
                prefixIcon: const Icon(Icons.search,
                    color: FlixieColors.medium),
                filled: true,
                fillColor: FlixieColors.tabBarBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _friends.isEmpty
                              ? 'All your friends are already in the group'
                              : 'No friends match your search',
                          style: const TextStyle(
                              color: FlixieColors.medium),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final friend = filtered[i];
                          final selected =
                              _selected.contains(friend.id);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selected.add(friend.id);
                                } else {
                                  _selected.remove(friend.id);
                                }
                              });
                            },
                            title: Text(
                              friend.username,
                              style: const TextStyle(
                                  color: FlixieColors.light),
                            ),
                            subtitle: friend.firstName != null
                                ? Text(
                                    friend.firstName!,
                                    style: const TextStyle(
                                        color: FlixieColors.medium,
                                        fontSize: 12),
                                  )
                                : null,
                            activeColor: FlixieColors.primary,
                            checkColor: Colors.black,
                            secondary: CircleAvatar(
                              backgroundColor: FlixieColors.primary
                                  .withValues(alpha: 0.2),
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
