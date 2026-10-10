import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_friend_activity_row.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class ShowFriendsSection extends StatefulWidget {
  const ShowFriendsSection({super.key, required this.summary});
  final TvShowFriendSummary? summary;
  @override
  State<ShowFriendsSection> createState() => _ShowFriendsSectionState();
}

class _ShowFriendsSectionState extends State<ShowFriendsSection> {
  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    if (summary == null || summary.friendCount == 0) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(child: FlixieSectionHeader(title: 'Friends')),
          TextButton.icon(
            onPressed: summary.friends.isEmpty
                ? null
                : () => _showAllShowFriends(summary),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: const Text('View all'),
          ),
        ]),
        Text(
          '${summary.friendCount} ${summary.friendCount == 1 ? 'friend' : 'friends'} interacted',
          style: TextStyle(color: context.colors.medium, fontSize: 11),
        ),
        const SizedBox(height: 10),
        if (summary.friendCount > 3)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
                color: context.colors.surface.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  height: 28,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: summary.friends
                        .take(3)
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) => Positioned(
                            left: entry.key * 17,
                            child: _showFriendAvatar(entry.value, 28)))
                        .toList(),
                  ),
                ),
                _showFriendMetric(summary.watchedCount, 'watched'),
                _showFriendMetric(summary.ratedCount, 'rated'),
                _showFriendMetric(summary.recommendedCount, 'recommend'),
                _showFriendMetric(summary.watchlistCount, 'watchlist'),
                _showFriendMetric(summary.favouriteCount, 'favourite'),
              ],
            ),
          ),
        const SizedBox(height: 8),
        ...summary.friends.take(3).map(_buildShowFriendRow),
      ],
    );
  }

  Widget _showFriendMetric(int value, String label) => Expanded(
        child: Column(children: [
          Text('$value',
              style: TextStyle(
                  color: context.colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              style: TextStyle(color: context.colors.medium, fontSize: 9)),
        ]),
      );

  Widget _showFriendAvatar(TvShowFriend friend, double size) =>
      ProfileAvatarView(
        avatar: friend.avatar,
        profileBadges: friend.profileBadges,
        fallbackText:
            friend.username.isEmpty ? '?' : friend.username[0].toUpperCase(),
        fallbackColor: FlixieColors.primary,
        size: size,
      );

  Widget _buildShowFriendRow(TvShowFriend friend) => MediaFriendActivityRow(
        isShow: true,
        activity: MovieFriendActivity(
            userId: friend.userId,
            username: friend.username,
            avatar: friend.avatar,
            profileBadges: friend.profileBadges,
            watched: friend.watched,
            onWatchlist: friend.onWatchlist,
            favorited: friend.favorited,
            reviewed: friend.reviewed,
            rating: friend.rating?.round(),
            recommended: friend.recommends ? true : null),
        onTap: friend.userId.isEmpty
            ? null
            : () => context.push('/friends/${friend.userId}'),
      );

  void _showAllShowFriends(TvShowFriendSummary summary) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .7,
        minChildSize: .45,
        maxChildSize: .92,
        builder: (context, controller) => Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
              color: context.colors.background,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: context.colors.medium,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: Text('${summary.friendCount} friends interacted',
                      style: TextStyle(
                          color: context.colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800))),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: context.colors.light)),
            ]),
            Expanded(
                child: ListView(
                    controller: controller,
                    children:
                        summary.friends.map(_buildShowFriendRow).toList())),
          ]),
        ),
      ),
    );
  }
}
