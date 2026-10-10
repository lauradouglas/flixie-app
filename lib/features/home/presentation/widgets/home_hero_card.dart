import '../models/home_image_urls.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/friend_media_interaction.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'hero_compact_icon_button.dart';

/// Trending card UI. Loading, membership and actions belong to the Home owner.
class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard(
      {super.key,
      required this.movie,
      required this.posterHeight,
      required this.inWatchlist,
      required this.isUpdating,
      required this.interactions,
      required this.friendActivityLoading,
      required this.friendActivityFailed,
      required this.onOpen,
      required this.onDetails,
      required this.onWatchlist,
      required this.onTrailer,
      required this.onFriendsRetry});
  final MovieShort movie;
  final double posterHeight;
  final bool inWatchlist,
      isUpdating,
      friendActivityLoading,
      friendActivityFailed;
  final List<FriendMediaInteraction> interactions;
  final VoidCallback onOpen, onDetails, onWatchlist, onTrailer, onFriendsRetry;

  @override
  Widget build(BuildContext context) {
    final posterUrl = homeHeroImageUrl(movie.poster);
    final ratingsHidden = context.select<MovieRatingPrivacy?, bool>(
        (privacy) => privacy?.hides(movie.id) ?? false);
    final watchlistedBy =
        interactions.where((interaction) => interaction.onWatchlist).toList();
    final favouritedBy =
        interactions.where((interaction) => interaction.favourited).toList();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: posterHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (posterUrl != null)
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRect(
                          child: ImageFiltered(
                            imageFilter:
                                ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: CachedNetworkImage(
                              imageUrl: posterUrl,
                              fit: BoxFit.cover,
                              color: Colors.black.withValues(alpha: .38),
                              colorBlendMode: BlendMode.darken,
                              errorWidget: (_, __, ___) =>
                                  _heroFallback(context),
                            ),
                          ),
                        ),
                        Center(
                          child: SizedBox(
                            height: posterHeight,
                            child: AspectRatio(
                              aspectRatio: 2 / 3,
                              child: CachedNetworkImage(
                                imageUrl: posterUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorWidget: (_, __, ___) =>
                                    _heroFallback(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    _heroFallback(context),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                movie.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.colors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  height: 1.08,
                                ),
                              ),
                              if ((movie.releaseDate ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatHeroDate(movie.releaseDate!),
                                  style: TextStyle(
                                    color: context.colors.medium,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        HeroCompactIconButton(
                          tooltip: inWatchlist
                              ? 'Remove from watchlist'
                              : 'Watchlist',
                          icon: inWatchlist
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_outline_rounded,
                          foregroundColor: inWatchlist
                              ? context.colors.primaryText
                              : context.colors.light,
                          isBusy: isUpdating,
                          onPressed: onWatchlist,
                        ),
                      ],
                    ),
                    if ((movie.overview ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        movie.overview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.light,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        if (!ratingsHidden && (movie.voteAverage ?? 0) > 0) ...[
                          Icon(
                            Icons.star_rounded,
                            color: context.colors.warning,
                            size: 19,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            movie.voteAverage!.toStringAsFixed(1),
                            style: TextStyle(
                              color: context.colors.warning,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ] else ...[
                          Icon(
                            Icons.star_outline_rounded,
                            color: context.colors.medium,
                            size: 19,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Not rated yet',
                            style: TextStyle(
                              color: context.colors.medium,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if ((movie.trailer?.key ?? '').trim().isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 1,
                            height: 22,
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          const SizedBox(width: 10),
                          TextButton.icon(
                            onPressed: onTrailer,
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: const Text('Trailer'),
                            style: TextButton.styleFrom(
                              foregroundColor: context.colors.danger,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(
                                color: context.colors.danger
                                    .withValues(alpha: 0.55),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        HeroCompactIconButton(
                          tooltip: 'Details',
                          icon: Icons.info_outline_rounded,
                          foregroundColor: context.colors.light,
                          onPressed: onDetails,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    if (watchlistedBy.isNotEmpty || favouritedBy.isNotEmpty)
                      Row(
                        children: [
                          if (watchlistedBy.isNotEmpty)
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.bookmark_rounded,
                                    color: context.colors.warning,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  _FriendInteractionAvatarStack(
                                    interactions: watchlistedBy,
                                  ),
                                ],
                              ),
                            )
                          else
                            const Spacer(flex: 2),
                          if (watchlistedBy.isNotEmpty &&
                              favouritedBy.isNotEmpty) ...[
                            Container(
                              width: 1,
                              height: 30,
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                            const SizedBox(width: 14),
                          ],
                          if (favouritedBy.isNotEmpty) ...[
                            Expanded(
                              flex: 1,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Icon(
                                    Icons.favorite_rounded,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: _FriendInteractionAvatarStack(
                                        interactions: favouritedBy,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      )
                    else if (friendActivityFailed)
                      TextButton.icon(
                        onPressed: onFriendsRetry,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry friends’ activity'),
                      )
                    else if (friendActivityLoading)
                      const SizedBox(
                        height: 30,
                        child: Row(
                          children: [
                            SkeletonBox(
                              width: 26,
                              height: 26,
                              borderRadius: 13,
                            ),
                            SizedBox(width: 8),
                            SkeletonBox(width: 132, height: 10),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        height: 30,
                        child: Row(
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              color: context.colors.medium,
                              size: 19,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'No friends have saved or favourited this yet',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.colors.medium,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroFallback(BuildContext context) {
    return Container(
      color: context.colors.tabBarBackgroundFocused,
      child: Icon(
        Icons.movie_outlined,
        color: context.colors.medium,
        size: 48,
      ),
    );
  }
}

String _formatHeroDate(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
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
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _FriendInteractionAvatarStack extends StatelessWidget {
  const _FriendInteractionAvatarStack({required this.interactions});

  final List<FriendMediaInteraction> interactions;

  @override
  Widget build(BuildContext context) {
    const avatarSize = 30.0;
    const avatarSpacing = 22.0;
    final visible = interactions.take(3).toList(growable: false);
    final overflow = interactions.length - visible.length;
    final itemCount = visible.length + (overflow > 0 ? 1 : 0);
    return SizedBox(
      width: avatarSize + ((itemCount - 1).clamp(0, 3) * avatarSpacing),
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * avatarSpacing,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(
                  color: FlixieColors.primary,
                  shape: BoxShape.circle,
                ),
                child: ProfileAvatarView(
                  avatar: visible[index].avatar,
                  fallbackText: visible[index].username.isEmpty
                      ? '?'
                      : visible[index].username[0].toUpperCase(),
                  fallbackColor: context.colors.surfaceElevated,
                  size: 27,
                  profileBadges: visible[index].profileBadges,
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * avatarSpacing,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.colors.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: FlixieColors.primary, width: 1.5),
                ),
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
