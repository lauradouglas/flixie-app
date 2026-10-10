import 'package:flixie_app/features/profile/presentation/widgets/favourite_poster_rail.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';

import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/continue_watching_show.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/features/profile/presentation/widgets/lists_preview_section.dart';
import 'package:flixie_app/features/home/presentation/widgets/continue_watching_carousel.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';

import 'profile_favourites_library.dart';

class ProfileLibraryTab extends StatelessWidget {
  const ProfileLibraryTab(
      {super.key,
      required this.userId,
      required this.favoriteMovies,
      required this.favoritePeople,
      required this.favoriteShows,
      required this.activity,
      required this.continueWatching,
      required this.watchProviders,
      required this.loadingExtras,
      required this.failedExtras,
      required this.loadingActivity,
      required this.onRemoveShow,
      required this.onManageProviders,
      required this.onRatings,
      required this.onRetryExtras});
  final String? userId;
  final List<dynamic> favoriteMovies, favoritePeople, favoriteShows;
  final List<ActivityListItem> activity;
  final List<ContinueWatchingShow> continueWatching;
  final List<WatchProvider> watchProviders;
  final bool loadingExtras, failedExtras, loadingActivity;
  final ValueChanged<ContinueWatchingShow> onRemoveShow;
  final VoidCallback onManageProviders, onRatings, onRetryExtras;
  Widget _libraryRow(BuildContext context,
          {required IconData icon,
          required String label,
          required VoidCallback onPressed}) =>
      Column(children: [
        ListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 52,
            leading: Icon(icon, size: 20, color: context.colors.secondary),
            title: Text(label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: onPressed),
        Divider(height: 1, color: context.colors.tabBarBorder),
      ]);

  @override
  Widget build(BuildContext context) {
    final userId = this.userId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileFavouritesLibrary(
          movies: favoriteMovies,
          people: favoritePeople,
          shows: favoriteShows,
        ),
        const SizedBox(height: 20),
        if (loadingExtras) ...[
          const _ProfileExtrasLoadingIndicator(),
          const SizedBox(height: 20),
        ],
        if (failedExtras)
          TextButton.icon(
              onPressed: onRetryExtras,
              icon: const Icon(Icons.refresh),
              label: const Text('Couldn’t load profile details · Retry')),
        _libraryRow(context,
            icon: Icons.bookmark_outline,
            label: 'Watchlist',
            onPressed: () => context.push('/watchlist')),
        const SizedBox(height: 20),
        if (userId != null) ...[
          ListsPreviewSection(
            userId: userId,
            title: 'Your lists',
            emptyMessage:
                'Keep a little collection of your own. Rainy-day films? A director you love?',
            allowManage: true,
            embedded: true,
          ),
          const SizedBox(height: 20),
        ],
        if (loadingActivity && activity.isEmpty)
          const ContentPlaceholder(
              label: 'Loading recently watched',
              style: ContentPlaceholderStyle.posters)
        else
          _recentlyWatched(context),
        const SizedBox(height: 20),
        if (continueWatching.isNotEmpty) ...[
          _ProfileContinueWatching(
            shows: continueWatching,
            onRemove: onRemoveShow,
          ),
          const SizedBox(height: 20),
        ],
        _libraryRow(
          context,
          icon: Icons.rate_review_outlined,
          label: 'Reviews',
          onPressed: () => context.push('/my-reviews'),
        ),
        _libraryRow(
          context,
          icon: Icons.star_outline,
          label: 'Ratings',
          onPressed: onRatings,
        ),
        const SizedBox(height: 20),
        _WatchProvidersSummary(
          providers: watchProviders,
          onManage: onManageProviders,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _recentlyWatched(BuildContext context) {
    final watches = activity
        .where((item) =>
            !item.removed &&
            (item.type == ActivityListType.movieWatched ||
                item.type == ActivityListType.showWatched ||
                item.watchLogged))
        .toList()
      ..sort((a, b) => (DateTime.tryParse(b.watchedAt ?? b.timestamp) ??
              DateTime(1970))
          .compareTo(
              DateTime.tryParse(a.watchedAt ?? a.timestamp) ?? DateTime(1970)));
    final seen = <String>{};
    final items = <FavouriteDisplayItem>[];
    for (final item in watches) {
      final route = item.showId != null
          ? '/shows/${item.showId}'
          : item.movieId != null
              ? '/movies/${item.movieId}'
              : null;
      if (route == null || !seen.add(route)) continue;
      items.add(FavouriteDisplayItem(
          title: item.mediaTitle ?? 'View title',
          imagePath: item.mediaPosterPath,
          route: route));
      if (items.length == 10) break;
    }
    if (items.isEmpty) {
      return _ProfileEmptyAction(
        icon: Icons.movie_outlined,
        title: 'Find your next watch',
        body:
            'Explore films and shows, or log something you’ve already watched.',
        label: 'Explore films & shows',
        onPressed: () => context.push('/search'),
      );
    }
    return FavouritePosterRail(
        title: 'Recently watched',
        items: items,
        onSeeAll: () => context.push('/watch-history'));
  }
}

class _ProfileContinueWatching extends StatelessWidget {
  const _ProfileContinueWatching({
    required this.shows,
    required this.onRemove,
  });

  final List<ContinueWatchingShow> shows;
  final ValueChanged<ContinueWatchingShow> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlixieSectionHeader(
          title: 'Continue watching',
        ),
        const SizedBox(height: 10),
        ContinueWatchingCarousel(
          shows: shows.take(10).toList(),
          contentPadding: EdgeInsets.zero,
          onTap: (show) => context.push(showDetailPath(show.showId)),
          onRemove: onRemove,
        ),
      ],
    );
  }
}

class _ProfileExtrasLoadingIndicator extends StatelessWidget {
  const _ProfileExtrasLoadingIndicator();

  @override
  Widget build(BuildContext context) => const ContentPlaceholder(
      label: 'Loading profile details', style: ContentPlaceholderStyle.compact);
}

class _WatchProvidersSummary extends StatelessWidget {
  const _WatchProvidersSummary({
    required this.providers,
    required this.onManage,
  });

  final List<WatchProvider> providers;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.live_tv_outlined, color: FlixieColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Watch providers',
                  style: TextStyle(
                    color: context.colors.light,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  providers.isEmpty
                      ? 'Choose where you stream'
                      : providers
                              .take(3)
                              .map((provider) => provider.providerName)
                              .join(' · ') +
                          (providers.length > 3
                              ? ' +${providers.length - 3}'
                              : ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.medium,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onManage,
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }
}

class _ProfileEmptyAction extends StatelessWidget {
  const _ProfileEmptyAction({
    required this.icon,
    required this.title,
    required this.body,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.tabBarBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FlixieColors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: FlixieColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    color: context.colors.medium,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: label,
            onPressed: onPressed,
            style: IconButton.styleFrom(
              backgroundColor: FlixieColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }
}
