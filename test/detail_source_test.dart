import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/core/analytics/recommendation_attribution.dart';
import 'package:flixie_app/models/movie_short.dart';

void main() {
  test('detail source parser rejects arbitrary values', () {
    expect(DetailSource.fromValue('search'), DetailSource.search);
    expect(DetailSource.fromValue('made_up'), DetailSource.unknown);
    expect(DetailSource.fromValue(null), DetailSource.unknown);
  });

  test('person credits path includes its parent content attribution', () {
    expect(
      personDetailPath(
        88,
        source: DetailSource.personCredits,
        parentContentId: 42,
        parentContentType: 'movie',
      ),
      '/people/88?source=person_credits&parentContentId=42&parentContentType=movie',
    );
  });

  test('movie and show paths always carry an explicit source', () {
    expect(
      movieDetailPath(1, source: DetailSource.justForYou),
      '/movies/1?source=just_for_you',
    );
    expect(showDetailPath(2), '/shows/2?source=unknown');
  });

  test('personalised attribution uses backend source codes and score', () {
    const movie = MovieShort(
      id: 7,
      name: 'Example',
      mediaType: 'movie',
      recommendationScore: .82,
      recommendationSourceTypes: ['taste_profile'],
    );

    final attribution = RecommendationAttribution.forPersonalisedMovie(
      movie,
      position: 3,
    );

    expect(attribution.algorithm, 'weighted_taste_profile');
    expect(attribution.version, 'v1');
    expect(attribution.reason, 'taste_profile');
    expect(attribution.predictedScore, .82);
    expect(attribution.position, 3);
  });

  test('recommendation context survives the movie detail route', () {
    const attribution = RecommendationAttribution(
      contentId: 7,
      contentType: 'movie',
      source: 'just_for_you',
      position: 2,
      algorithm: 'weighted_taste_profile',
      version: 'v1',
      reason: 'rewatch',
      predictedScore: .75,
    );
    final uri = Uri.parse(movieDetailPath(
      7,
      source: DetailSource.justForYou,
      recommendation: attribution,
    ));
    final restored = RecommendationAttribution.fromRoute(
      contentId: 7,
      contentType: 'movie',
      query: uri.queryParameters,
    );

    expect(restored.analyticsParameters, attribution.analyticsParameters);
  });
}
