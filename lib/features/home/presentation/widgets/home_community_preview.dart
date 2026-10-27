import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';

/// A spoiler-safe entry point to the full post and its existing social actions.
class HomeCommunityPreview extends StatelessWidget {
  const HomeCommunityPreview(
      {super.key,
      required this.item,
      required this.onOpen,
      required this.onProfile});
  final ActivityListItem item;
  final VoidCallback onOpen, onProfile;

  @override
  Widget build(BuildContext context) {
    final hidden = hideMovieRatings(context, item.movieId,
        isShow: item.showId != null, ownerId: item.userId);
    final poster =
        item.mediaPosterPath ?? item.listPreviewPosterPaths.firstOrNull;
    final name = item.username.isEmpty ? item.firstName : item.username;
    final label = switch (item.type) {
      ActivityListType.movieRating ||
      ActivityListType.showRating =>
        'Rated a title',
      ActivityListType.movieReview ||
      ActivityListType.showReview =>
        'Wrote a review',
      ActivityListType.movieWatched ||
      ActivityListType.showWatched =>
        'Logged a watch',
      ActivityListType.movieListAdded => 'Added to a list',
      _ => 'Shared an update',
    };
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
                onTap: onProfile,
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      ProfileAvatarView(
                          avatar: item.avatar,
                          profileBadges: item.profileBadges,
                          size: 40,
                          fallbackText: name.isEmpty ? '?' : name[0],
                          fallbackColor: FlixieColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                            Text(label,
                                style: TextStyle(
                                    color: context.colors.light, fontSize: 12))
                          ])),
                    ]))),
            InkWell(
                onTap: onOpen,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(50, 4, 0, 4),
                    child: Row(children: [
                      if (poster != null) ...[
                        ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                                imageUrl: poster.startsWith('http')
                                    ? poster
                                    : 'https://image.tmdb.org/t/p/w185$poster',
                                width: 34,
                                height: 51,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    const SizedBox(width: 42, height: 63))),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                item.mediaTitle ?? item.listName ?? 'View post',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                            if (!hidden && item.mediaRating != null)
                              Text(
                                  '${item.mediaRating!.toStringAsFixed(item.mediaRating! % 1 == 0 ? 0 : 1)}/10',
                                  style: TextStyle(
                                      color: context.colors.warning,
                                      fontSize: 12)),
                            Text('View post',
                                style: TextStyle(
                                    color: context.colors.primaryText,
                                    fontSize: 12)),
                          ])),
                      const Icon(Icons.chevron_right, size: 20)
                    ]))),
          ])),
      Divider(height: 1, color: context.colors.tabBarBorder),
    ]);
  }
}
