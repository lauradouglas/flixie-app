import 'package:flixie_app/models/movie_short.dart';

class RecommendationAttribution {
  const RecommendationAttribution({
    required this.contentId,
    required this.contentType,
    required this.source,
    required this.position,
    required this.algorithm,
    required this.version,
    this.reason,
    this.predictedScore,
  });

  static const personalisedAlgorithm = 'weighted_taste_profile';
  static const currentPersonalisedVersion = 'v1';
  static const unknownAlgorithm = 'unknown';
  static const unknownVersion = 'unknown';

  static const _personalisedReasons = {
    'taste_profile',
    'rewatch',
    'popular_exploration',
  };
  static const _legacyReasons = {
    'legacy_tmdb_similarity',
    'popular_fallback',
  };
  static const allowedReasonCodes = {
    ..._personalisedReasons,
    ..._legacyReasons,
  };

  final int contentId;
  final String contentType;
  final String source;
  final int position;
  final String algorithm;
  final String version;
  final String? reason;
  final double? predictedScore;

  factory RecommendationAttribution.forPersonalisedMovie(
    MovieShort movie, {
    required int position,
  }) {
    final reason = movie.recommendationSourceTypes
        .where(allowedReasonCodes.contains)
        .firstOrNull;
    final algorithm = switch (reason) {
      'legacy_tmdb_similarity' => 'legacy_tmdb_similarity',
      'popular_fallback' => 'popular_fallback',
      _
          when movie.recommendationSourceTypes
              .any(_personalisedReasons.contains) =>
        personalisedAlgorithm,
      _ => unknownAlgorithm,
    };
    final score = movie.recommendationScore;
    return RecommendationAttribution(
      contentId: movie.id,
      contentType: movie.mediaType == 'show' ? 'show' : 'movie',
      source: 'just_for_you',
      position: position,
      algorithm: algorithm,
      version: algorithm == unknownAlgorithm
          ? unknownVersion
          : currentPersonalisedVersion,
      reason: reason,
      predictedScore:
          score == null || !score.isFinite ? null : score.clamp(0, 1),
    );
  }

  factory RecommendationAttribution.fromRoute({
    required int contentId,
    required String contentType,
    required Map<String, String> query,
  }) {
    final reason = query['recReason'];
    final score = double.tryParse(query['recScore'] ?? '');
    return RecommendationAttribution(
      contentId: contentId,
      contentType: contentType == 'show' ? 'show' : 'movie',
      source: query['recSource'] == 'just_for_you' ? 'just_for_you' : 'unknown',
      position: int.tryParse(query['recPosition'] ?? '')?.clamp(0, 1000) ?? 0,
      algorithm: _allowedAlgorithm(query['recAlgorithm']),
      version: query['recVersion'] == currentPersonalisedVersion
          ? currentPersonalisedVersion
          : unknownVersion,
      reason: allowedReasonCodes.contains(reason) ? reason : null,
      predictedScore:
          score == null || !score.isFinite ? null : score.clamp(0, 1),
    );
  }

  static String _allowedAlgorithm(String? value) {
    return const {
      personalisedAlgorithm,
      'legacy_tmdb_similarity',
      'popular_fallback',
    }.contains(value)
        ? value!
        : unknownAlgorithm;
  }

  Map<String, Object> get analyticsParameters => {
        'content_id': contentId,
        'content_type': contentType,
        'recommendation_source': source,
        'position': position,
        'recommendation_algorithm': algorithm,
        'recommendation_version': version,
        if (reason != null) 'recommendation_reason': reason!,
        if (predictedScore != null) 'predicted_score': predictedScore!,
      };

  Map<String, String> get routeParameters => {
        'recSource': source,
        'recPosition': position.toString(),
        'recAlgorithm': algorithm,
        'recVersion': version,
        if (reason != null) 'recReason': reason!,
        if (predictedScore != null) 'recScore': predictedScore!.toString(),
      };
}
