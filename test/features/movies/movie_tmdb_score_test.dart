import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import '../../support/api_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/movie.dart';
import '../../movie_detail_loading_test.dart' as fixture;

void main() {
  test('personal rating still posts to Flixie independently of TMDB score',
      () async {
    Map<String, dynamic>? saved;
    useApiFixture(MockClient((request) async {
      expect(request.url.path, endsWith('/movies/348/add/rating'));
      expect(request.method, 'POST');
      saved = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'rating': 9, 'voteAverage': 9}), 200);
    }));
    await MovieService().addMovieRating(348, 'fictional-viewer', 9, true);
    expect(saved, containsPair('rating', 9));
    expect(saved, containsPair('userId', 'fictional-viewer'));
    expect(saved!.containsKey('tmdbVoteAverage'), isFalse);
  });
  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(1194, 834)
  ]) {
    testWidgets('TMDB score and explanation at $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = fixture.GuestAuth();
      final movies = fixture.DelayedMovies();
      addTearDown(auth.dispose);
      await t.pumpWidget(fixture.app(auth, movies, '348'));
      movies.core[348]!.complete(const Movie(
        id: 348,
        title: 'Alien',
        voteAverage: 3,
        voteCount: 1,
        tmdbVoteAverage: 8.2,
        tmdbVoteCount: 15000,
      ));
      movies.providers.complete([]);
      movies.reviews.complete([]);
      await t.pumpAndSettle();
      expect(find.text('8.2/10'), findsOneWidget);
      expect(find.textContaining('FlixScore'), findsNothing);
      expect(find.textContaining('TMDB'), findsNothing);
      final info = find.widgetWithIcon(IconButton, Icons.info_outline_rounded);
      expect(t.getSize(info), const Size(48, 48));
      await t.tap(find.text('8.2/10'));
      await t.pumpAndSettle();
      expect(find.text('TMDB movie ratings'), findsNothing,
          reason: 'Only the separate info button opens the explanation');
      await t.tap(find.byIcon(Icons.info_outline_rounded).first);
      await t.pumpAndSettle();
      expect(find.text('TMDB movie ratings'), findsOneWidget);
      expect(
          find.text(
              'Scores come from TMDB. Ratings submitted through Flixie also '
              'contribute to TMDB, while being saved separately in Flixie.'),
          findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.text('Got it'));
      await t.pumpAndSettle();
      expect(find.text('TMDB movie ratings'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('missing TMDB score never falls back to Flixie average',
      (t) async {
    final auth = fixture.GuestAuth();
    final movies = fixture.DelayedMovies();
    addTearDown(auth.dispose);
    await t.pumpWidget(fixture.app(auth, movies, '348'));
    movies.core[348]!.complete(
        const Movie(id: 348, title: 'Alien', voteAverage: 9, voteCount: 3));
    movies.providers.complete([]);
    movies.reviews.complete([]);
    await t.pumpAndSettle();
    expect(find.text('Score unavailable'), findsOneWidget);
    expect(find.textContaining('9.0'), findsNothing);
    await t.tap(find.text('Score unavailable'));
    await t.pumpAndSettle();
    expect(find.text('TMDB movie ratings'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
