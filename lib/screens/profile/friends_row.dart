import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/friendship.dart';
import '../../theme/app_theme.dart';
import 'add_friend_sheet.dart';
import 'all_friends_sheet.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AllFriendsSheet(
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddFriendSheet(
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
    final total = friends.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Friends',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: FlixieColors.light,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: FlixieColors.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$total',
                style: const TextStyle(
                  color: FlixieColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showAddFriendSheet(context),
              style: TextButton.styleFrom(
                foregroundColor: FlixieColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
              ),
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('Add +'),
            ),
            TextButton(
              onPressed: () => _showAllFriendsSheet(context),
              style: TextButton.styleFrom(
                foregroundColor: FlixieColors.light,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
              ),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: friends.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final friend = friends[i].friendUser;
                if (friend == null) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => context.push('/friends/${friend.id}'),
                  child: _FriendPreviewCard(user: friend),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _FriendPreviewCard extends StatelessWidget {
  const _FriendPreviewCard({required this.user});

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
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: FlixieColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlixieColors.tabBarBorder),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: _avatarColor.withValues(alpha: 0.25),
            child: Text(
              user.initials ??
                  (user.username.isNotEmpty
                      ? user.username[0].toUpperCase()
                      : '?'),
              style: TextStyle(
                color: _avatarColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user.firstName?.isNotEmpty == true
                ? user.firstName!
                : user.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Friend',
            style: TextStyle(
              color: FlixieColors.medium,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
