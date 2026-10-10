import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/controllers/movie_detail_controller.dart';
import 'package:flixie_app/features/movies/presentation/movie_detail_action_flow.dart';
import 'package:flixie_app/features/watchlist/presentation/controllers/watchlist_actions_controller.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import '../../movie_detail_loading_test.dart' show DelayedMovies;

class ActionAuth extends ChangeNotifier implements AuthProvider {
  User? account;
  @override
  User? get dbUser => account;
  @override
  void markActivityChanged() {}
  @override
  void updateUserList(
      {List<WatchedMovie>? watchedMovies,
      List<dynamic>? watchedShows,
      List<WatchlistMovie>? movieWatchlist,
      List<dynamic>? showWatchlist,
      List<FavoriteMovie>? favoriteMovies,
      List<dynamic>? favoriteShows,
      List<dynamic>? favoritePeople}) {
    account = account!.copyWith(
        movieWatchlist: movieWatchlist ?? account!.movieWatchlist,
        favoriteMovies: favoriteMovies ?? account!.favoriteMovies);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class ActionAnalytics extends ChangeNotifier implements AnalyticsController {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class ActionData extends WatchlistActionsController {
  bool fail = false;
  int watchlistSaves = 0;
  Completer<WatchlistMovie>? gate;
  @override
  Future<WatchlistMovie> addToWatchlist(String userId, int movieId) async {
    watchlistSaves++;
    if (fail) throw StateError('Fixture unavailable');
    if (gate != null) return gate!.future;
    return WatchlistMovie(id: 'saved', userId: userId, movieId: movieId);
  }

  @override
  Future<FavoriteMovie> addToFavorites(String userId, int movieId) async =>
      FavoriteMovie(id: 'favourite', userId: userId, movieId: movieId);
  @override
  Future<void> removeFromFavorites(String userId, int movieId) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<(ActionAuth, MovieDetailController, ActionData)> fixture() async {
    final auth = ActionAuth();
    final service = DelayedMovies();
    service.core[1] = Completer<Movie>()
      ..complete(const Movie(id: 1, title: 'The Odyssey'));
    service.reviews.complete([]);
    service.providers.complete([]);
    final actions = ActionData();
    final controller =
        MovieDetailController(auth: auth, service: service, actions: actions);
    await controller.load('1');
    auth.account = const User(
        id: 'fictional-viewer',
        username: 'Fixture',
        email: '',
        iconColorId: 0,
        completedSetup: false,
        darkMode: true,
        favoriteMovies: [],
        movieWatchlist: []);
    addTearDown(() {
      controller.dispose();
      auth.dispose();
    });
    return (auth, controller, actions);
  }

  Widget app(ActionAuth auth, MovieDetailController data) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<AnalyticsController>(
                create: (_) => ActionAnalytics()),
          ],
          child: MaterialApp(
              home: Scaffold(
                  body: Builder(
                      builder: (context) => ListenableBuilder(
                          listenable: data,
                          builder: (_, __) => Column(children: [
                                Text(data.inWatchlist
                                    ? 'Saved title'
                                    : 'Unsaved title'),
                                Text(data.isFavorite
                                    ? 'Favourite title'
                                    : 'Not favourite'),
                                TextButton(
                                    onPressed: () => MovieDetailActionFlow(
                                            context: context, data: data)
                                        .toggleWatchlist(offerUndo: false),
                                    child: const Text('Save title')),
                                TextButton(
                                    onPressed: () => MovieDetailActionFlow(
                                            context: context, data: data)
                                        .toggleFavorite(offerUndo: false),
                                    child: const Text('Toggle favourite')),
                              ]))))));

  testWidgets('failed save preserves library and Retry commits the title',
      (tester) async {
    final (auth, data, actions) = await fixture();
    actions.fail = true;
    await tester.pumpWidget(app(auth, data));
    await tester.tap(find.text('Save title'));
    await tester.pumpAndSettle();
    expect(data.inWatchlist, false);
    expect(auth.dbUser!.movieWatchlist, isEmpty);
    expect(data.currentlyUpdating, isNull);
    actions.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Saved title'), findsOneWidget);
    expect(auth.dbUser!.movieWatchlist!.single.movieId, 1);
    expect(actions.watchlistSaves, 2);
  });
  testWidgets('favourite save and removal update persisted local membership',
      (tester) async {
    final (auth, data, _) = await fixture();
    await tester.pumpWidget(app(auth, data));
    await tester.tap(find.text('Toggle favourite'));
    await tester.pumpAndSettle();
    expect(data.isFavorite, true);
    expect(auth.dbUser!.favoriteMovies!.single.movieId, 1);
    await tester.tap(find.text('Toggle favourite'));
    await tester.pumpAndSettle();
    expect(data.isFavorite, false);
    expect(auth.dbUser!.favoriteMovies, isEmpty);
  });
  testWidgets('late previous viewer save cannot publish into the new viewer',
      (tester) async {
    final (auth, data, actions) = await fixture();
    actions.gate = Completer<WatchlistMovie>();
    await tester.pumpWidget(app(auth, data));
    await tester.tap(find.text('Save title'));
    await tester.pump();
    auth.account = auth.account!.copyWith(id: 'another-fictional-viewer');
    actions.gate!.complete(const WatchlistMovie(
        id: 'saved', userId: 'fictional-viewer', movieId: 1));
    await tester.pumpAndSettle();
    expect(data.inWatchlist, false);
    expect(auth.dbUser!.movieWatchlist, isEmpty);
    expect(find.text('Added to watchlist'), findsNothing);
  });
}
