import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/core/utils/favourite_limits.dart';

List<FavouriteDisplayItem> favouriteMovieItems(List<FavoriteMovie> movies) {
  final ranked = movies.where((e) => e.removed != true).toList()
    ..sort((a, b) => (a.rank ?? 999).compareTo(b.rank ?? 999));
  return ranked.map((favorite) {
    final movie = favorite.movie ?? const <String, dynamic>{};
    return FavouriteDisplayItem(
      title: movie['title']?.toString() ?? 'Movie',
      imagePath: movie['posterPath']?.toString(),
      route: '/movies/${favorite.movieId}',
    );
  }).toList(growable: false);
}

void showFavouriteMoviesSheet(
    BuildContext context, List<FavoriteMovie> movies) {
  FavouritePosterRail(
    title: 'Favourite movies',
    items: favouriteMovieItems(movies),
    limit: maxFavouriteMovies,
  ).showAll(context);
}

List<FavouriteDisplayItem> favouriteShowItems(List<dynamic> shows) {
  final ranked = shows
      .whereType<Map>()
      .where((e) => e['removed'] != true)
      .toList()
    ..sort((a, b) => ((a['rank'] as num?)?.toInt() ?? 999)
        .compareTo((b['rank'] as num?)?.toInt() ?? 999));
  return ranked.map((outer) {
    final show = outer['show'] is Map ? outer['show'] as Map : outer;
    final id = show['id'] ?? outer['showId'];
    return FavouriteDisplayItem(
        title: (show['title'] ?? show['name'] ?? 'Show').toString(),
        imagePath: show['posterPath']?.toString(),
        route: id == null ? null : '/shows/$id');
  }).toList();
}

void showAllFavouritesSheet(
    BuildContext context, List<FavoriteMovie> movies, List<dynamic> shows) {
  showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheet) => SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .8,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                child: Row(children: [
                  const Expanded(
                      child: Text('Favourite films & shows',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800))),
                  IconButton(
                      tooltip: 'Close favourites',
                      onPressed: () => Navigator.pop(sheet),
                      icon: const Icon(Icons.close)),
                ])),
            Expanded(
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                  for (final group in [
                    ('Films', favouriteMovieItems(movies)),
                    ('Shows', favouriteShowItems(shows))
                  ]) ...[
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('${group.$1} (${group.$2.length})',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700))),
                    if (group.$2.isEmpty)
                      Text('No favourite ${group.$1.toLowerCase()} yet.'),
                    for (final item in group.$2)
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.title),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: item.route == null
                              ? null
                              : () {
                                  final router = GoRouter.of(context);
                                  Navigator.pop(sheet);
                                  router.push(item.route!);
                                }),
                  ],
                ])),
          ])));
}

class FavouriteDisplayItem {
  const FavouriteDisplayItem({
    required this.title,
    required this.imagePath,
    required this.route,
  });

  final String title;
  final String? imagePath;
  final String? route;
}

class FavouritePosterRail extends StatelessWidget {
  const FavouritePosterRail({
    super.key,
    required this.title,
    required this.items,
    this.limit,
    this.circular = false,
    this.onRank,
    this.onSeeAll,
  });

  final VoidCallback? onRank;
  final VoidCallback? onSeeAll;
  final String title;
  final List<FavouriteDisplayItem> items;
  final int? limit;
  final bool circular;

  void showAll(BuildContext context) {
    showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => SizedBox(
            height: MediaQuery.sizeOf(context).height * .8,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 8, 12),
                child: Row(children: [
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: context.colors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(
                          limit == null
                              ? '${items.length} favourites'
                              : '${items.length} of $limit favourites',
                          style: TextStyle(
                              fontSize: 13, color: context.colors.light)),
                    ],
                  )),
                  IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ]),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (sheetContext, index) {
                    final item = items[index];
                    final raw = item.imagePath;
                    final url = raw == null
                        ? null
                        : raw.startsWith('http')
                            ? raw
                            : 'https://image.tmdb.org/t/p/w185$raw';
                    return Material(
                      color: context.colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: item.route == null
                            ? null
                            : () {
                                final router = GoRouter.of(context);
                                Navigator.pop(sheetContext);
                                router.push(item.route!);
                              },
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(children: [
                            if (!circular) ...[
                              SizedBox(
                                  width: 26,
                                  child: Text('${index + 1}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: context.colors.primaryText))),
                              const SizedBox(width: 10),
                            ],
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(circular ? 50 : 6),
                              child: SizedBox(
                                  width: 44,
                                  height: circular ? 44 : 66,
                                  child: url == null
                                      ? const Icon(Icons.movie_outlined)
                                      : Image.network(url,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                  Icons.movie_outlined))),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Text(item.title,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: context.colors.textPrimary))),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right,
                                size: 20, color: context.colors.light),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: FlixieSectionHeader(title: title)),
          if (onRank != null)
            IconButton(
              tooltip:
                  title == 'Favourite shows' ? 'Rank shows' : 'Rank movies',
              onPressed: onRank,
              icon: Icon(Icons.format_list_numbered,
                  color: context.colors.primaryText, size: 22),
            ),
          TextButton(
            onPressed: onSeeAll ?? () => showAll(context),
            child: Text(title.startsWith('Favourite ') ? 'All (${items.length})' : 'See all',
                style: TextStyle(color: context.colors.primaryText, fontSize: 14)),
          ),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final tablet = constraints.maxWidth >= 550;
          final width = tablet
              ? ((constraints.maxWidth - 40) / 5).clamp(104.0, 160.0)
              : 104.0;
          final posterHeight = circular
              ? width - 8
              : tablet
                  ? width * 1.5
                  : 146.0;
          var titleHeight = MediaQuery.textScalerOf(context).scale(36);
          {
            for (final item in (circular ? items : items.take(10))) {
              final painter = TextPainter(
                text: TextSpan(
                    text: item.title,
                    style: DefaultTextStyle.of(context).style.merge(
                        const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700))),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: width);
              if (painter.height > titleHeight) titleHeight = painter.height;
              painter.dispose();
            }
          }
          return SizedBox(
            height: posterHeight + 6 + titleHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: circular ? items.length : items.length.clamp(0, 10),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final rawPath = item.imagePath;
                final imageUrl = rawPath == null
                    ? null
                    : rawPath.startsWith('http')
                        ? rawPath
                        : 'https://image.tmdb.org/t/p/w342$rawPath';
                return SizedBox(
                  width: width,
                  child: InkWell(
                    onTap: item.route == null
                        ? null
                        : () => context.push(item.route!),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            circular ? 999 : 10,
                          ),
                          child: SizedBox(
                            width: circular ? width - 8 : width,
                            height: posterHeight,
                            child: imageUrl == null
                                ? ColoredBox(
                                    color: context.colors.surfaceElevated,
                                    child: Icon(
                                      Icons.favorite_outline_rounded,
                                      color: context.colors.medium,
                                    ),
                                  )
                                : Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.image_not_supported_outlined,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          style: TextStyle(
                            color: context.colors.light,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}
