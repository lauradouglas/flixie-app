import '../widgets/expandable_profile_bio.dart';
import 'package:flixie_app/features/social/data/community_service.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_follow_button.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_badges.dart';

import '../controllers/friend_profile_controller.dart';
import '../friend_profile_action_flow.dart';

class FriendProfileHeader extends StatelessWidget {
  const FriendProfileHeader({super.key, required this.controller});
  final FriendProfileController controller;
  @override
  Widget build(BuildContext context) =>
      _modernHeader(context, controller.user!);
  Color get _avatarColor {
    final hex = controller.user?.iconColor?['hexCode'] as String?;
    if (hex != null) {
      try {
        return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
      } catch (_) {}
    }
    return FlixieColors.primary;
  }

  String get _memberSinceLabel {
    final joined = DateTime.tryParse(controller.user?.createdAt ?? '');
    if (joined == null) return 'Member';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return 'Member since ${months[joined.month - 1]} ${joined.year}';
  }

  Widget _modernHeader(BuildContext context, User user) {
    final showFirstName = user.firstName?.trim().isNotEmpty == true;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        ProfileAvatarView(
            avatar: user.avatar,
            fallbackText: user.initials ??
                (user.username.isEmpty ? '?' : user.username[0]),
            fallbackColor: _avatarColor,
            size: 64,
            profileBadges: user.profileBadges),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(showFirstName ? user.firstName! : user.username,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: context.colors.white)),
          if (user.creatorProfile != null)
            Text('✓ Verified ${user.creatorProfile!.role}',
                style:
                    TextStyle(color: context.colors.primaryText, fontSize: 13)),
          Text('@${user.username}',
              style: TextStyle(color: context.colors.medium)),
          if (user.profileBadges.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ProfileBadgePills(
                    badges: user.profileBadges, compact: true)),
        ])),
      ]),
      if (controller.friendshipStatus == FriendshipStatus.friends) ...[
        const SizedBox(height: 2),
        Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('✓ Friends',
                  style:
                      TextStyle(color: context.colors.success, fontSize: 13)),
              CommunityFollowButton(
                  path: 'profiles/${controller.subjectId}',
                  service: const CommunityService()),
            ]),
      ],
      if (user.bio?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 6),
        ExpandableProfileBio(text: user.bio!),
        const SizedBox(height: 8),
      ],
      Text(_memberSinceLabel,
          style: TextStyle(color: context.colors.medium, fontSize: 12)),
    ]);
  }
}

