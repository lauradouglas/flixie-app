import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/home/presentation/widgets/section_header.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class FriendsWatchingSection extends StatelessWidget {
  const FriendsWatchingSection({super.key, required this.activity});

  final List<ActivityListItem> activity;

  @override
  Widget build(BuildContext context) {
    final items = activity
        .where((item) =>
            !item.removed &&
            item.type == ActivityListType.movieWatched &&
            item.movieId != null)
        .toList()
      ..sort((left, right) {
        final leftTime = DateTime.tryParse(left.timestamp);
        final rightTime = DateTime.tryParse(right.timestamp);
        if (leftTime != null && rightTime != null) {
          return rightTime.compareTo(leftTime);
        }
        return right.timestamp.compareTo(left.timestamp);
      });
    final recent = items.take(12).toList(growable: false);
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Friends watching',
          onSeeAll: () => context.push('/friends-activity'),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = recent[index];
              final rawPoster = item.mediaPosterPath;
              final posterUrl = rawPoster == null || rawPoster.isEmpty
                  ? null
                  : rawPoster.startsWith('http')
                      ? rawPoster
                      : 'https://image.tmdb.org/t/p/w342$rawPoster';
              return GestureDetector(
                onTap: () => context.push('/movies/${item.movieId}'),
                child: SizedBox(
                  width: 108,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: SizedBox(
                              width: 108,
                              height: 144,
                              child: posterUrl == null
                                  ? _friendPosterFallback()
                                  : CachedNetworkImage(
                                      imageUrl: posterUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          _friendPosterFallback(),
                                    ),
                            ),
                          ),
                          Positioned(
                            left: 7,
                            bottom: 7,
                            child: Container(
                              padding: const EdgeInsets.all(1.5),
                              decoration: const BoxDecoration(
                                color: FlixieColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: ProfileAvatarView(
                                avatar: item.avatar,
                                fallbackText: item.username.isEmpty
                                    ? '?'
                                    : item.username[0].toUpperCase(),
                                fallbackColor: FlixieColors.surfaceElevated,
                                size: 27,
                                profileBadges: item.profileBadges,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 7,
                            bottom: 7,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.68),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.visibility_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.mediaTitle ?? 'Movie',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

Widget _friendPosterFallback() {
  return Container(
    color: FlixieColors.tabBarBackgroundFocused,
    alignment: Alignment.center,
    child: const Icon(
      Icons.movie_outlined,
      color: FlixieColors.medium,
      size: 30,
    ),
  );
}

class TrendingEntry {
  final int movieId;
  final String title;
  final String? posterPath;
  final int friendCount;
  final List<String> friendNames;

  const TrendingEntry({
    required this.movieId,
    required this.title,
    this.posterPath,
    required this.friendCount,
    required this.friendNames,
  });
}

class TrendingAmongFriendsSection extends StatelessWidget {
  const TrendingAmongFriendsSection({super.key, required this.activity});

  final List<ActivityListItem> activity;

  List<TrendingEntry> _compute() {
    // Group by movieId, track unique users and first seen title/poster
    final Map<int, Set<String>> usersByMovie = {};
    final Map<int, String> titleByMovie = {};
    final Map<int, String?> posterByMovie = {};
    final Map<int, Map<String, String>> namesByMovie = {};

    for (final item in activity) {
      final id = item.movieId;
      if (id == null || item.mediaTitle == null) continue;
      usersByMovie.putIfAbsent(id, () => {}).add(item.userId);
      titleByMovie.putIfAbsent(id, () => item.mediaTitle!);
      posterByMovie.putIfAbsent(id, () => item.mediaPosterPath);
      namesByMovie.putIfAbsent(id, () => {})[item.userId] = item.username;
    }

    final entries = usersByMovie.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => TrendingEntry(
              movieId: e.key,
              title: titleByMovie[e.key]!,
              posterPath: posterByMovie[e.key],
              friendCount: e.value.length,
              friendNames: namesByMovie[e.key]!.values.take(3).toList(),
            ))
        .toList()
      ..sort((a, b) => b.friendCount.compareTo(a.friendCount));

    return entries.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _compute();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(title: 'Trending Among Friends'),
        const SizedBox(height: 12),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final entry = items[i];
              return GestureDetector(
                onTap: () => context.push('/movies/${entry.movieId}'),
                child: SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 110,
                              height: 145,
                              child: entry.posterPath != null
                                  ? CachedNetworkImage(
                                      imageUrl:
                                          'https://image.tmdb.org/t/p/w185${entry.posterPath}',
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: FlixieColors
                                            .tabBarBackgroundFocused,
                                        child: const Icon(Icons.movie_outlined,
                                            color: FlixieColors.medium),
                                      ),
                                    )
                                  : Container(
                                      color:
                                          FlixieColors.tabBarBackgroundFocused,
                                      child: const Icon(Icons.movie_outlined,
                                          color: FlixieColors.medium),
                                    ),
                            ),
                          ),
                          if (entry.friendCount > 1)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: FlixieColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${entry.friendCount} friends',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
