import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class MediaFriendActivityRow extends StatelessWidget {
  const MediaFriendActivityRow(
      {super.key,
      required this.activity,
      required this.onTap,
      this.movieId,
      this.isShow = false});
  final int? movieId;
  final bool isShow;
  final MovieFriendActivity activity;
  final VoidCallback? onTap;
  BoxDecoration _friendPanelDecoration(BuildContext context) => BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      );

  Widget _compactFriendAvatar(
      BuildContext context, MovieFriendActivity activity,
      {double size = 30}) {
    final hex =
        activity.iconColor?['hexCode']?.toString().replaceFirst('#', '');
    final value = hex == null
        ? null
        : int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    final color = value == null ? FlixieColors.primary : Color(value);
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: context.colors.surface,
        shape: BoxShape.circle,
      ),
      child: ProfileAvatarView(
        avatar: activity.avatar,
        fallbackText: activity.username.isEmpty
            ? '?'
            : activity.username[0].toUpperCase(),
        fallbackColor: color,
        size: size - 3,
        profileBadges: activity.profileBadges,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = (activity.watchCount ?? 0) > 0
        ? activity.watchCount!
        : activity.isRewatch
            ? 2
            : 1;
    final chips = <Widget>[
      if (activity.watched)
        _compactFriendChip('$count ${count == 1 ? 'time' : 'times'}',
            Icons.check_rounded, context.colors.success,
            description: 'Watched $count ${count == 1 ? 'time' : 'times'}'),
      if (activity.rating != null)
        _compactFriendChip(
            hideMovieRatings(context, movieId,
                    isShow: isShow, ownerId: activity.userId)
                ? 'Rated'
                : '${activity.rating}/10',
            Icons.star_rounded,
            context.colors.warning,
            description: hideMovieRatings(context, movieId,
                    isShow: isShow, ownerId: activity.userId)
                ? 'Rated'
                : 'Rated ${activity.rating} out of 10'),
      if (activity.recommended != null)
        _compactFriendChip(
            null,
            activity.recommended!
                ? Icons.thumb_up_alt_rounded
                : Icons.thumb_down_alt_rounded,
            activity.recommended!
                ? context.colors.success
                : context.colors.danger,
            description:
                activity.recommended! ? 'Recommends' : "Doesn't recommend"),
      if (activity.favorited)
        _compactFriendChip(null, Icons.favorite_rounded, context.colors.danger,
            description: 'Favourite'),
      if (activity.onWatchlist)
        _compactFriendChip(null, Icons.bookmark_rounded, context.colors.warning,
            description: 'In watchlist'),
      if (activity.reviewed)
        _compactFriendChip(
            null, Icons.rate_review_outlined, const Color(0xFF70A7FF),
            description: 'Reviewed'),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: _friendPanelDecoration(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _compactFriendAvatar(context, activity, size: 38),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.username,
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: chips,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: FlixieColors.primary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactFriendChip(String? label, IconData icon, Color color,
      {required String description}) {
    return Tooltip(
      message: description,
      child: Semantics(
        label: description,
        excludeSemantics: true,
        child: FlixiePill.label(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              if (label != null) ...[
                const SizedBox(width: 10),
                Flexible(child: Text(label)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
