import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/movie_list_movie.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

import 'package:flixie_app/features/movies/presentation/movie_list_selection.dart';

class MovieListPosterCard extends StatelessWidget {
  const MovieListPosterCard({
    super.key,
    required this.entry,
    required this.canEdit,
    required this.currentUserId,
    required this.onOpen,
    required this.onRemove,
  });

  final MovieListMovie entry;
  final bool canEdit;
  final String? currentUserId;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final movie = entry.movie;
    final show = entry.show;
    final isShow = entryShowId(entry) > 0;
    final posterPath = movie?.posterPath ?? show?.posterPath;
    final posterUrl = posterPath != null
        ? 'https://image.tmdb.org/t/p/w500$posterPath'
        : null;
    final year = extractYear(movie?.releaseDate ?? show?.firstAirDate);
    final rating =
        hideMovieRatings(context, entry.movieId, isShow: entry.showId > 0)
            ? null
            : entryRating(entry);
    final isRecent = isRecentAddition(entry.createdAt);

    return Material(
      color: context.colors.tabBarBackgroundFocused,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  posterUrl == null
                      ? Container(
                          color: const Color(0xFF1E2D40),
                          child: Center(
                            child: Icon(
                              Icons.movie_outlined,
                              color: context.colors.medium,
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFF1E2D40),
                            child: Center(
                              child: Icon(
                                Icons.movie_outlined,
                                color: context.colors.medium,
                              ),
                            ),
                          ),
                        ),
                  if (canEdit)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          tooltip: 'List item actions',
                          color: context.colors.tabBarBackgroundFocused,
                          icon: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: const Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                          onSelected: (value) {
                            if (value == 'remove') onRemove();
                            if (value == 'contributor' &&
                                entry.addedBy != null) {
                              context.push('/friends/${entry.addedBy!.id}');
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'remove',
                              height: 40,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.remove_circle_outline_rounded,
                                    color: context.colors.danger,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 9),
                                  const Flexible(
                                      child: Text('Remove from list')),
                                ],
                              ),
                            ),
                            if (entry.addedBy != null)
                              const PopupMenuItem(
                                value: 'contributor',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_outline_rounded,
                                        size: 18),
                                    SizedBox(width: 9),
                                    Expanded(child: Text('View who added it')),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (entry.addedBy != null)
                    Positioned(
                      left: 7,
                      bottom: 7,
                      child: Tooltip(
                        message: 'Added by @${entry.addedBy!.username}',
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: FlixieColors.primary,
                              width: 1.5,
                            ),
                          ),
                          child: ProfileAvatarView(
                            avatar: entry.addedBy!.avatar,
                            fallbackText: entry.addedBy!.username.isEmpty
                                ? '?'
                                : entry.addedBy!.username[0].toUpperCase(),
                            fallbackColor: FlixieColors.primary,
                            size: 27,
                            profileBadges: entry.addedBy!.profileBadges,
                          ),
                        ),
                      ),
                    ),
                  if (isRecent)
                    const Positioned(
                      left: 7,
                      top: 7,
                      child: FlixiePill.label(label: Text('New')),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 9, 9, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: MediaQuery.textScalerOf(context).scale(32),
                    child: Text(
                      entryTitle(entry),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (year != null)
                        Text(
                          isShow ? '$year · Show' : year,
                          style: TextStyle(
                            color: context.colors.medium,
                            fontSize: 12,
                          ),
                        ),
                      if (rating != null && rating > 0) ...[
                        Icon(
                          Icons.star_rounded,
                          color: context.colors.tertiary,
                          size: 13,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            color: context.colors.tertiary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (entry.addedBy != null) ...[
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ProfileAvatarView(
                              avatar: entry.addedBy!.avatar,
                              fallbackText: entry.addedBy!.username.isEmpty
                                  ? '?'
                                  : entry.addedBy!.username[0].toUpperCase(),
                              fallbackColor: FlixieColors.primary,
                              size: 20,
                              profileBadges: entry.addedBy!.profileBadges,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                addedByUsername(entry, currentUserId),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.colors.light,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          addedDateLabel(entry.createdAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.medium,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
