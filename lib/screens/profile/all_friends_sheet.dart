import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/friendship.dart';
import '../../services/friend_service.dart';
import '../../theme/app_theme.dart';

class AllFriendsSheet extends StatefulWidget {
  const AllFriendsSheet({
    super.key,
    required this.data,
    this.extraSentUsers = const [],
    this.onFriendsChanged,
  });
  final FriendsData data;
  final List<FriendshipUser> extraSentUsers;
  final void Function(FriendsData)? onFriendsChanged;

  @override
  State<AllFriendsSheet> createState() => _AllFriendsSheetState();
}

class _AllFriendsSheetState extends State<AllFriendsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<Friendship> _pendingFriends;
  late List<FriendshipUser> _sentUsers;
  late List<Friendship> _friends;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pendingFriends = List.from(widget.data.pendingFriends);
    _friends = List.from(widget.data.friendships);
    _sentUsers = [
      ...widget.data.requestedFriends
          .map((f) => f.friendUser)
          .whereType<FriendshipUser>(),
      ...widget.extraSentUsers,
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _acceptRequest(Friendship friendship) async {
    try {
      await FriendService.updateRequest(friendship.id, 'ACCEPTED');
      if (mounted) {
        setState(() {
          _pendingFriends.removeWhere((f) => f.id == friendship.id);
          if (friendship.friendUser != null) {
            _friends.add(Friendship(
              id: friendship.id,
              friend: friendship.friendUser,
              createdAt: '',
              updatedAt: '',
            ));
          }
        });
        widget.onFriendsChanged?.call(
          widget.data.copyWith(
            friendships: List.unmodifiable(_friends),
            pendingFriends: List.unmodifiable(_pendingFriends),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Now friends with ${friendship.friendUser?.username ?? 'user'}')),
        );
      }
    } catch (_) {
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
          _pendingFriends.removeWhere((f) => f.id == friendship.id);
        });
        widget.onFriendsChanged?.call(
          widget.data.copyWith(
            pendingFriends: List.unmodifiable(_pendingFriends),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to decline friend request')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 3,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
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
              child: Text(
                'Friends',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: FlixieColors.primary,
              unselectedLabelColor: FlixieColors.medium,
              indicatorColor: FlixieColors.primary,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Friends'),
                      const SizedBox(width: 6),
                      _TabBadge(
                        count: _friends.length,
                        color: FlixieColors.primary,
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Pending'),
                      const SizedBox(width: 6),
                      _TabBadge(
                        count: _pendingFriends.length,
                        color: FlixieColors.warning,
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Sent'),
                      const SizedBox(width: 6),
                      _TabBadge(
                        count: _sentUsers.length,
                        color: FlixieColors.medium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Friends tab
                  _friends.isEmpty
                      ? const _EmptyTab(message: 'No friends yet.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _friends.length,
                          itemBuilder: (_, i) {
                            final user = _friends[i].friendUser;
                            if (user == null) return const SizedBox.shrink();
                            return _FriendListTile(
                              user: user,
                              subtitle: 'Friend',
                              accentColor: FlixieColors.primary,
                              onTap: () {
                                final router = GoRouter.of(context);
                                Navigator.pop(context);
                                router.push('/friends/${user.id}');
                              },
                            );
                          },
                        ),

                  // Pending tab (incoming requests)
                  _pendingFriends.isEmpty
                      ? const _EmptyTab(message: 'No pending friend requests.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _pendingFriends.length,
                          itemBuilder: (_, i) {
                            final friendship = _pendingFriends[i];
                            final user = friendship.friendUser;
                            if (user == null) return const SizedBox.shrink();
                            return _PendingRequestTile(
                              user: user,
                              onAccept: () => _acceptRequest(friendship),
                              onDecline: () => _declineRequest(friendship),
                              onTap: () => context.push('/friends/${user.id}'),
                            );
                          },
                        ),

                  // Sent tab
                  _sentUsers.isEmpty
                      ? const _EmptyTab(message: 'No sent friend requests.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _sentUsers.length,
                          itemBuilder: (_, i) {
                            final user = _sentUsers[i];
                            return _FriendListTile(
                              user: user,
                              subtitle: 'Request sent',
                              accentColor: FlixieColors.medium,
                              onTap: () => context.push('/friends/${user.id}'),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBadge extends StatelessWidget {
  const _TabBadge({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: FlixieColors.medium),
        ),
      ),
    );
  }
}

class _PendingRequestTile extends StatelessWidget {
  const _PendingRequestTile({
    required this.user,
    required this.onAccept,
    required this.onDecline,
    required this.onTap,
  });

  final FriendshipUser user;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onTap;

  Color get _avatarColor {
    final hex = user.iconColor?['hexCode'] as String?;
    if (hex != null) {
      try {
        return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
      } catch (_) {}
    }
    return FlixieColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: CircleAvatar(
              backgroundColor: _avatarColor.withValues(alpha: 0.25),
              child: Text(
                user.initials ??
                    (user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : '?'),
                style: TextStyle(
                  color: _avatarColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${user.username}',
                    style: const TextStyle(color: FlixieColors.light),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.firstName != null)
                    Text(
                      '${user.firstName}'.trim(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: FlixieColors.light.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  const Text(
                    'Wants to be your friend',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: FlixieColors.warning, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onAccept,
                icon: const Icon(Icons.check_circle_outline,
                    color: FlixieColors.success),
                tooltip: 'Accept',
                iconSize: 20,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onDecline,
                icon: const Icon(Icons.cancel_outlined,
                    color: FlixieColors.danger),
                tooltip: 'Decline',
                iconSize: 20,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FriendListTile extends StatelessWidget {
  const _FriendListTile({
    required this.user,
    required this.subtitle,
    required this.accentColor,
    this.onTap,
  });

  final FriendshipUser user;
  final String subtitle;
  final Color accentColor;
  final VoidCallback? onTap;

  Color get _avatarColor {
    final hex = user.iconColor?['hexCode'] as String?;
    if (hex != null) {
      try {
        return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
      } catch (_) {}
    }
    return accentColor;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: _avatarColor.withValues(alpha: 0.25),
        child: Text(
          user.initials ??
              (user.username.isNotEmpty ? user.username[0].toUpperCase() : '?'),
          style: TextStyle(
            color: _avatarColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(user.displayName,
          style: const TextStyle(color: FlixieColors.light)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: accentColor, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: FlixieColors.medium),
    );
  }
}
