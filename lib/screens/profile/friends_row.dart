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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'FOLLOWING FRIENDS',
              style: textTheme.titleMedium?.copyWith(
                color: FlixieColors.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            TextButton(
              onPressed: () => _showAllFriendsSheet(context),
              child: const Text(
                'See All',
                style: TextStyle(color: FlixieColors.primary),
              ),
            ),
          ],
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
            height: 90,
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
    final hex = user.iconColor?['hex'] as String?;
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
          radius: 30,
          backgroundColor: _avatarColor.withValues(alpha: 0.3),
          child: Text(
            user.initials ?? user.username.substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: _avatarColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 60,
          child: Text(
            user.shortName,
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

class _AllFriendsSheet extends StatelessWidget {
  const _AllFriendsSheet({required this.data});
  final FriendsData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
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
            child: Row(
              children: [
                Text(
                  'Friends',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FlixieColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${data.friendships.length}',
                    style: const TextStyle(
                      color: FlixieColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (data.friendships.isNotEmpty) ...[
                  _SectionHeader(title: 'Friends', count: data.friendships.length),
                  ...data.friendships.map((f) {
                    final user = f.friendUser;
                    if (user == null) return const SizedBox.shrink();
                    return _FriendListTile(
                      user: user,
                      subtitle: 'Friend',
                      accentColor: FlixieColors.primary,
                    );
                  }),
                ],
                if (data.pendingFriends.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionHeader(
                    title: 'Pending Requests',
                    count: data.pendingFriends.length,
                    color: FlixieColors.warning,
                  ),
                  ...data.pendingFriends.map((r) {
                    final user = r.sender;
                    if (user == null) return const SizedBox.shrink();
                    return _FriendListTile(
                      user: user,
                      subtitle: 'Wants to be your friend',
                      accentColor: FlixieColors.warning,
                    );
                  }),
                ],
                if (data.requestedFriends.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionHeader(
                    title: 'Sent Requests',
                    count: data.requestedFriends.length,
                    color: FlixieColors.medium,
                  ),
                  ...data.requestedFriends.map((r) {
                    final user = r.receiver;
                    if (user == null) return const SizedBox.shrink();
                    return _FriendListTile(
                      user: user,
                      subtitle: 'Request sent',
                      accentColor: FlixieColors.medium,
                    );
                  }),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    this.color = FlixieColors.primary,
  });
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($count)',
            style: const TextStyle(color: FlixieColors.medium, fontSize: 12),
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
  });

  final FriendshipUser user;
  final String subtitle;
  final Color accentColor;

  Color get _avatarColor {
    final hex = user.iconColor?['hex'] as String?;
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
      title: Text(user.displayName, style: const TextStyle(color: FlixieColors.light)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: accentColor, fontSize: 12),
      ),
    );
  }
}