class FriendProfileActions extends StatelessWidget {
  const FriendProfileActions(
      {super.key,
      required this.controller,
      required this.flow,
      this.showCommunityFollow = false});
  final FriendProfileController controller;
  final FriendProfileActionFlow flow;
  final bool showCommunityFollow;
  @override
  Widget build(BuildContext context) => _profileActions(context);
  Widget _buildFriendshipButton(BuildContext context) {
    if (controller.actionLoading) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    switch (controller.friendshipStatus) {
      case FriendshipStatus.none:
        return ElevatedButton.icon(
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Add Friend'),
          style: ElevatedButton.styleFrom(
            backgroundColor: FlixieColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: flow.sendFriendRequest,
        );

      case FriendshipStatus.requested:
        return OutlinedButton.icon(
          icon: const Icon(Icons.schedule_outlined),
          label: const Text('Request Pending'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.warning,
            side: BorderSide(color: context.colors.warning),
          ),
          onPressed: null,
        );

      case FriendshipStatus.pending:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.success,
                foregroundColor: Colors.black,
              ),
              onPressed: flow.acceptRequest,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.danger,
                side: BorderSide(color: context.colors.danger),
              ),
              onPressed: flow.declineRequest,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Decline'),
            ),
          ],
        );

      case FriendshipStatus.friends:
        return OutlinedButton.icon(
          icon: const Icon(Icons.person_remove_outlined),
          label: const Text('Remove Friend'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.danger,
            side: BorderSide(color: context.colors.danger),
          ),
          onPressed: flow.removeFriend,
        );
    }
  }

  Widget _profileActions(BuildContext context) {
    if (controller.actionLoading) {
      return Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (controller.friendshipStatusLoading) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(24),
        ),
      );
    }
    if (controller.friendshipStatus != FriendshipStatus.friends) {
      final friendship = _buildFriendshipButton(context);
      if (!showCommunityFollow) return friendship;
      return Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            friendship,
            CommunityFollowButton(
                path: 'profiles/${controller.subjectId}',
                service: const CommunityService()),
          ]);
    }
    return LayoutBuilder(builder: (context, constraints) {
      final style = FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
      final message = FilledButton.tonalIcon(
        onPressed: () => context.push('/chat/${controller.subjectId}'),
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
        label: const Text('Message'),
        style: style.copyWith(
            backgroundColor: WidgetStatePropertyAll(context.colors.surface),
            foregroundColor:
                WidgetStatePropertyAll(context.colors.primaryText)),
      );
      final plan = FilledButton.icon(
        onPressed: flow.inviteToWatch,
        icon: const Icon(Icons.movie_outlined, size: 18),
        label: const Text('Plan a watch'),
        style: style,
      );
      if (constraints.maxWidth < 330 ||
          MediaQuery.textScalerOf(context).scale(14) > 19) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [message, const SizedBox(height: 8), plan]);
      }
      return Row(children: [
        Expanded(child: message),
        const SizedBox(width: 10),
        Expanded(child: plan)
      ]);
    });
  }
}

class FriendProfileTotals extends StatelessWidget {
  const FriendProfileTotals({super.key, required this.user});
  final User user;
  @override
  Widget build(BuildContext context) => _modernStats(
      context,
      (user.watchedMovies?.length ?? 0) + (user.watchedShows?.length ?? 0),
      (user.movieWatchlist?.length ?? 0) + (user.showWatchlist?.length ?? 0),
      (user.favoriteMovies?.length ?? 0) + (user.favoriteShows?.length ?? 0));
  Widget _modernStats(
      BuildContext context, int watched, int watchlist, int favourites) {
    final user = this.user;
    final breakdowns = [
      '${user.watchedMovies?.length ?? 0} movies · ${user.watchedShows?.length ?? 0} shows',
      '${user.movieWatchlist?.length ?? 0} movies · ${user.showWatchlist?.length ?? 0} shows',
      '${user.favoriteMovies?.length ?? 0} movies · ${user.favoriteShows?.length ?? 0} shows',
    ];
    final values = [
      (watched, 'Watched', Icons.visibility_outlined),
      (watchlist, 'Watchlist', Icons.bookmark_border_rounded),
      (favourites, 'Favourites', Icons.favorite_border_rounded),
    ];
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          for (var i = 0; i < values.length; i++) ...[
            Expanded(
                child: Column(children: [
              Text('${values[i].$1}',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: context.colors.white)),
              Text(values[i].$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.medium, fontSize: 13)),
              const SizedBox(height: 5),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(breakdowns[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: context.colors.light))),
            ])),
            if (i < values.length - 1)
              Container(
                  width: 1, height: 36, color: context.colors.tabBarBorder),
          ],
        ]));
  }
}

class FriendProfileTabs extends StatelessWidget {
  const FriendProfileTabs({super.key, required this.controller});
  final FriendProfileController controller;
  @override
  Widget build(BuildContext context) => _profileTabs(context);
  Widget _profileTabs(BuildContext context) {
    const labels = ['Overview', 'Activity', 'Reviews'];
    return Row(children: [
      for (var i = 0; i < labels.length; i++)
        Expanded(
          child: InkWell(
            onTap: () => controller.change(() => controller.selectedTab = i),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(labels[i],
                    style: TextStyle(
                      color: controller.selectedTab == i
                          ? FlixieColors.primary
                          : context.colors.light,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: controller.selectedTab == i
                      ? FlixieColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }
}
