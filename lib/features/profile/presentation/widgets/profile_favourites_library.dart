import 'profile_favourite_people.dart';
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
    this.featuredPeople = const {},
    this.onChoosePerson,
    this.savingPeople = false,
  });

  final Map<String, int> featuredPeople;
  final Future<void> Function(String, int?)? onChoosePerson;
  final bool savingPeople;
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
    final showItems = favouriteShowItems(shows);

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
        ProfileFavouritePeople(
            people: people,
            featured: featuredPeople,
            onChoose: onChoosePerson,
            saving: savingPeople),
      ],
    );
  }
}
