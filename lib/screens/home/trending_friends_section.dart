import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity_list_item.dart';
import '../../theme/app_theme.dart';
import 'section_header.dart';

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
