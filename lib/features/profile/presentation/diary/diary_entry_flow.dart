import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/models/watch_log_details.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/external_watch_invite_sheet.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/watched_movie.dart';
import '../../data/diary_entry_service.dart';

Future<MovieWatchEntry?> editDiaryMemory(
  BuildContext context, {
  required AuthProvider auth,
  required DiaryEntryService service,
  MovieWatchEntry? entry,
  MovieShort? movie,
  DateTime? day,
}) async {
  final viewer = auth.dbUser?.id;
  if (viewer == null || (entry == null && movie == null)) return null;
  final movieId = entry?.movieId ?? movie!.id;
  final title = entry?.movie?.title ?? movie?.name;
  final draftId = const Uuid().v4();
  var details = const WatchLogDetails();
  MovieWatchEntry? saved;
  await showMovieWatchLogSheet<void>(
      context: context,
      movieId: movieId,
      movieTitle: title,
      releaseDate: entry?.movie?.releaseDate ?? movie?.releaseDate,
      editingExisting: entry != null,
      builder: (_) => RewatchLogSheet(
            initial: entry,
            movieTitle: title,
            initialWatchedAt: day?.toIso8601String(),
            loadFriends: entry?.externalInvite == null
                ? () => service.friends(viewer)
                : null,
            onDetailsChanged: (value) => details = value,
            onSubmit: (
                {required watchedAt,
                required rating,
                required recommended,
                required notes}) async {
              if (auth.dbUser?.id != viewer) {
                throw StateError('Your session changed. Reopen your diary.');
              }
              // A retry after an interrupted response reuses the same idempotency key.
              saved = entry == null
                  ? await service.log(
                      viewer,
                      LogMovieWatchRequest(
                        draftId: draftId,
                        movieId: movieId,
                        watchedAt: watchedAt,
                        rating: rating,
                        recommended: recommended,
                        notes: notes,
                        watchedAtCinema: details.watchedAtCinema,
                        companionId: details.companion?.id,
                        companionIds:
                            details.companions.map((p) => p.id).toList(),
                        externalCompanionName: details.externalCompanionName,
                      ))
                  : await service.update(
                      viewer,
                      entry.id,
                      UpdateMovieWatchRequest(
                        draftId: draftId,
                        movieId: movieId,
                        watchedAt: watchedAt,
                        rating: rating,
                        recommended: recommended,
                        notes: notes,
                        watchedAtCinema: details.watchedAtCinema,
                        companionId:
                            entry.planId == null ? details.companion?.id : null,
                        companionIds:
                            details.companions.map((p) => p.id).toList(),
                        externalCompanionName: details.externalCompanionName,
                      ));
              if (auth.dbUser?.id == viewer) {
                final watched = auth.dbUser?.watchedMovies ?? [];
                if (entry == null &&
                    !watched.any((item) =>
                        item.movieId == movieId && item.removed != true)) {
                  auth.updateUserList(watchedMovies: [
                    ...watched.where((item) => item.movieId != movieId),
                    WatchedMovie(
                        id: '',
                        userId: viewer,
                        movieId: movieId,
                        watchedAt: saved!.watchedAt,
                        rating: saved!.rating,
                        notes: saved!.notes,
                        removed: false,
                        movie: saved!.movie?.toJson() ??
                            {'id': movieId, 'title': title}),
                  ]);
                }
                auth.markActivityChanged();
              }
            },
          ));
  if (auth.dbUser?.id != viewer) return null;
  if (context.mounted && saved?.externalInvite?.available == true) {
    await showExternalWatchInviteSheet(
        context, saved!.externalInvite!, title ?? 'this film');
  }
  return saved;
}
