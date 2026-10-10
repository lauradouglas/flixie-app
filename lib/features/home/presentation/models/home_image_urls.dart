import 'package:flixie_app/models/continue_watching_show.dart';
import 'package:flixie_app/models/movie_short.dart';

/// Share exact cache URLs between Home's visible cards and bounded preloading.
String? homeImageUrl(String? path, String size) {
  if (path == null || path.trim().isEmpty) return null;
  return path.startsWith('http')
      ? path
      : 'https://image.tmdb.org/t/p/$size$path';
}

String? homeHeroImageUrl(String? poster) => homeImageUrl(poster, 'w780');
String? homeRecommendationImageUrl(String? poster) =>
    homeImageUrl(poster, 'w500');
String? homeContinueWatchingImageUrl(ContinueWatchingShow show) =>
    homeImageUrl(show.backdropPath ?? show.posterPath, 'w780');

List<String> homeImageWarmupUrls({
  required Iterable<MovieShort> trending,
  required Iterable<MovieShort> recommendations,
  required Iterable<ContinueWatchingShow> continueWatching,
}) =>
    {
      ...trending
          .take(2)
          .map((movie) => homeHeroImageUrl(movie.poster))
          .whereType<String>(),
      ...recommendations
          .take(2)
          .map((movie) => homeRecommendationImageUrl(movie.poster))
          .whereType<String>(),
      ...continueWatching
          .take(1)
          .map(homeContinueWatchingImageUrl)
          .whereType<String>(),
    }.toList(growable: false);
