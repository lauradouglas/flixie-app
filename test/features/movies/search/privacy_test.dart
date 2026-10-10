import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/movies/presentation/widgets/search/search_media_tile.dart';
import 'package:flixie_app/features/movies/presentation/widgets/search/search_default_view.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/search_result.dart';

void main() {
  testWidgets('Search respects movie rating privacy in results and trending',
      (tester) async {
    final privacy = MovieRatingPrivacy()
      ..userId = 'viewer'
      ..loaded = true
      ..enabled = true;
    addTearDown(privacy.dispose);
    final result = SearchResults.fromJson({
      'results': [
        {'id': 348, 'title': 'Alien', 'media_type': 'movie', 'voteAverage': 8.5}
      ]
    }).results.single;
    await tester.pumpWidget(ChangeNotifierProvider<MovieRatingPrivacy>.value(
        value: privacy,
        child: MaterialApp(
            home: Scaffold(
                body: Column(children: [
          SearchMediaTile.movie(movie: result.movie!, query: 'Alien'),
          const SearchTrendingCard(
              movie: MovieShort(
                  id: 348,
                  name: 'Alien',
                  voteAverage: 8.5,
                  releaseDate: '1979-05-25')),
        ])))));
    await tester.pumpAndSettle();
    expect(find.textContaining('8.5'), findsNothing);
    privacy.ratingSaved('viewer', 348, 8);
    await tester.pumpAndSettle();
    expect(find.textContaining('8.5'), findsNWidgets(2));
  });
}
