import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/features/home/data/trending_service.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import '../models/signup_journey.dart';
import 'setup_service.dart';

/// Mix related titles with current trends, preserving each source's ranking.
List<SetupTitle> mixJourneySuggestions(
    List<SetupTitle> related, List<SetupTitle> trending,
    {required String exclude}) {
  final seen = {exclude};
  final result = <SetupTitle>[];
  for (var i = 0; i < related.length || i < trending.length; i++) {
    for (final source in [related, trending]) {
      if (i < source.length && seen.add(source[i].key)) result.add(source[i]);
    }
  }
  return result.take(18).toList();
}

class SignupJourneyService {
  const SignupJourneyService();
  Future<({String? releaseDate, String? status})> movieRelease(int id) async {
    final movie = await MovieService().getMovieById(id);
    return (releaseDate: movie.releaseDate, status: movie.status);
  }

  Future<SetupTitle> title(SignupJourney journey) async {
    if (journey.isShow) {
      final show = await ShowService.getShowById(journey.mediaId);
      final season = journey.action == 'episode'
          ? show.seasons
              .where((s) => s.seasonNumber == journey.seasonNumber)
              .firstOrNull
          : null;
      return SetupTitle(
          show.id, show.name, season?.posterPath ?? show.posterPath,
          isShow: true);
    }
    final movie = await MovieService().getMovieById(journey.mediaId);
    return SetupTitle(movie.id, movie.title, movie.posterPath);
  }

  Future<List<SetupTitle>> initialSuggestions() async =>
      (await TrendingService.getTrendingMedia())
          .take(12)
          .map((m) => SetupTitle(m.id, m.name, m.poster,
              isShow: m.isShow, reason: 'Trending now'))
          .toList();
  Future<List<SetupTitle>> suggestions(SetupTitle title) async {
    Object? failure;
    Future<List<SetupTitle>> available(Future<List<SetupTitle>> request) async {
      try {
        return await request;
      } catch (error) {
        failure = error;
        return [];
      }
    }

    final sources = await Future.wait([
      available(const SetupService().recommendations([title])),
      available(TrendingService.getTrendingMedia().then((rows) => rows
          .map((m) => SetupTitle(m.id, m.name, m.poster,
              isShow: m.isShow, reason: 'Trending now'))
          .toList())),
    ]);
    if (sources.every((s) => s.isEmpty) && failure != null) throw failure!;
    return mixJourneySuggestions(sources[0], sources[1], exclude: title.key);
  }

  Future<void> saveTitle(String userId, SetupTitle title,
          {bool favourite = false}) =>
      favourite
          ? const SetupService().addProfileFavourite(userId, title)
          : const SetupService().addToWatchlist(userId, title);
  Future<void> rate(
      SignupJourney journey, int rating, String? recommendation) async {
    if (journey.isShow) {
      await ShowService.addShowRating(journey.mediaId, journey.userId, rating,
          recommendation: recommendation);
    } else {
      await MovieService().addMovieRating(
          journey.mediaId,
          journey.userId,
          rating,
          recommendation == null || recommendation == 'neutral'
              ? null
              : recommendation == 'recommend');
    }
  }

  Future<MovieWatchEntry> log(
      String userId, LogMovieWatchRequest request) async {
    final saved = await UserService.logMovieWatch(userId, request);
    await UserService.addToWatched(userId, request.movieId);
    return saved;
  }

  Future<void> episode(SignupJourney journey) async {
    if (!journey.isShow || journey.episodeId == null) {
      throw StateError('Choose an episode again from the show.');
    }
    // Verify that this is a real released episode of the intended show.
    final show = await ShowService.getShowById(journey.mediaId);
    final episode = TvShowEpisodeProgress(show)
        .releasedEpisodes
        .where((e) => e.id == journey.episodeId)
        .firstOrNull;
    if (episode == null) {
      throw StateError(
          'This episode is unavailable. Open the show and try again.');
    }
    await ShowService.updateEpisodeProgress(
        userId: journey.userId,
        showId: journey.mediaId,
        episodeId: journey.episodeId!,
        watched: true,
        watchedAt: DateTime.now().toUtc().toIso8601String());
  }
}
