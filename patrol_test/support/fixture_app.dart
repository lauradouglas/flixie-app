import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';

/// Test-only authentication. Never initializes Firebase or uses a real account.
class FixtureAuth extends ChangeNotifier implements AuthProvider {
  FixtureAuth({int count = 10})
      : _user = User(
          id: 'patrol-viewer',
          username: 'Patrol viewer',
          email: '',
          iconColorId: 0,
          completedSetup: true,
          darkMode: false,
          favoriteMovies: List.generate(
              count,
              (i) => FavoriteMovie(
                  id: 'movie-fav-$i',
                  movieId: i + 1,
                  userId: 'patrol-viewer',
                  rank: i + 1,
                  movie: {'title': 'Film ${i + 1}'})),
          favoriteShows: List.generate(
              count,
              (i) => {
                    'id': 'show-fav-$i',
                    'showId': i + 101,
                    'rank': i + 1,
                    'show': {'id': i + 101, 'title': 'Show ${i + 1}'},
                  }),
        );
  User _user;
  @override
  User get dbUser => _user;
  @override
  int activityVersion = 0;
  @override
  void markActivityChanged() {
    activityVersion++;
    notifyListeners();
  }

  @override
  void updateUserList({
    List<WatchedMovie>? watchedMovies,
    List<dynamic>? watchedShows,
    List<WatchlistMovie>? movieWatchlist,
    List<dynamic>? showWatchlist,
    List<FavoriteMovie>? favoriteMovies,
    List<dynamic>? favoriteShows,
    List<dynamic>? favoritePeople,
  }) {
    _user = _user.copyWith(
      favoriteMovies: favoriteMovies ?? _user.favoriteMovies,
      favoriteShows: favoriteShows ?? _user.favoriteShows,
    );
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
      'Unconfigured auth call: ${invocation.memberName}');
}

Widget fixtureApp(FixtureAuth auth, Widget home, {bool dark = false}) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: home,
      ),
    );
