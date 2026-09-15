import 'package:flutter/material.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/add_friend_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/all_friends_sheet.dart';

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
      useRootNavigator: true,
      useSafeArea: true,
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
      useRootNavigator: true,
      useSafeArea: true,
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
        SizedBox(
          width: double.infinity,
          child: OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: 12,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Friends',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: FlixieColors.light,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                ],
              ),
              TextButton.icon(
                onPressed: () => _showAddFriendSheet(context),
                style: TextButton.styleFrom(
                  foregroundColor: FlixieColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
                label: const Text('Add friend'),
              ),
            ],
          ),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final friendship in friends)
                if (friendship.friendUser != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () =>
                          context.push('/friends/${friendship.friendUser!.id}'),
                      child: _FriendPreviewCard(user: friendship.friendUser!),
                    ),
                  ),
            ]),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _showAllFriendsSheet(context),
            label: const Text('View all friends'),
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            iconAlignment: IconAlignment.end,
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
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          ProfileAvatarView(
            avatar: user.avatar,
            fallbackText: user.initials ??
                (user.username.isNotEmpty
                    ? user.username[0].toUpperCase()
                    : '?'),
            fallbackColor: _avatarColor,
            size: 66,
            profileBadges: user.profileBadges,
          ),
          const SizedBox(height: 8),
          Text(
            user.username,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
