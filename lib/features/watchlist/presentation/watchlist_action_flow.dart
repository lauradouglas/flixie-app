import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/favourite_limits.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/features/movies/presentation/widgets/add_to_list_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_limit_sheet.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';

import '../data/watchlist_data_service.dart';
import '../models/watchlist_show_entry.dart';
import 'controllers/watchlist_controller.dart';
import 'widgets/watchlist_movie_search_sheet.dart';

/// Presents Watchlist action sheets, analytics and success/error feedback.
/// Persisted changes go through the data service; list state stays in the controller.
class WatchlistActionFlow {
  WatchlistActionFlow(
      {required this.context,
      required WatchlistController watchlist,
      WatchlistDataService? service})
      : _watchlist = watchlist,
        _service = service ?? const WatchlistDataService();

  final BuildContext context;
  final WatchlistController _watchlist;
  final WatchlistDataService _service;

  Future<void> addMovie() async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    if (user == null) return;

    final existingMovieIds =
        _watchlist.allWatchlist.map((item) => item.movieId).toSet();
    final selected = await showModalBottomSheet<MovieShort>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WatchlistMovieSearchSheet(
        existingMovieIds: existingMovieIds,
        service: _service,
      ),
    );
    if (!context.mounted || selected == null) return;

    if (existingMovieIds.contains(selected.id)) {
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.info,
            content: Text('${selected.name} is already in your watchlist')),
      );
      return;
    }

    try {
      final addedResponse = await _service.addToWatchlist(user.id, selected.id);
      await analytics.watchlistAdded(
        contentType: 'movie',
        contentId: selected.id,
        source: 'watchlist',
      );
      final added = _entryWithMovieFallback(addedResponse, selected);
      final currentWatchlist =
          List<WatchlistMovie>.from(user.movieWatchlist ?? []);
      currentWatchlist.removeWhere((item) => item.movieId == selected.id);
      currentWatchlist.add(added);

      authProvider.updateUserList(movieWatchlist: currentWatchlist);
      authProvider.markActivityChanged();
      _watchlist.addMovie(added);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.success,
            content: Text('${selected.name} added to watchlist'),
            backgroundColor: context.colors.surfaceElevated,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding movie to watchlist: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
          type: FlixieToastType.error,
          content: const Text('Failed to add movie to watchlist'),
          backgroundColor: context.colors.danger,
        ),
      );
    }
  }

  Future<bool> _confirmWatchEntry(
    WatchlistMovie item,
    String userId,
  ) async {
    var didSubmit = false;
    final analytics = context.read<AnalyticsController>();
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RewatchLogSheet(
        onSubmit: ({
          required String? watchedAt,
          required double? rating,
          required bool? recommended,
          required String? notes,
        }) async {
          await _service.logMovieWatch(
            userId,
            LogMovieWatchRequest(
              movieId: item.movieId,
              watchedAt: watchedAt,
              rating: rating,
              recommended: recommended,
              notes: notes,
            ),
          );
          if (rating != null) {
            await analytics.ratingSaved(source: 'watchlist');
          }
          didSubmit = true;
          if (context.mounted) {
            context.read<AuthProvider>().markActivityChanged();
          }
        },
      ),
    );
    return didSubmit;
  }

  WatchlistMovie _entryWithMovieFallback(
    WatchlistMovie entry,
    MovieShort movie,
  ) {
    if (entry.movie != null) return entry;
    return WatchlistMovie(
      id: entry.id,
      userId: entry.userId,
      movieId: entry.movieId,
      removed: entry.removed,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      movie: WatchlistMovieDetails(
        id: movie.id,
        title: movie.name,
        posterPath: movie.poster,
        releaseDate: movie.releaseDate,
        voteAverage: movie.voteAverage,
      ),
    );
  }

  Future<void> markAsWatched(WatchlistMovie item) async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    if (user == null) return;
    final committed = await _confirmWatchEntry(item, user.id);
    if (!committed || !context.mounted) return;

    try {
      // The submitted watch entry marks the movie as watched. Only now remove
      // it from the watchlist and update local state.
      await _service.removeFromWatchlist(user.id, item.movieId);
      await analytics.watchlistItemRemoved(source: 'watchlist');
      await analytics.movieRemovedFromWatchlist();
      final watchedMovie = await _service.addToWatched(user.id, item.movieId);

      // Update the local user lists
      final currentWatchlist =
          List<WatchlistMovie>.from(user.movieWatchlist ?? []);
      currentWatchlist.removeWhere((w) => w.movieId == item.movieId);

      final currentWatched = List<WatchedMovie>.from(user.watchedMovies ?? []);
      // Add the watched movie (prefer the API response, fallback to minimal object)
      currentWatched.add(watchedMovie ??
          WatchedMovie(
            id: '',
            userId: user.id,
            movieId: item.movieId,
            watchedAt: DateTime.now().toIso8601String(),
          ));

      // Update provider with both lists
      authProvider.updateUserList(
        movieWatchlist: currentWatchlist,
        watchedMovies: currentWatched,
      );
      authProvider.markActivityChanged();

      // Update local state
      _watchlist.removeMovies({item.movieId});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.success,
            content: Text('${item.movie?.title ?? "Movie"} marked as watched'),
            backgroundColor: context.colors.surfaceElevated,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking as watched: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Failed to mark as watched'),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    }
  }

  Future<void> removeMovie(WatchlistMovie item) async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    if (user == null) return;

    // Check if already in watched list before removing
    final alreadyWatched = user.isMovieWatched(item.movieId);

    try {
      await _service.removeFromWatchlist(user.id, item.movieId);
      await analytics.watchlistItemRemoved(source: 'watchlist');
      await analytics.movieRemovedFromWatchlist();

      // Update the local user list
      final currentWatchlist =
          List<WatchlistMovie>.from(user.movieWatchlist ?? []);
      currentWatchlist.removeWhere((w) => w.movieId == item.movieId);

      // Update provider
      authProvider.updateUserList(movieWatchlist: currentWatchlist);

      _watchlist.removeMovies({item.movieId});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.success,
            content:
                Text('${item.movie?.title ?? "Movie"} removed from watchlist'),
          ),
        );
      }

      // If not already in watched list, offer to add it
      if (!alreadyWatched && context.mounted) {
        final markWatched = await showFlixiePromptSheet<bool>(
          context: context,
          builder: (ctx) => FlixiePromptSheetContent(
            title: Text('Did you watch it?',
                style: TextStyle(color: context.colors.light)),
            content: Text(
                'Want to add ${item.movie?.title ?? "this movie"} to your watched list?',
                style: TextStyle(color: context.colors.medium)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child:
                    Text('No', style: TextStyle(color: context.colors.medium)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes!',
                    style: TextStyle(color: FlixieColors.primary)),
              ),
            ],
          ),
        );
        if (markWatched == true && context.mounted) {
          final committed = await _confirmWatchEntry(item, user.id);
          if (!committed || !context.mounted) return;
          final watchedResult =
              await _service.addToWatched(user.id, item.movieId);
          final currentWatched =
              List<WatchedMovie>.from(user.watchedMovies ?? []);
          currentWatched.add(watchedResult ??
              WatchedMovie(
                id: '',
                userId: user.id,
                movieId: item.movieId,
                watchedAt: DateTime.now().toIso8601String(),
              ));
          authProvider.updateUserList(watchedMovies: currentWatched);
          authProvider.markActivityChanged();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showFlixieToast(
              FlixieToast(
                type: FlixieToastType.success,
                content: Text(
                    '${item.movie?.title ?? "Movie"} added to watched list'),
                backgroundColor: context.colors.surfaceElevated,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Failed to remove from watchlist'),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    }
  }

  Future<void> clearWatchedMovies() async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    if (user == null) return;
    final watchedIds =
        user.watchedMovies?.map((item) => item.movieId).toSet() ?? <int>{};
    final watchedItems = _watchlist.allWatchlist
        .where((item) => watchedIds.contains(item.movieId))
        .toList();
    if (watchedItems.isEmpty) return;

    final confirmed = await showFlixiePromptSheet<bool>(
          context: context,
          builder: (dialogContext) => FlixiePromptSheetContent(
            title: const Text('Clear watched movies?'),
            content: Text(
              'Remove ${watchedItems.length} watched ${watchedItems.length == 1 ? 'movie' : 'movies'} from your watchlist? Your watch history will not be affected.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.danger,
                ),
                child: const Text('Clear watched'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await Future.wait(watchedItems.map(
        (item) => _service.removeFromWatchlist(user.id, item.movieId),
      ));
      await analytics.watchlistItemRemoved(source: 'watchlist');
      await analytics.movieRemovedFromWatchlist();
      final idsToRemove = watchedItems.map((item) => item.movieId).toSet();
      final updatedWatchlist = (user.movieWatchlist ?? [])
          .where((item) => !idsToRemove.contains(item.movieId))
          .toList();
      authProvider.updateUserList(movieWatchlist: updatedWatchlist);
      if (!context.mounted) return;
      _watchlist.removeMovies(idsToRemove);
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
          type: FlixieToastType.success,
          content: Text(
            '${watchedItems.length} watched ${watchedItems.length == 1 ? 'movie' : 'movies'} removed from your watchlist',
          ),
          backgroundColor: context.colors.surfaceElevated,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
          type: FlixieToastType.error,
          content: const Text('Failed to clear watched movies'),
          backgroundColor: context.colors.danger,
        ),
      );
    }
  }

  Future<void> addToFavourites(WatchlistMovie item) async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    if (user == null) return;

    final movieId = item.movieId;
    if (user.isMovieFavorite(movieId)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.info,
            content: Text(
              '${item.movie?.title ?? "Movie"} is already in favourites',
            ),
          ),
        );
      }
      return;
    }

    final activeFavouriteCount =
        (user.favoriteMovies ?? const <FavoriteMovie>[])
            .where((favorite) => favorite.removed != true)
            .length;
    if (activeFavouriteCount >= maxFavouriteMovies) {
      if (context.mounted) {
        showFavouriteLimitPrompt(
          context,
          type: FavouriteLimitType.movie,
          onSpaceMade: () => addToFavourites(item),
        );
      }
      return;
    }

    try {
      final addedFavorite = await _service.addToFavorites(user.id, movieId);
      await analytics.movieFavourited();
      final updatedFavorites =
          List<FavoriteMovie>.from(user.favoriteMovies ?? []);
      if (!updatedFavorites.any((f) => f.movieId == movieId)) {
        updatedFavorites.add(addedFavorite);
      }

      authProvider.updateUserList(favoriteMovies: updatedFavorites);
      authProvider.markActivityChanged();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.success,
            content:
                Text('${item.movie?.title ?? "Movie"} added to favourites'),
            backgroundColor: context.colors.surfaceElevated,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
      if (context.mounted) {
        if (isFavouriteLimitError(e)) {
          showFavouriteLimitPrompt(
            context,
            type: FavouriteLimitType.movie,
            onSpaceMade: () => addToFavourites(item),
          );
        } else {
          ScaffoldMessenger.of(context).showFlixieToast(
            FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to add to favourites'),
              backgroundColor: context.colors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> addToList(WatchlistMovie item) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddToListSheet(movieId: item.movieId),
    );
  }

  void requestWatch(WatchlistMovie item) {
    final auth = context.read<AuthProvider>();
    final friends = auth.cachedFriends?.friendships ?? [];
    final userId = auth.dbUser?.id;
    if (userId == null) return;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MovieWatchRequestSheet(
        movieId: item.movieId,
        movieTitle: item.movie?.title,
        requesterId: userId,
        friends: friends,
        onSuccess: () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showFlixieToast(
              FlixieToast(
                  type: FlixieToastType.success,
                  content: const Text('Watch Plan sent!')),
            );
          }
        },
        onError: () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showFlixieToast(
              FlixieToast(
                  type: FlixieToastType.error,
                  content: const Text('Failed to send Watch Plan')),
            );
          }
        },
      ),
    );
  }

  Future<void> removeShow(WatchlistShowEntry item) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.dbUser;
    if (user == null) return;
    try {
      await _service.removeShowFromWatchlist(user.id, item.showId);
      final updated = List<dynamic>.from(user.showWatchlist ?? const [])
        ..removeWhere((entry) {
          if (entry is! Map) return false;
          return watchlistInt(entry['showId']) == item.showId;
        });
      authProvider.updateUserList(showWatchlist: updated);
      if (!context.mounted) return;
      _watchlist.removeShow(item.showId);
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.success,
            content: Text('${item.title} removed from watchlist')),
      );
    } catch (error) {
      logger.w('[Watchlist] Show removal failed: $error');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Couldn’t remove show from watchlist'),
            action: SnackBarAction(
                label: 'Retry',
                onPressed: () {
                  if (context.mounted) removeShow(item);
                })),
      );
    }
  }
}
