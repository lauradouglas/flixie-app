import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/load_failure_notice.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/core/utils/app_logger.dart';

class InviteMembersSheet extends StatefulWidget {
  const InviteMembersSheet({
    super.key,
    required this.groupId,
    required this.currentMemberIds,
    required this.onInvited,
    required this.isCurrent,
  });

  final String groupId;
  final List<String> currentMemberIds;
  final VoidCallback onInvited;
  final bool Function() isCurrent;

  @override
  State<InviteMembersSheet> createState() => InviteMembersSheetState();
}

class InviteMembersSheetState extends State<InviteMembersSheet> {
  List<FriendshipUser> _friends = [];
  final List<String> _selected = [];
  final TextEditingController _search = TextEditingController();
  bool _loading = true;
  bool _inviting = false;
  String? _loadError;

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
      if (mounted && widget.isCurrent()) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await FriendService.getFriends(userId);
      final memberIds = widget.currentMemberIds.toSet();
      if (mounted && widget.isCurrent()) {
        setState(() {
          _friends = data.friendships
              .map((f) => f.friendUser)
              .whereType<FriendshipUser>()
              .where((u) => !memberIds.contains(u.id))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && widget.isCurrent()) {
        setState(() {
          _loading = false;
          _loadError = 'Couldn’t load your friends.';
        });
      }
    }
  }

  Future<void> _invite() async {
    if (_selected.isEmpty || _inviting || !widget.isCurrent()) return;
    setState(() => _inviting = true);
    logger.d(
        'Inviting ${_selected.length} members to group ${widget.groupId}: ${_selected.join(', ')}');
    final userId = context.read<AuthProvider>().dbUser?.id;
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
        inviterId: userId,
      );
      if (!mounted || !widget.isCurrent()) return;
      widget.onInvited();
      if (mounted && widget.isCurrent()) Navigator.pop(context);
    } catch (e) {
      logger.e('Invite members error: $e');
      if (mounted && widget.isCurrent()) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to send invitations')),
        );
        setState(() => _inviting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    if (!widget.isCurrent()) {
      return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Account changed. Close this sheet to continue.'));
    }
    final query = _search.text.toLowerCase();
    final filtered = _friends.where((f) {
      return f.username.toLowerCase().contains(query);
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
              color: context.colors.medium.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Invite Friends',
                  style: TextStyle(
                    color: context.colors.light,
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
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: _inviting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
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
              style: TextStyle(color: context.colors.light),
              decoration: InputDecoration(
                hintText: 'Search friends…',
                hintStyle: TextStyle(color: context.colors.medium),
                prefixIcon: Icon(Icons.search, color: context.colors.medium),
                filled: true,
                fillColor: context.colors.tabBarBackground,
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
            child: _loading
                ? const ContentListSkeleton()
                : _loadError != null
                    ? Center(
                        child: SingleChildScrollView(
                            child: LoadFailureNotice(
                                message: _loadError!, onRetry: _loadFriends)))
                    : filtered.isEmpty
                        ? Center(
                            child: Text(
                              _friends.isEmpty
                                  ? 'All your friends are already in the group'
                                  : 'No friends match your search',
                              style: TextStyle(color: context.colors.medium),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final friend = filtered[i];
                              final selected = _selected.contains(friend.id);
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
                                  style: TextStyle(color: context.colors.light),
                                ),
                                activeColor: FlixieColors.primary,
                                checkColor: Colors.white,
                                secondary: ProfileAvatarView(
                                  avatar: friend.avatar,
                                  profileBadges: friend.profileBadges,
                                  fallbackText: friend.username.isEmpty
                                      ? '?'
                                      : friend.username[0].toUpperCase(),
                                  fallbackColor: FlixieColors.primary,
                                  size: 36,
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
