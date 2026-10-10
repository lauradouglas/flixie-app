import '../widgets/creator_interview.dart';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/mini_stats.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favorite_movies_section.dart';
import 'package:flixie_app/features/profile/presentation/widgets/lists_preview_section.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/features/movies/presentation/widgets/review_card.dart'
    as shared;

import '../controllers/friend_profile_controller.dart';
import 'friend_shared_ratings_sheet.dart';

class _EmptyProfileTab extends StatelessWidget {
  const _EmptyProfileTab({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(icon, color: context.colors.medium, size: 40),
            const SizedBox(height: 12),
            Text(text, style: TextStyle(color: context.colors.medium)),
          ],
        ),
      );
}

/// Return individual children so the owning ListView keeps lazy row rendering.
List<Widget> buildFriendProfileContent(BuildContext context,
        {required FriendProfileController controller,
        bool previewMode = false}) =>
    _FriendProfileContent(controller: controller, previewMode: previewMode)
        .build(context);

class _FriendProfileContent {
  const _FriendProfileContent(
      {required this.controller, this.previewMode = false});
  final FriendProfileController controller;
  final bool previewMode;
  List<Widget> build(BuildContext context) => switch (controller.selectedTab) {
        1 => _activityContent(context, controller.user!),
        2 => _reviewsContent(context),
        _ => _overviewContent(context, controller.user!),
      };
  List<Widget> _sharedWatchlist(BuildContext context, User user) {
    if (controller.isSelf ||
        controller.friendshipStatus != FriendshipStatus.friends) {
      return [];
    }
    final mine = context.read<AuthProvider>().dbUser?.movieWatchlist ?? [];
    final ids = mine
        .where((entry) => entry.removed != true)
        .map((entry) => entry.movieId)
        .toSet();
    final shared = (user.movieWatchlist ?? [])
        .where((entry) => entry.removed != true && ids.contains(entry.movieId))
        .toList();
    if (shared.isEmpty) return [];
    return [
      const Text('Your next movie night',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Films you both want to see',
          style: TextStyle(color: context.colors.medium, fontSize: 13)),
      const SizedBox(height: 10),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final entry in shared)
              _profilePoster(
                  context,
                  entry.movie?.title ?? 'Movie',
                  entry.movie?.posterPath,
                  () => context.push(movieDetailPath(entry.movieId))),
          ])),
      const SizedBox(height: 18),
    ];
  }

  Widget _profilePoster(BuildContext context, String title, String? path,
          VoidCallback onTap) =>
      Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SizedBox(
              width: 100,
              child: InkWell(
                  onTap: onTap,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                                width: 100,
                                height: 150,
                                child: path == null
                                    ? ColoredBox(
                                        color: context.colors.surface,
                                        child: const Icon(Icons.movie_outlined))
                                    : CachedNetworkImage(
                                        imageUrl: path.startsWith('http')
                                            ? path
                                            : 'https://image.tmdb.org/t/p/w342$path',
                                        fit: BoxFit.cover))),
                        const SizedBox(height: 6),
                        Text(title,
                            style: TextStyle(
                                fontSize: 13, color: context.colors.light)),
                      ]))));

  Widget _friendShows(BuildContext context, User user) {
    final shows = (user.favoriteShows ?? [])
        .whereType<Map<String, dynamic>>()
        .where((entry) => entry['removed'] != true)
        .toList()
      ..sort((a, b) =>
          ((a['rank'] as num?) ?? 999).compareTo((b['rank'] as num?) ?? 999));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Favourite shows',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final entry in shows.take(10))
              Builder(builder: (_) {
                final show = entry['show'] as Map<String, dynamic>? ?? entry;
                final id = entry['showId'] ?? show['id'];
                return _profilePoster(
                    context,
                    '${show['name'] ?? show['title'] ?? 'Show'}',
                    show['posterPath'] as String?,
                    () => context.push(showDetailPath(id as int)));
              })
          ])),
    ]);
  }

  Widget _sharedTasteLine(
          BuildContext context, IconData icon, String label, Color color) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14, height: 1.4, color: context.colors.light))),
        ],
      );

  List<Widget> _overviewContent(BuildContext context, User user) => [
        if (user.creatorProfile != null &&
            (user.creatorProfile!.answers.isNotEmpty ||
                user.creatorProfile!.credits.isNotEmpty))
          CreatorInterview(profile: user.creatorProfile!),
        if (user.creatorProfile == null &&
            !controller.activityLoading &&
            !controller.reviewsLoading &&
            !controller.activityFailed &&
            !controller.reviewsFailed &&
            controller.activity.isEmpty &&
            controller.reviews.isEmpty &&
            (user.favoriteMovies ?? []).isEmpty &&
            (user.favoriteShows ?? []).isEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(children: [
                Icon(Icons.movie_outlined,
                    size: 36, color: context.colors.primaryText),
                const SizedBox(height: 16),
                const Text('A new story starts here',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('No films or reviews shared here yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.light)),
                const SizedBox(height: 8),
                Text('Only activity available to you appears on this profile.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: context.colors.medium, fontSize: 13)),
              ])),
        if (controller.friendshipStatus == FriendshipStatus.friends &&
            !controller.compatibilityLoading &&
            controller.sharedRatings.isNotEmpty) ...[
          Material(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  showFriendSharedRatings(context, controller: controller),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('In common',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.colors.textPrimary)),
                      const SizedBox(height: 10),
                      _sharedTasteLine(
                          context,
                          Icons.star_rounded,
                          '${controller.sharedRatings.length} films rated by both',
                          context.colors.warning),
                      if (controller.sharedFavCount > 0) ...[
                        const SizedBox(height: 8),
                        _sharedTasteLine(
                            context,
                            Icons.favorite_rounded,
                            '${controller.sharedFavCount} shared favourites',
                            context.colors.danger),
                      ],
                    ],
                  )),
                  const SizedBox(width: 12),
                  Icon(Icons.chevron_right_rounded,
                      color: context.colors.primaryText),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (controller.friendshipStatus == FriendshipStatus.friends)
          ..._sharedWatchlist(context, user),
        ListsPreviewSection(
          userId: controller.subjectId,
          title: controller.friendshipStatus == FriendshipStatus.friends
              ? 'Shared lists'
              : 'Public lists',
          hideWhenEmpty: true,
          emptyMessage: 'No lists shared with you yet.',
          embedded: true,
          publicOnly: previewMode ||
              (!controller.isSelf &&
                  controller.friendshipStatus != FriendshipStatus.friends),
        ),
        if (user.favoriteMovies?.isNotEmpty == true) ...[
          const SizedBox(height: 18),
          FavoriteMoviesSection(favoriteMovies: user.favoriteMovies!),
        ],
        if ((user.favoriteShows ?? [])
            .whereType<Map>()
            .any((entry) => entry['removed'] != true)) ...[
          const SizedBox(height: 18),
          _friendShows(context, user),
        ],
        if (controller.reviews.isNotEmpty) ...[
          const SizedBox(height: 18),
          shared.ReviewCard(
              showMediaTitle: true,
              review: controller.reviews.first,
              currentUserId: context.read<AuthProvider>().dbUser?.id),
        ],
      ];

  List<Widget> _activityContent(BuildContext context, User user) {
    if (controller.activityLoading && controller.activity.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 56),
          child: Center(
            child: CircularProgressIndicator(color: FlixieColors.primary),
          ),
        ),
      ];
    }
    if (controller.activityFailed && controller.activity.isEmpty) {
      return [
        TextButton(
            onPressed: controller.loadActivity,
            child: const Text('Couldn’t load activity. Retry'))
      ];
    }
    if (controller.activity.isEmpty) {
      return const [
        _EmptyProfileTab(
          icon: Icons.timeline_outlined,
          text: 'No public activity yet.',
        ),
      ];
    }
    return [
      if (user.watchedMovies?.isNotEmpty == true) ...[
        FriendMiniStats(watchedMovies: user.watchedMovies!),
        const SizedBox(height: 14),
      ],
      for (var index = 0; index < controller.activity.length; index++) ...[
        ActivityTile(
          item: controller.activity[index],
          compact: true,
          detailSource: DetailSource.friendActivity,
        ),
        if (index != controller.activity.length - 1) const SizedBox(height: 10),
      ],
      if (controller.activityCursor != null || controller.activityFailed)
        TextButton(
            onPressed: controller.activityLoading
                ? null
                : () => controller.loadActivity(more: true),
            child: Text(controller.activityFailed ? 'Retry' : 'Load more')),
    ];
  }

  List<Widget> _reviewsContent(BuildContext context) {
    if (controller.reviewsFailed) {
      return [
        TextButton(
            onPressed: controller.loadReviews,
            child: const Text('Couldn’t load reviews. Retry'))
      ];
    }
    if (controller.reviewsLoading) {
      return const [Center(child: CircularProgressIndicator())];
    }
    if (controller.reviews.isEmpty) {
      return const [
        _EmptyProfileTab(icon: Icons.reviews_outlined, text: 'No reviews yet.'),
      ];
    }
    return [
      for (final review in controller.reviews.take(controller.reviewLimit))
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: shared.ReviewCard(
                showMediaTitle: true,
                review: review,
                currentUserId: context.read<AuthProvider>().dbUser?.id)),
      if (controller.reviews.length > controller.reviewLimit)
        TextButton(
            onPressed: () =>
                controller.change(() => controller.reviewLimit += 10),
            child: const Text('Load more reviews')),
    ];
  }
}
