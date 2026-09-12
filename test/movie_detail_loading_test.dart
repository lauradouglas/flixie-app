import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/models/movie_credits.dart';
import 'package:flixie_app/models/movie_images.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/similar_movie.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_detail_screen.dart';

class GuestAuth extends ChangeNotifier implements AuthProvider {
  @override
  User? get dbUser => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class DelayedMovies extends MovieService {
  final core = <int, Completer<Movie>>{};
  var reviews = Completer<List<Review>>();
  final providers = Completer<List<WatchProvider>>();
  int creditCalls = 0;
  @override
  Future<Movie> getMovieById(int id, {String? userId}) =>
      (core[id] ??= Completer<Movie>()).future;
  @override
  Future<List<Review>> getMovieReviews(int id, {String? userId}) =>
      reviews.future;
  @override
  Future<List<WatchProvider>> getMovieWatchProviders(int id, String region) =>
      providers.future;
  @override
  Future<List<SimilarMovie>> getMovieRecommendations(int id) async => [];
  @override
  Future<MovieCredits> getMovieCredits(int id) async {
    creditCalls++;
    if (creditCalls == 1) throw Exception('fixture credits failure');
    return const MovieCredits(castMembers: [], crewMembers: []);
  }

  @override
  Future<MovieImages> getMovieImages(int id) async => const MovieImages();
}

Widget app(GuestAuth auth, DelayedMovies movies, String id) =>
    MultiProvider(providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      Provider<MovieService>.value(value: movies),
    ], child: MaterialApp(home: MovieDetailScreen(movieId: id)));
void main() {
  testWidgets(
      'core renders while optional work is held; optional errors retry independently',
      (tester) async {
    final auth = GuestAuth();
    final movies = DelayedMovies();
    addTearDown(auth.dispose);
    await tester.pumpWidget(app(auth, movies, '1'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Useful movie'), findsNothing);
    movies.core[1]!.complete(
        const Movie(id: 1, title: 'Useful movie', overview: 'Useful synopsis'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Useful movie'), findsWidgets);
    expect(movies.reviews.isCompleted, false);
    expect(movies.providers.isCompleted, false);
    expect(find.text('Loading watch providers…'), findsOneWidget);
    // The core is useful at virtual t=100ms. Full loading is still pending.
    await tester.pump(const Duration(milliseconds: 4900));
    movies.providers.complete([]);
    movies.reviews.complete([]);
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(
        find.text('Couldn’t load cast and crew'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find
            .ancestor(
                of: find.text('Couldn’t load cast and crew'),
                matching: find.byType(Row))
            .first,
        matching: find.text('Retry')));
    await tester.pump();
    await tester.pump();
    expect(movies.creditCalls, 2);
    // The title can be disposed by the sliver while the credits are visible.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.text('Useful movie'), findsWidgets);
    expect(tester.takeException(), isNull);
    debugPrint(
        'Virtual fixture: useful content=100ms; optional work settled=5000ms (not frame performance).');
  });

  testWidgets(
      'refresh waits for optional completion and discards old review results',
      (tester) async {
    final auth = GuestAuth();
    final movies = DelayedMovies();
    addTearDown(auth.dispose);
    await tester.pumpWidget(app(auth, movies, '1'));
    movies.core[1]!.complete(const Movie(id: 1, title: 'First result'));
    await tester.pump();
    await tester.pump();
    final oldReviews = movies.reviews;
    movies.reviews = Completer<List<Review>>();
    movies.core[1] = Completer<Movie>();
    var complete = false;
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh()
        .then((_) => complete = true);
    movies.core[1]!.complete(const Movie(id: 1, title: 'Refreshed result'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Refreshed result'), findsWidgets);
    expect(complete, false);
    movies.providers.complete([]);
    movies.reviews.complete([]);
    await tester.pump();
    await refresh;
    oldReviews.complete([
      Review.fromJson(
          {'id': 'stale', 'title': 'Stale review', 'body': 'Stale body'})
    ]);
    await tester.pump();
    await tester.pump();
    // Open the Reviews tab after the stale response completes.
    await tester.scrollUntilVisible(find.text('Reviews').first, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Reviews').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reviews').first);
    await tester.pumpAndSettle();
    expect(find.text('Stale review'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late core response cannot replace a newly navigated movie',
      (tester) async {
    final auth = GuestAuth();
    final movies = DelayedMovies();
    addTearDown(auth.dispose);
    await tester.pumpWidget(app(auth, movies, '1'));
    await tester.pumpWidget(app(auth, movies, '2'));
    movies.core[2]!.complete(const Movie(id: 2, title: 'Current movie'));
    await tester.pump();
    await tester.pump();
    movies.core[1]!.complete(const Movie(id: 1, title: 'Old movie'));
    movies.reviews.complete([]);
    movies.providers.complete([]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Current movie'), findsWidgets);
    expect(find.text('Old movie'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
