import '../widgets/group_members/group_member_actions.dart';
import '../controllers/group_members_controller.dart';
import '../widgets/group_members/group_member_tile.dart';
import '../widgets/group_members/invite_members_sheet.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/load_failure_notice.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';

class GroupMembersScreen extends StatelessWidget {
  const GroupMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final String groupId;
  final String groupName;

  @override
  Widget build(BuildContext context) {
    final accountId =
        context.select<AuthProvider, String?>((a) => a.dbUser?.id);
    return _GroupMembersPage(
        key: ValueKey('$accountId:$groupId'),
        groupId: groupId,
        groupName: groupName,
        accountId: accountId);
  }
}

class _GroupMembersPage extends StatefulWidget {
  const _GroupMembersPage(
      {super.key,
      required this.groupId,
      required this.groupName,
      required this.accountId});
  final String groupId;
  final String groupName;
  final String? accountId;
  @override
  State<_GroupMembersPage> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<_GroupMembersPage> {
  late final GroupMembersController _controller;
  List<GroupMember> get _members => _controller.members;
  bool get _loading => _controller.loading;
  bool get _isCurrent =>
      mounted && context.read<AuthProvider>().dbUser?.id == widget.accountId;
  String? _currentUserId;
  GroupMember? _myMembership;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // null = all, 'PENDING' = pending only
  String? _filterRole;

  @override
  void initState() {
    super.initState();
    _currentUserId = context.read<AuthProvider>().dbUser?.id;
    _searchController.addListener(() {
      setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _controller = GroupMembersController(
        groupId: widget.groupId, accountId: widget.accountId);
    _controller.addListener(_changed);
    _load();
  }

  void _changed() {
    if (_isCurrent) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<GroupMember> get _filtered =>
      _controller.filter(_searchQuery, pendingOnly: _filterRole == 'PENDING');

  Future<void> _load() async {
    if (!_isCurrent) return;
    await _controller.load();
    if (!_isCurrent) return;
    await _updateMembership();
  }

  Future<void> _updateMembership() async {
    if (!_isCurrent) return;
    setState(() {
      _myMembership =
          _members.where((m) => m.memberId == _currentUserId).firstOrNull;
    });
  }

  bool get _isOwner => _myMembership?.isOwner ?? false;
  bool get _isAdmin => _myMembership?.isAdmin ?? false;
  bool get _canManage => _isOwner || _isAdmin;

  Future<void> _changeRole(GroupMember member, String newRole) async {
    if (!_isCurrent) return;
    try {
      await GroupService.updateRoleOfMemberInGroup(
          widget.groupId, member.memberId, newRole);
      if (!_isCurrent) return;
      await _controller.reloadAfterMutation();
      await _updateMembership();
    } catch (e) {
      logger.e('Change role error: $e');
      if (mounted && _isCurrent) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to update role')),
        );
      }
    }
  }

  Future<void> _transferOwnership(GroupMember member) async {
    if (!_isCurrent) return;
    final confirm = await showFlixiePromptSheet<bool>(
      context: context,
      builder: (dialogContext) => FlixiePromptSheetContent(
        title: Text('Transfer Ownership',
            style: TextStyle(color: context.colors.light)),
        content: Text(
          'Transfer ownership to ${member.displayName}? You will become an admin.',
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
                backgroundColor: FlixieColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (confirm != true || !_isCurrent) return;
    try {
      await GroupService.updateRoleOfMemberInGroup(
          widget.groupId, member.memberId, 'OWNER');
      if (!_isCurrent) return;
      await _controller.reloadAfterMutation();
      await _updateMembership();
    } catch (e) {
      logger.e('Transfer ownership error: $e');
      if (mounted && _isCurrent) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to transfer ownership')),
        );
      }
    }
  }

  Future<void> _removeMember(GroupMember member) async {
    if (!_isCurrent) return;
    final confirm = await showFlixiePromptSheet<bool>(
      context: context,
      builder: (dialogContext) => FlixiePromptSheetContent(
        title: Text('Remove Member',
            style: TextStyle(color: context.colors.light)),
        content: Text(
          'Remove ${member.displayName} from the group?',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !_isCurrent) return;
    try {
      await GroupService.removeMember(widget.groupId, member.memberId);
      if (!_isCurrent) return;
      await _controller.reloadAfterMutation();
      await _updateMembership();
    } catch (e) {
      logger.e('Remove member error: $e');
      if (mounted && _isCurrent) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to remove member')),
        );
      }
    }
  }

  void _showInviteSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => InviteMembersSheet(
        groupId: widget.groupId,
        currentMemberIds: _members.map((m) => m.memberId).toList(),
        onInvited: () async {
          if (!_isCurrent) return;
          await _controller.reloadAfterMutation();
          await _updateMembership();
        },
        isCurrent: () => _isCurrent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: context.colors.light),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: TextStyle(
                  color: context.colors.light,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            Text(
              'Members',
              style: TextStyle(color: context.colors.medium, fontSize: 12),
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
          ? const ContentListSkeleton()
          : _controller.error != null && _members.isEmpty
              ? LoadFailureNotice(
                  message: 'Couldn’t load group members.', onRetry: _load)
              : Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: context.colors.light),
                        decoration: InputDecoration(
                          hintText: 'Search members…',
                          hintStyle: TextStyle(color: context.colors.medium),
                          prefixIcon:
                              Icon(Icons.search, color: context.colors.medium),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear,
                                      color: context.colors.medium, size: 18),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          filled: true,
                          fillColor: context.colors.tabBarBackgroundFocused,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                    ),
                    // Filter chips
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _filterRole == null,
                            onTap: () => setState(() => _filterRole = null),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Pending',
                            selected: _filterRole == 'PENDING',
                            onTap: () => setState(() => _filterRole =
                                _filterRole == 'PENDING' ? null : 'PENDING'),
                          ),
                        ],
                      ),
                    ),
                    // Member count
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${filtered.length} member${filtered.length == 1 ? '' : 's'}',
                          style: TextStyle(
                              color: context.colors.medium, fontSize: 12),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _members.isEmpty
                          ? Center(
                              child: Text('No members found',
                                  style:
                                      TextStyle(color: context.colors.medium)),
                            )
                          : filtered.isEmpty
                              ? Center(
                                  child: Text('No members match your search',
                                      style: TextStyle(
                                          color: context.colors.medium)),
                                )
                              : RefreshIndicator(
                                  onRefresh: _load,
                                  color: FlixieColors.primary,
                                  child: ListView.separated(
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) => Divider(
                                      height: 1,
                                      color: context.colors.tabBarBorder,
                                      indent: 72,
                                    ),
                                    itemBuilder: (_, i) {
                                      final member = filtered[i];
                                      final isMe =
                                          member.memberId == _currentUserId;
                                      final canTap = _canManage &&
                                          !isMe &&
                                          !member.isOwner;
                                      return GroupMemberTile(
                                        member: member,
                                        isMe: isMe,
                                        showChevron: canTap,
                                        onTap: canTap
                                            ? () => showGroupMemberActions(
                                                context,
                                                member: member,
                                                currentUserId: _currentUserId,
                                                isOwner: _isOwner,
                                                isAdmin: _isAdmin,
                                                changeRole: (role) =>
                                                    _changeRole(member, role),
                                                transfer: () =>
                                                    _transferOwnership(member),
                                                remove: () =>
                                                    _removeMember(member))
                                            : null,
                                      );
                                    },
                                  ),
                                ),
                    ),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FlixiePill.choice(
        label: Text(label), selected: selected, onSelected: (_) => onTap());
  }
}
