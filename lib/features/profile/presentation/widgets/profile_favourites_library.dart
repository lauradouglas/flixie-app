import 'package:flixie_app/features/profile/presentation/widgets/favourite_poster_rail.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_ranking_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/core/utils/favourite_limits.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';

class ProfileFavouritesLibrary extends StatelessWidget {
  const ProfileFavouritesLibrary({
    super.key,
    required this.movies,
    required this.shows,
    required this.people,
  });

  final List<dynamic> movies;
  final List<dynamic> people;
  final List<dynamic> shows;

  Widget _empty(BuildContext context, String title, String action) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FlixieSectionHeader(title: title),
          TextButton.icon(
              onPressed: () => context.push('/search'),
              icon: const Icon(Icons.add, size: 18),
              label: Text(action)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final movieItems =
        favouriteMovieItems(movies.whereType<FavoriteMovie>().toList());
    final rankedShows = shows
        .whereType<Map>()
        .where((e) => e['removed'] != true)
        .toList()
      ..sort((a, b) => ((a['rank'] as num?)?.toInt() ?? 999)
          .compareTo((b['rank'] as num?)?.toInt() ?? 999));
    final showItems = rankedShows.map((raw) {
      final outer =
          raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
      final show = outer['show'] is Map<String, dynamic>
          ? outer['show'] as Map<String, dynamic>
          : outer;
      final id = show['id'] ?? outer['showId'];
      return FavouriteDisplayItem(
        title: (show['title'] ?? show['name'] ?? 'Show').toString(),
        imagePath: show['posterPath']?.toString(),
        route: id == null ? null : '/shows/$id',
      );
    }).toList(growable: false);
    final peopleItems = people.map((raw) {
      final person =
          raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
      final id = person['id'] ?? person['personId'];
      return FavouriteDisplayItem(
        title: (person['name'] ?? 'Person').toString(),
        imagePath:
            (person['profileImgUrl'] ?? person['profilePath'])?.toString(),
        route: id == null ? null : '/people/$id',
      );
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (movieItems.isNotEmpty)
          FavouritePosterRail(
            title: 'Favourite films',
            items: movieItems,
            limit: maxFavouriteMovies,
            onRank: () => showFavouriteRankingSheet(context, shows: false),
          ),
        if (movieItems.isEmpty)
          _empty(context, 'Favourite films', 'Add favourite films'),
        const SizedBox(height: 18),
        if (showItems.isNotEmpty)
          FavouritePosterRail(
            title: 'Favourite shows',
            items: showItems,
            limit: maxFavouriteShows,
            onRank: () => showFavouriteRankingSheet(context, shows: true),
          ),
        if (showItems.isEmpty)
          _empty(context, 'Favourite shows', 'Add favourite shows'),
        const SizedBox(height: 18),
        if (peopleItems.isNotEmpty)
          FavouritePosterRail(
            title: 'Favourite people',
            items: peopleItems,
            circular: true,
          ),
        if (peopleItems.isEmpty)
          _empty(context, 'Favourite people', 'Add favourite people'),
      ],
    );
  }
}
