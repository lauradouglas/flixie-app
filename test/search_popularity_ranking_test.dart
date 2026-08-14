import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/models/search_result.dart';

void main() {
  test('mixed search results are ranked by TMDB popularity', () {
    final results = <SearchResultItem>[
      SearchResultItem.fromJson({
        'id': 1,
        'media_type': 'movie',
        'title': 'Exact title match',
        'popularity': 12,
      }),
      SearchResultItem.fromJson({
        'id': 2,
        'media_type': 'tv',
        'name': 'Popular show',
        'popularity': 80,
      }),
      SearchResultItem.fromJson({
        'id': 3,
        'media_type': 'movie',
        'title': 'Popular movie',
        'popularity': 120,
      }),
    ];

    final ranked = rankSearchResultsByPopularity(results);

    expect(ranked.map((item) => item.movie?.id ?? item.show?.id), [3, 2, 1]);
  });

  test('all search groups movies before shows and ranks each by popularity',
      () {
    final results = <SearchResultItem>[
      SearchResultItem.fromJson({
        'id': 1,
        'media_type': 'tv',
        'name': 'Very popular show',
        'popularity': 500,
      }),
      SearchResultItem.fromJson({
        'id': 2,
        'media_type': 'movie',
        'title': 'Movie two',
        'popularity': 20,
      }),
      SearchResultItem.fromJson({
        'id': 3,
        'media_type': 'movie',
        'title': 'Movie one',
        'popularity': 40,
      }),
    ];

    final ranked = rankSearchResultsByPopularity(
      results,
      groupByMediaType: true,
    );

    expect(ranked.map((item) => item.movie?.id ?? item.show?.id), [3, 2, 1]);
  });
}
