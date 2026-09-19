import 'package:flutter/material.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/models/watch_provider.dart';

class TestAuth extends ChangeNotifier implements AuthProvider {
  List<int> ids = [1];
  final providerRequests = <List<int>>[];
  Future<void>? providerGate;
  @override
  int activityVersion = 0;
  @override
  int friendDataVersion = 0;
  @override
  User get dbUser => User(
      id: 'viewer',
      username: 'Me',
      email: '',
      iconColorId: 0,
      completedSetup: true,
      darkMode: true,
      movieWatchlist: ids
          .map((id) => WatchlistMovie(
              id: '$id',
              userId: 'viewer',
              movieId: id,
              movie: WatchlistMovieDetails(id: id, title: 'Film $id')))
          .toList());
  @override
  Map<int, List<WatchProvider>> get cachedWatchProvidersByMovieId =>
      {for (final id in ids) id: []};
  @override
  Set<int> get cachedUserWatchProviderIds => {};
  @override
  Future<void> ensureWatchProviderCache({Iterable<int>? movieIds}) async {
    providerRequests.add(movieIds?.toList() ?? []);
    await providerGate;
  }

  @override
  Future<void> refreshUserData() async {
    notifyListeners();
  }

  void notifyOnly() => notifyListeners();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
