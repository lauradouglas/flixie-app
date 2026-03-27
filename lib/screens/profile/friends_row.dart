import 'package:flutter/material.dart';

import '../../models/friendship.dart';
import '../../theme/app_theme.dart';

class FriendsRow extends StatelessWidget {
  const FriendsRow({
    super.key,
    required this.data,
    this.isLoading = false,
  });

  final FriendsData data;
  final bool isLoading;

  void _showAllFriendsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AllFriendsSheet(data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final friends = data.friendships;

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
        if (isLoading)
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
                return _FriendAvatar(user: friend);
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
            user.initials ?? user.username.substring(0, 1).toUpperCase(),
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

class _AllFriendsSheet extends StatefulWidget {
  const _AllFriendsSheet({required this.data});
  final FriendsData data;

  @override
  State<_AllFriendsSheet> createState() => _AllFriendsSheetState();
}

class _AllFriendsSheetState extends State<_AllFriendsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: FlixieColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.data.friendships.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: FlixieColors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.data.pendingFriends.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: FlixieColors.medium.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.data.requestedFriends.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                  widget.data.friendships.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No friends yet.',
                              style: textTheme.bodyMedium
                                  ?.copyWith(color: FlixieColors.medium),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: widget.data.friendships.length,
                          itemBuilder: (_, i) {
                            final user = widget.data.friendships[i].friendUser;
                            if (user == null) return const SizedBox.shrink();
                            return _FriendListTile(
                              user: user,
                              subtitle: 'Friend',
                              accentColor: FlixieColors.primary,
                            );
                          },
                        ),
                  // Pending tab
                  widget.data.pendingFriends.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No pending friend requests.',
                              style: textTheme.bodyMedium
                                  ?.copyWith(color: FlixieColors.medium),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: widget.data.pendingFriends.length,
                          itemBuilder: (_, i) {
                            final user =
                                widget.data.pendingFriends[i].friendUser;
                            if (user == null) return const SizedBox.shrink();
                            return _FriendListTile(
                              user: user,
                              subtitle: 'Wants to be your friend',
                              accentColor: FlixieColors.warning,
                            );
                          },
                        ),
                  // Sent tab
                  widget.data.requestedFriends.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No sent friend requests.',
                              style: textTheme.bodyMedium
                                  ?.copyWith(color: FlixieColors.medium),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: widget.data.requestedFriends.length,
                          itemBuilder: (_, i) {
                            final user =
                                widget.data.requestedFriends[i].friendUser;
                            if (user == null) return const SizedBox.shrink();
                            return _FriendListTile(
                              user: user,
                              subtitle: 'Request sent',
                              accentColor: FlixieColors.medium,
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

class _FriendListTile extends StatelessWidget {
  const _FriendListTile({
    required this.user,
    required this.subtitle,
    required this.accentColor,
  });

  final FriendshipUser user;
  final String subtitle;
  final Color accentColor;

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
      leading: CircleAvatar(
        backgroundColor: _avatarColor.withValues(alpha: 0.25),
        child: Text(
          user.initials ?? user.username.substring(0, 1).toUpperCase(),
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
    );
  }
}
