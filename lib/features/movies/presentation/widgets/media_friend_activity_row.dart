import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class MediaFriendActivityRow extends StatelessWidget {
  const MediaFriendActivityRow(
      {super.key, required this.activity, required this.onTap});
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
    final chips = <Widget>[
      if (activity.watched)
        _compactFriendChip(
          (activity.watchCount ?? 0) > 2
              ? 'Watched ${activity.watchCount} times'
              : activity.isRewatch || activity.watchCount == 2
                  ? 'Watched twice'
                  : 'Watched',
          Icons.check_rounded,
          context.colors.success,
        ),
      if (activity.onWatchlist)
        _compactFriendChip(
          'In watchlist',
          Icons.bookmark_outline_rounded,
          FlixieColors.primary,
        ),
      if (activity.favorited)
        _compactFriendChip(
          'Favourite',
          Icons.favorite_rounded,
          context.colors.danger,
        ),
      if (activity.reviewed)
        _compactFriendChip(
          'Reviewed',
          Icons.check_box_rounded,
          const Color(0xFF70A7FF),
        ),
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
              if (activity.recommended != null) ...[
                const SizedBox(width: 7),
                Tooltip(
                  message: activity.recommended!
                      ? 'Recommends'
                      : "Doesn't recommend",
                  child: Icon(
                    activity.recommended!
                        ? Icons.thumb_up_alt_rounded
                        : Icons.thumb_down_alt_rounded,
                    color: activity.recommended!
                        ? context.colors.success
                        : context.colors.danger,
                    size: 17,
                  ),
                ),
              ],
              if (activity.rating != null) ...[
                const SizedBox(width: 9),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded,
                        color: context.colors.warning, size: 16),
                    const SizedBox(width: 2),
                    Text(
                      '${activity.rating}/10',
                      style: TextStyle(
                        color: context.colors.light,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
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

  Widget _compactFriendChip(String label, IconData icon, Color color) {
    return FlixiePill.label(
        label: Text(label), avatar: Icon(icon, color: color));
  }
}
