import 'package:flixie_app/features/social/presentation/widgets/friend_search_scope.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';

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
    with SingleTickerProviderStateMixin, StarredFriendsState<AllFriendsSheet> {
  late TabController _tabController;
  late List<Friendship> _pendingFriends;
  late List<FriendshipUser> _sentUsers;
  String _query = '';
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
    final analytics = context.read<AnalyticsController>();
    try {
      await FriendService.updateRequest(friendship.id, 'ACCEPTED');
      await analytics.friendConnected();
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
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.success,
              content: Text(
                  'Now friends with ${friendship.friendUser?.username ?? 'user'}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to accept friend request')),
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
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to decline friend request')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final friends = orderedFriends(_friends, (f) => f.friendUser, _query);
    final pending =
        orderedFriends(_pendingFriends, (f) => f.friendUser, _query);
    final sent = orderedFriends(_sentUsers, (f) => f, _query);

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
                color: context.colors.medium.withValues(alpha: 0.4),
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
              unselectedLabelColor: context.colors.medium,
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
                        color: context.colors.warning,
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
                        color: context.colors.medium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                        hintText: 'Search friends',
                        prefixIcon: Icon(Icons.search_rounded)))),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Friends tab
                  friends.isEmpty
                      ? _EmptyTab(
                          message: _query.trim().isEmpty
                              ? 'No friends yet.'
                              : 'No friends match your search.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: friends.length,
                          itemBuilder: (_, i) {
                            final user = friends[i].friendUser;
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
                  pending.isEmpty
                      ? const _EmptyTab(message: 'No pending friend requests.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: pending.length,
                          itemBuilder: (_, i) {
                            final friendship = pending[i];
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
                  sent.isEmpty
                      ? const _EmptyTab(message: 'No sent friend requests.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: sent.length,
                          itemBuilder: (_, i) {
                            final user = sent[i];
                            return _FriendListTile(
                              user: user,
                              subtitle: 'Request sent',
                              accentColor: context.colors.medium,
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
    return FlixiePill.label(label: Text('$count'));
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
              ?.copyWith(color: context.colors.medium),
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

  Color _avatarColor(BuildContext context) {
    final hex = user.iconColor?['hexCode'] as String?;
    if (hex != null) {
      try {
        return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
      } catch (_) {}
    }
    return context.colors.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: ProfileAvatarView(
              avatar: user.avatar,
              fallbackText: user.initials ??
                  (user.username.isNotEmpty
                      ? user.username[0].toUpperCase()
                      : '?'),
              fallbackColor: _avatarColor(context),
              size: 40,
              profileBadges: user.profileBadges,
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
                    style: TextStyle(color: context.colors.light),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Wants to be your friend',
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: context.colors.warning, fontSize: 12),
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
                icon: Icon(Icons.check_circle_outline,
                    color: context.colors.success),
                tooltip: 'Accept',
                iconSize: 20,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onDecline,
                icon: Icon(Icons.cancel_outlined, color: context.colors.danger),
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
      leading: ProfileAvatarView(
        avatar: user.avatar,
        fallbackText: user.initials ??
            (user.username.isNotEmpty ? user.username[0].toUpperCase() : '?'),
        fallbackColor: _avatarColor,
        size: 40,
        profileBadges: user.profileBadges,
      ),
      title:
          Text(user.displayName, style: TextStyle(color: context.colors.light)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: accentColor, fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right, color: context.colors.medium),
    );
  }
}
