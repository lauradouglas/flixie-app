import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_poster_rail.dart';
import 'package:flixie_app/models/user.dart';

enum ProfileLibrary { watched, watchlist, favourites }

extension on ProfileLibrary {
  String get title => switch (this) {
        ProfileLibrary.watched => 'Watched',
        ProfileLibrary.watchlist => 'Watchlist',
        ProfileLibrary.favourites => 'Favourites',
      };
  Color color(BuildContext context) => switch (this) {
        ProfileLibrary.watched => context.colors.success,
        ProfileLibrary.watchlist => context.colors.warning,
        ProfileLibrary.favourites => context.colors.danger,
      };
}

List<Map<String, dynamic>> _entries(
    User user, ProfileLibrary library, bool shows) {
  final List<dynamic> entries = shows
      ? switch (library) {
          ProfileLibrary.watched => user.watchedShows ?? [],
          ProfileLibrary.watchlist => user.showWatchlist ?? [],
          ProfileLibrary.favourites => user.favoriteShows ?? [],
        }
      : switch (library) {
          ProfileLibrary.watched =>
            (user.watchedMovies ?? []).map((e) => e.toJson()).toList(),
          ProfileLibrary.watchlist =>
            (user.movieWatchlist ?? []).map((e) => e.toJson()).toList(),
          ProfileLibrary.favourites =>
            (user.favoriteMovies ?? []).map((e) => e.toJson()).toList(),
        };
  return entries
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where((e) => e['removed'] != true)
      .toList();
}

/// The whole column is a shortcut, including its movie/show breakdown.
class ProfileLibraryTotals extends StatelessWidget {
  const ProfileLibraryTotals({super.key, required this.user});
  final User user;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          for (final library in ProfileLibrary.values) ...[
            if (library != ProfileLibrary.watched)
              Container(
                  width: 1, height: 48, color: context.colors.tabBarBorder),
            Expanded(child: Builder(builder: (context) {
              final movies = _entries(user, library, false).length;
              final shows = _entries(user, library, true).length;
              return Semantics(
                button: true,
                label:
                    '${library.title}, ${movies + shows} titles. Open ${library.title.toLowerCase()}',
                child: InkWell(
                  key: ValueKey('profile-total-${library.name}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    switch (library) {
                      case ProfileLibrary.watched:
                        context.push('/watch-history');
                      case ProfileLibrary.watchlist:
                        context.go('/watchlist');
                      case ProfileLibrary.favourites:
                        showFavouriteMoviesSheet(
                            context, user.favoriteMovies ?? []);
                    }
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${movies + shows}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: library.color(context),
                              fontWeight: FontWeight.w900,
                              fontSize: 24)),
                      Text(library.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: context.colors.medium,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Text(
                          '$movies ${movies == 1 ? 'movie' : 'movies'} · $shows ${shows == 1 ? 'show' : 'shows'}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: context.colors.light)),
                    ]),
                  ),
                ),
              );
            })),
          ],
        ]),
      );
}
