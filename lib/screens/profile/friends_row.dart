import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/friendship.dart';
import '../../theme/app_theme.dart';
import 'add_friend_sheet.dart';
import 'all_friends_sheet.dart';
import 'friend_avatar.dart';

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
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
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
                  child: FriendAvatar(user: friend),
                );
              },
            ),
          ),
      ],
    );
  }
}

