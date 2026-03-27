import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/friendship.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/friend_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

class FriendsRow extends StatefulWidget {
  const FriendsRow({
    super.key,
    required this.data,
    this.isLoading = false,
    this.onFriendsChanged,
  });

  final FriendsData data;
  final bool isLoading;
  final void Function(FriendsData)? onFriendsChanged;

  @override
  State<FriendsRow> createState() => _FriendsRowState();
}

class _FriendsRowState extends State<FriendsRow> {
  // Tracks users for whom a request was sent this session,
  // so they appear immediately in the Sent tab.
  final List<FriendshipUser> _extraSentUsers = [];

  void _showAllFriendsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AllFriendsSheet(
        data: widget.data,
        extraSentUsers: List.unmodifiable(_extraSentUsers),
        onFriendsChanged: widget.onFriendsChanged,
      ),
    );
  }

  void _showAddFriendSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddFriendSheet(
        onRequestSent: (user) {
          if (mounted) setState(() => _extraSentUsers.add(user));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final friends = widget.data.friendships;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
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
                'FRIENDS',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _showAddFriendSheet(context),
                icon: const Icon(Icons.person_add_outlined,
                    color: FlixieColors.primary, size: 20),
                tooltip: 'Add Friend',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => _showAllFriendsSheet(context),
                child: const Text(
                  'See All',
                  style: TextStyle(color: FlixieColors.primary),
                ),
              ),
            ],
          ),
        ),
        if (widget.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (friends.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No friends yet.',
              style: textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
            ),
          )
        else
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: friends.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) {
                final friend = friends[i].friendUser;
                if (friend == null) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => context.push('/friends/${friend.id}'),
                  child: _FriendAvatar(user: friend),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.user});
  final FriendshipUser user;

  Color get _avatarColor {
    final hex = user.iconColor?['hexCode'] as String?;
    if (hex != null) {
      try {
        return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
      } catch (_) {}
    }
    return FlixieColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: _avatarColor.withValues(alpha: 0.3),
          child: Text(
            user.initials ??
                (user.username.isNotEmpty
                    ? user.username[0].toUpperCase()
                    : '?'),
            style: TextStyle(
              color: _avatarColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 76,
          child: Text(
            user.username,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------------
// All Friends Sheet (with tabs: Friends | Pending | Sent)
// -------------------------------------------------------------------------

class _AllFriendsSheet extends StatefulWidget {
  const _AllFriendsSheet({
    required this.data,
    this.extraSentUsers = const [],
    this.onFriendsChanged,
  });
  final FriendsData data;
  final List<FriendshipUser> extraSentUsers;
  final void Function(FriendsData)? onFriendsChanged;

  @override
  State<_AllFriendsSheet> createState() => _AllFriendsSheetState();
}

class _AllFriendsSheetState extends State<_AllFriendsSheet>
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
                  ),
                  if (user.firstName != null)
                    Text(
                      '${user.firstName}'.trim(),
                      style: TextStyle(
                        color: FlixieColors.light.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  const Text(
                    'Wants to be your friend',
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
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              IconButton(
                onPressed: onDecline,
                icon: const Icon(Icons.cancel_outlined,
                    color: FlixieColors.danger),
                tooltip: 'Decline',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
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

// -------------------------------------------------------------------------
// Add Friend Sheet – search by username or email
// -------------------------------------------------------------------------

class _AddFriendSheet extends StatefulWidget {
  const _AddFriendSheet({this.onRequestSent});

  final void Function(FriendshipUser user)? onRequestSent;

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  List<User> _results = [];
  String? _searchError;
  final Set<String> _sentRequests = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _searchError = null;
      _results = [];
    });

    try {
      final auth = context.read<AuthProvider>();
      final myId = auth.dbUser?.id;

      List<User> results;

      // Try the search endpoint first; fall back to exact username lookup.
      try {
        results = await UserService.searchUsers(query);
      } catch (_) {
        try {
          final user = await UserService.getUserByUsername(query);
          results = [user];
        } catch (_) {
          results = [];
        }
      }

      // Exclude the current user from results.
      if (myId != null) {
        results = results.where((u) => u.id != myId).toList();
      }

      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
          if (results.isEmpty) _searchError = 'No users found.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searching = false;
          _searchError = 'Search failed. Please try again.';
        });
      }
    }
  }

  Future<void> _sendRequest(User user) async {
    final auth = context.read<AuthProvider>();
    final myId = auth.dbUser?.id;
    if (myId == null) return;

    setState(() => _sentRequests.add(user.id));

    try {
      await FriendService.sendFriendRequest({
        'requesterId': myId,
        'recipientId': user.id,
        'responderUsername': user.username,
        'message': '',
        'type': 'FRIEND_REQUEST',
      });
      // Notify parent so the Sent tab updates immediately
      widget.onRequestSent?.call(
        FriendshipUser(
          id: user.id,
          username: user.username,
          firstName: user.firstName,
          lastName: user.lastName,
          initials: user.initials,
          iconColor: user.iconColor,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request sent to ${user.username}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sentRequests.remove(user.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send friend request')),
        );
      }
    }
  }

  Color _userAvatarColor(User user) {
    final hex = user.iconColor?['hexCode'] as String?;
    if (hex != null) {
      try {
        return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
      } catch (_) {}
    }
    return FlixieColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
            child: Text(
              'Add Friend',
              style:
                  textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Search by username or email',
              style: textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: FlixieColors.light),
                    decoration: InputDecoration(
                      hintText: 'Username or email…',
                      hintStyle: const TextStyle(color: FlixieColors.medium),
                      prefixIcon:
                          const Icon(Icons.search, color: FlixieColors.medium),
                      filled: true,
                      fillColor: FlixieColors.tabBarBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searching ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlixieColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _results.isEmpty && _searchError != null
                ? Center(
                    child: Text(
                      _searchError!,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FlixieColors.medium),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final user = _results[i];
                      final sent = _sentRequests.contains(user.id);
                      final color = _userAvatarColor(user);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.25),
                          child: Text(
                            user.initials ??
                                (user.username.isNotEmpty
                                    ? user.username[0].toUpperCase()
                                    : '?'),
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(user.username,
                            style: const TextStyle(color: FlixieColors.light)),
                        subtitle: Text(
                          user.email,
                          style: const TextStyle(
                              color: FlixieColors.medium, fontSize: 12),
                        ),
                        trailing: sent
                            ? const Icon(Icons.check_circle,
                                color: FlixieColors.success)
                            : ElevatedButton(
                                onPressed: () => _sendRequest(user),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: FlixieColors.primary,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                                child: const Text('Add'),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
