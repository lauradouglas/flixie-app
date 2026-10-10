import 'package:flixie_app/core/storage/library_image_warmup.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/watchlist/domain/release_status.dart';
import 'package:flixie_app/models/friend_recommendation.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/watchlist_movie.dart';

import 'watchlist_friends_viewing.dart';
import 'watchlist_poster_placeholder.dart';
import 'watchlist_providers_inline.dart';

class WatchlistMovieRow extends StatelessWidget {
  final bool isShow, isLoadingFriends, friendsFailed, providersFailed;
  final String region;
  final String? metadataOverride;
  final VoidCallback? onRetryFriends, onRetryProviders, onEditPreferences;
  final WatchlistMovie watchlistItem;
  final bool isWatched;
  final List<WatchProvider> availableProviders;
  final Set<int> userWatchProviderIds;
  final Set<String> userWatchProviderMatchKeys;
  final bool canWatchNow;
  final bool isLoadingProviders;
  final List<FriendRecommendationItem> recommendations;
  final VoidCallback onTap;
  final VoidCallback onMarkAsWatched;
  final VoidCallback? onAddToFavourites;
  final VoidCallback? onAddToList;
  final VoidCallback? onRequestToWatch;
  final VoidCallback onRemove;

  const WatchlistMovieRow({
    super.key,
    this.isShow = false,
    this.isLoadingFriends = false,
    this.friendsFailed = false,
    this.providersFailed = false,
    this.region = 'GB',
    this.metadataOverride,
    this.onRetryFriends,
    this.onRetryProviders,
    this.onEditPreferences,
    required this.watchlistItem,
    required this.isWatched,
    this.availableProviders = const <WatchProvider>[],
    this.userWatchProviderIds = const <int>{},
    this.userWatchProviderMatchKeys = const <String>{},
    this.canWatchNow = false,
    this.isLoadingProviders = false,
    this.recommendations = const [],
    required this.onTap,
    required this.onMarkAsWatched,
    this.onAddToFavourites,
    this.onAddToList,
    this.onRequestToWatch,
    required this.onRemove,
  });

  static String _runtimeLabel(int? minutes) {
    if (minutes == null || minutes == 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final movie = watchlistItem.movie;
    if (movie == null) return const SizedBox.shrink();
    final metadata = metadataOverride ??
        [
          if (movie.releaseDate?.isNotEmpty == true)
            movie.releaseDate!.split('-').first,
          if (_runtimeLabel(movie.runtime).isNotEmpty)
            _runtimeLabel(movie.runtime),
          ...movie.genres.take(2),
          if (isWatched) 'Watched',
        ].join(' · ');
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(
              label: '${movie.title} poster',
              image: true,
              button: true,
              onTap: onTap,
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 68,
                      height: 102,
                      child: movie.posterPath == null
                          ? const WatchlistPosterPlaceholder()
                          : CachedNetworkImage(
                              memCacheWidth: watchlistPosterDecodeWidth(
                                  MediaQuery.devicePixelRatioOf(context)),
                              imageUrl:
                                  'https://image.tmdb.org/t/p/w342${movie.posterPath}',
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  const WatchlistPosterPlaceholder(),
                              errorWidget: (_, __, ___) =>
                                  const WatchlistPosterPlaceholder(),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: InkWell(
                    onTap: onTap,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(movie.title,
                                style: TextStyle(
                                    color: context.colors.textPrimary,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(metadata,
                                style: TextStyle(
                                    color: context.colors.light, fontSize: 13)),
                            const SizedBox(height: 7),
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              FlixiePill.label(
                                  label: Text(isShow ? 'Show' : 'Movie')),
                              if (releaseStatus(movie.releaseDate) ==
                                  ReleaseStatus.comingSoon)
                                const FlixiePill.label(
                                  avatar: Icon(Icons.event_outlined),
                                  label: Text('Coming soon'),
                                ),
                            ]),
                            if (releaseStatus(movie.releaseDate) ==
                                ReleaseStatus.comingSoon) ...[
                              const SizedBox(height: 4),
                              Text('Releases ${_formatDate(movie.releaseDate)}',
                                  style: TextStyle(
                                      color: context.colors.light,
                                      fontSize: 13)),
                            ],
                          ]),
                    ))),
            PopupMenuButton<String>(
              tooltip: 'More actions',
              color: context.colors.surfaceElevated,
              onSelected: (value) {
                switch (value) {
                  case 'details':
                    onTap();
                  case 'watched':
                    onMarkAsWatched();
                  case 'favourite':
                    onAddToFavourites?.call();
                  case 'list':
                    onAddToList?.call();
                  case 'request_watch':
                    onRequestToWatch?.call();
                  case 'remove':
                    onRemove();
                }
              },
              itemBuilder: (_) => [
                if (_formatDate(watchlistItem.createdAt).isNotEmpty)
                  PopupMenuItem<String>(
                      enabled: false,
                      child: Text(
                          'Added ${_formatDate(watchlistItem.createdAt)}')),
                const PopupMenuItem(
                    value: 'details', child: Text('Title details')),
                PopupMenuItem(
                    value: 'watched',
                    child: Text(isShow
                        ? 'Manage episodes & watched status'
                        : 'Mark as Watched')),
                if (!isShow || onAddToFavourites != null)
                  const PopupMenuItem(
                      value: 'favourite', child: Text('Add to favourites')),
                if (!isShow || onAddToList != null)
                  const PopupMenuItem(
                      value: 'list', child: Text('Add to list')),
                if (!isShow || onRequestToWatch != null)
                  const PopupMenuItem(
                      value: 'request_watch', child: Text('Invite friends')),
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
              child: Semantics(
                  label: 'Actions for ${movie.title}',
                  button: true,
                  child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.more_horiz_rounded,
                          color: context.colors.light))),
            ),
          ]),
          const SizedBox(height: 8),
          WatchlistFriendsViewing(
              movieId: movie.id,
              friends: recommendations,
              title: movie.title,
              isShow: isShow,
              loading: isLoadingFriends,
              failed: friendsFailed,
              onRetry: onRetryFriends),
          WatchlistProvidersInline(
              providers: availableProviders,
              userWatchProviderIds: userWatchProviderIds,
              userWatchProviderMatchKeys: userWatchProviderMatchKeys,
              isLoading: isLoadingProviders,
              failed: providersFailed,
              region: region,
              onRetry: onRetryProviders,
              onEditPreferences: onEditPreferences),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).brightness == Brightness.light
                ? context.colors.textPrimary.withValues(alpha: .2)
                : context.colors.tabBarBorder,
          ),
        ]),
      ),
    );
  }
}
