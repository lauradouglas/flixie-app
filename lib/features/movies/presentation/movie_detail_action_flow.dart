import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/movies/data/movie_watch_plan_choice.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_ranking_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/core/utils/favourite_limits.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_limit_sheet.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/core/reviews/app_review_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/movies/presentation/widgets/add_to_list_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/analytics/recommendation_attribution.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/share_card_sheet.dart';

import 'controllers/movie_detail_controller.dart';

/// Sheets, persisted save/log/rating/review actions and their user feedback.
/// A flow is scoped to the movie load generation and viewer that invoked it.
class MovieDetailActionFlow {
  MovieDetailActionFlow(
      {required this.context, required this.data, this.recommendation})
      : _generation = data.generation,
        _viewer = data.auth.dbUser?.id;
  final BuildContext context;
  final MovieDetailController data;
  final RecommendationAttribution? recommendation;
  final int _generation;
  final String? _viewer;
  bool get isCurrent =>
      context.mounted &&
      !data.isDisposed &&
      data.generation == _generation &&
      data.auth.dbUser?.id == _viewer;

  Future<void> toggleWatchlist({bool offerUndo = true}) async {
    if (!await GuestAccess.require(context,
        title: 'Save this film for later',
        message:
            'Create an account to keep your watchlist and come back to this film whenever you’re ready.',
        path: '/movies/${data.movieId}',
        intent: 'watchlist')) return;
    if (!context.mounted) return;
    if (!context.mounted || !isCurrent || data.currentlyUpdating != null) {
      return;
    }
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    final movieId = data.movieId;

    if (user == null || movieId == null) return;

    data.change(() => data.currentlyUpdating = ListUpdateType.watchlist);

    try {
      final result = await (data.inWatchlist
          ? data.actions.removeFromWatchlist(user.id, movieId)
          : data.actions.addToWatchlist(user.id, movieId));
      if (data.inWatchlist) {
        await analytics.watchlistRemoved(
          contentType: 'movie',
          contentId: movieId,
          source: 'movie_detail',
        );
      } else {
        await analytics.watchlistAdded(
          contentType: 'movie',
          contentId: movieId,
          source: 'movie_detail',
        );
        final recommendation = this.recommendation;
        if (recommendation != null) {
          await analytics.recommendationSaved(
            attribution: recommendation,
          );
        }
        await AppReviewService.recordMovieInteraction(
          user.id,
          hasCompletedSetup: user.completedSetup,
        );
      }

      // Successfully updated on server, toggle UI state and update user list
      if (context.mounted && isCurrent) {
        HapticFeedback.lightImpact();
        data.change(() {
          data.inWatchlist = !data.inWatchlist;
          data.currentlyUpdating = null;
        });

        // Keep existing entries, then append or remove the affected entry.
        final currentWatchlist =
            List<WatchlistMovie>.from(user.movieWatchlist ?? []);

        if (data.inWatchlist) {
          // Added
          currentWatchlist.removeWhere((item) => item.movieId == movieId);
          final details = data.movie;
          currentWatchlist.add(details == null
              ? result
              : WatchlistMovie.fromJson({
                  ...result.toJson(),
                  'movie': {
                    ...details.toJson(),
                    ...?result.movie?.toJson(),
                    'releaseDate':
                        result.movie?.releaseDate ?? details.releaseDate,
                    'runtime': result.movie?.runtime ?? details.runtime,
                    'voteAverage':
                        result.movie?.voteAverage ?? details.voteAverage,
                    'genres':
                        details.genres?.map((genre) => genre.name).toList() ??
                            [],
                  },
                }));
          authProvider.markActivityChanged();
          authProvider.updateUserList(movieWatchlist: currentWatchlist);
        } else {
          // Removed
          currentWatchlist.removeWhere((item) => item.movieId == movieId);
          authProvider.updateUserList(movieWatchlist: currentWatchlist);
          // Offer to mark as watched if not already
          if (context.mounted && offerUndo && !data.isWatched && isCurrent) {
            final markWatched = await showFlixiePromptSheet<bool>(
              context: context,
              builder: (ctx) => FlixiePromptSheetContent(
                title: Text('Did you watch it?',
                    style: TextStyle(color: context.colors.light)),
                content: Text('Want to add this to your watched list?',
                    style: TextStyle(color: context.colors.medium)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('No',
                        style: TextStyle(color: context.colors.medium)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Yes!',
                        style: TextStyle(color: FlixieColors.primary)),
                  ),
                ],
              ),
            );
            if (context.mounted && markWatched == true && isCurrent) {
              final committed = await showLogWatchSheet();
              if (context.mounted && committed && isCurrent) {
                data.change(() => data.isWatched = true);
              }
            }
          }
        }
        if (context.mounted && isCurrent) {
          final savedState = data.inWatchlist;
          ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.success,
            content: Text(
                savedState ? 'Added to watchlist' : 'Removed from watchlist'),
            action: offerUndo
                ? SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      if (context.mounted &&
                          isCurrent &&
                          data.currentlyUpdating == null &&
                          data.inWatchlist == savedState) {
                        toggleWatchlist(offerUndo: false);
                      }
                    })
                : null,
          ));
        }
      }
    } catch (e) {
      logger.e('Error toggling watchlist: $e');
      if (context.mounted && isCurrent) {
        data.change(() => data.currentlyUpdating = null);
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Couldn’t update your watchlist'),
              action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () {
                    if (context.mounted &&
                        isCurrent &&
                        data.currentlyUpdating == null) {
                      toggleWatchlist();
                    }
                  })),
        );
      }
    }
  }

  Future<void> toggleFavorite({bool offerUndo = true}) async {
    if (!await GuestAccess.require(context,
        title: 'Save your favourites',
        path: '/movies/${data.movieId}',
        intent: 'favorite')) return;
    if (!context.mounted) return;
    if (!context.mounted || !isCurrent || data.currentlyUpdating != null) {
      return;
    }
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    final movieId = data.movieId;

    if (user == null || movieId == null) return;

    final activeFavouriteCount =
        (user.favoriteMovies ?? const <FavoriteMovie>[])
            .where((favorite) => favorite.removed != true)
            .length;
    if (!data.isFavorite && activeFavouriteCount >= maxFavouriteMovies) {
      showFavouriteLimitPrompt(
        context,
        type: FavouriteLimitType.movie,
        onSpaceMade: toggleFavorite,
      );
      return;
    }

    data.change(() => data.currentlyUpdating = ListUpdateType.favorite);
    try {
      final FavoriteMovie? addedFavorite;
      if (data.isFavorite) {
        await data.actions.removeFromFavorites(user.id, movieId);
        await analytics.movieUnfavourited();
        addedFavorite = null;
      } else {
        addedFavorite = await data.actions.addToFavorites(user.id, movieId);
        await analytics.movieFavourited();
      }

      // Successfully updated on server, toggle UI state and update user list
      if (context.mounted && isCurrent) {
        HapticFeedback.lightImpact();
        data.change(() {
          data.isFavorite = !data.isFavorite;
          data.currentlyUpdating = null;
        });

        List<FavoriteMovie> updatedFavorites;
        if (data.isFavorite) {
          // Added
          updatedFavorites =
              List<FavoriteMovie>.from(user.favoriteMovies ?? []);
          if (addedFavorite != null &&
              !updatedFavorites.any((f) => f.movieId == movieId)) {
            updatedFavorites.add(addedFavorite);
          }
          authProvider.markActivityChanged();
        } else {
          // Removed
          updatedFavorites = (user.favoriteMovies ?? [])
              .where((f) => f.movieId != movieId)
              .toList();
        }
        authProvider.updateUserList(favoriteMovies: updatedFavorites);
        final savedState = data.isFavorite;
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
          type: FlixieToastType.success,
          content: Text(
              savedState ? 'Added to favourites' : 'Removed from favourites'),
          action: savedState
              ? SnackBarAction(
                  label: 'Rank',
                  onPressed: () {
                    if (context.mounted && isCurrent) {
                      showFavouriteRankingSheet(context, shows: false);
                    }
                  })
              : offerUndo
                  ? SnackBarAction(
                      label: 'Undo',
                      onPressed: () {
                        if (context.mounted &&
                            isCurrent &&
                            data.currentlyUpdating == null &&
                            data.isFavorite == savedState) {
                          toggleFavorite(offerUndo: false);
                        }
                      })
                  : null,
        ));
      }
    } catch (e) {
      logger.e('Error toggling favorite: $e');
      if (context.mounted && isCurrent) {
        data.change(() => data.currentlyUpdating = null);
        if (isFavouriteLimitError(e)) {
          showFavouriteLimitPrompt(
            context,
            type: FavouriteLimitType.movie,
            onSpaceMade: toggleFavorite,
          );
        } else {
          ScaffoldMessenger.of(context).showFlixieToast(
            FlixieToast(
                type: FlixieToastType.error,
                content: const Text('Couldn’t update your favourites'),
                action: SnackBarAction(
                    label: 'Retry',
                    onPressed: () {
                      if (context.mounted &&
                          isCurrent &&
                          data.currentlyUpdating == null) {
                        toggleFavorite();
                      }
                    })),
          );
        }
      }
    }
  }

  Future<void> showAddToListSheet() async {
    if (!await GuestAccess.require(context,
        title: 'Build your film lists',
        path: '/movies/${data.movieId}',
        intent: 'list')) return;
    if (!context.mounted) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    final movieId = data.movieId;
    if (movieId == null) return;
    await showModalBottomSheet<void>(
      useRootNavigator: true,
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AddToListSheet(
        movieId: movieId,
        movieTitle: data.movie?.title,
        moviePosterPath: data.movie?.posterPath,
        movieReleaseDate: data.movie?.releaseDate,
        movieRuntimeMinutes: data.movie?.runtime,
        movieRatingLabel: !hideMovieRatings(sheetContext, movieId) &&
                data.movie?.voteAverage != null
            ? '★ ${data.movie!.voteAverage!.toStringAsFixed(1)}'
            : null,
      ),
    );
    if (userId != null) {
      await data.loadListsContainingMovie(userId, movieId);
    }
  }

  Future<bool> showLogWatchSheet({MovieWatchEntry? entry}) async {
    if (!await GuestAccess.require(context,
        title: 'Log your movie entry',
        message:
            'Create an account to log when you watched this film, add a rating and keep your movie diary.',
        path: '/movies/${data.movieId}',
        intent: 'log')) return false;
    if (!context.mounted) return false;
    final movieId = data.movieId;
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final movieService = context.read<MovieService>();
    final userId = authProvider.dbUser?.id;
    if (movieId == null || userId == null) return false;
    final plans =
        entry == null ? MovieWatchPlanChoice.load(userId, movieId) : null;
    MovieWatchPlanChoice? selectedPlan;
    var didSubmit = false;
    var writeReview = false;
    String? reviewWatchEntryId = entry?.id;
    double? reviewRating;
    bool? reviewRecommended;
    String? shareNote;
    await showModalBottomSheet<void>(
      useRootNavigator: true,
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RewatchLogSheet(
        initial: entry,
        watchPlans: plans,
        onPlanSelected: (plan) => selectedPlan = plan,
        isRewatch: entry == null && data.movieWatchHistory.isNotEmpty,
        previousWatch: entry == null && data.movieWatchHistory.isNotEmpty
            ? data.movieWatchHistory.first
            : null,
        showReviewOption: entry == null,
        onReviewSelected: (selected) => writeReview = selected,
        onSubmit: ({
          required String? watchedAt,
          required double? rating,
          required bool? recommended,
          required String? notes,
        }) async {
          try {
            reviewRating = rating;
            reviewRecommended = recommended;
            shareNote = notes;
            if (entry == null) {
              if (selectedPlan != null) {
                await selectedPlan!.save(
                    watchedAt: watchedAt,
                    rating: rating,
                    recommended: recommended,
                    notes: notes);
              } else {
                final savedWatch = await data.actions.logMovieWatch(
                  userId,
                  LogMovieWatchRequest(
                    movieId: movieId,
                    watchedAt: watchedAt,
                    rating: rating,
                    recommended: recommended,
                    notes: notes,
                  ),
                );
                reviewWatchEntryId = savedWatch.id;
              }
              // Also mark the movie as watched in the main watched list and
              // update local user state, then offer to remove from watchlist.
              final watchedResult =
                  await data.actions.addToWatched(userId, movieId);
              if (!context.mounted || !isCurrent) return;
              final user = authProvider.dbUser;
              final updatedWatched =
                  List<WatchedMovie>.from(user?.watchedMovies ?? []);
              updatedWatched.removeWhere((item) => item.movieId == movieId);
              updatedWatched.add(watchedResult ??
                  WatchedMovie(
                    id: '',
                    userId: userId,
                    movieId: movieId,
                    watchedAt: DateTime.now().toIso8601String(),
                  ));
              authProvider.updateUserList(watchedMovies: updatedWatched);
              authProvider.markActivityChanged();
              didSubmit = true;
              // Offer watchlist removal if applicable
              if (context.mounted && data.inWatchlist && isCurrent) {
                final remove = await showFlixiePromptSheet<bool>(
                  context: context,
                  builder: (ctx) => FlixiePromptSheetContent(
                    title: Text('Remove from Watchlist?',
                        style: TextStyle(color: context.colors.light)),
                    content: Text(
                        "This movie is in your watchlist. Remove it now that you've watched it?",
                        style: TextStyle(color: context.colors.medium)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Keep it',
                            style: TextStyle(color: context.colors.medium)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Remove',
                            style: TextStyle(color: FlixieColors.primary)),
                      ),
                    ],
                  ),
                );
                if (context.mounted && remove == true && isCurrent) {
                  await data.actions.removeFromWatchlist(userId, movieId);
                  await analytics.watchlistItemRemoved(source: 'movie_detail');
                  await analytics.movieRemovedFromWatchlist();
                  final updatedWatchlist =
                      (authProvider.dbUser?.movieWatchlist ?? [])
                          .where((item) => item.movieId != movieId)
                          .toList();
                  if (context.mounted && isCurrent) {
                    data.change(() => data.inWatchlist = false);
                  }
                  authProvider.updateUserList(
                      movieWatchlist: updatedWatchlist,
                      watchedMovies: updatedWatched);
                }
              }
            } else {
              await data.actions.updateMovieWatch(
                userId,
                entry.id,
                UpdateMovieWatchRequest(
                  watchedAt: watchedAt,
                  rating: rating,
                  recommended: recommended,
                  notes: notes,
                ),
              );
              didSubmit = true;
            }
            if (entry == null) {
              await analytics.watchLogged(
                contentType: 'movie',
                contentId: movieId,
                source: 'movie_detail',
              );
              final recommendation = this.recommendation;
              if (recommendation != null) {
                await analytics.recommendationWatched(
                  attribution: recommendation,
                );
              }
              if (rating != null) {
                await analytics.ratingAdded(
                  contentType: 'movie',
                  contentId: movieId,
                  source: recommendation?.source ?? 'movie_detail',
                  recommendation: recommendation,
                );
              }
            }
            if (!context.mounted || !isCurrent) return;
            await data.loadWatchHistory(userId, movieId);
            // Evict the cache and re-fetch the movie so the updated
            // community rating (voteAverage / voteCount) is reflected.
            movieService.evictMovie(movieId);
            final updatedMovie =
                await movieService.getMovieById(movieId, userId: userId);
            if (context.mounted && isCurrent) {
              data.change(() {
                data.isWatched = true;
                data.movie = updatedMovie;
                if (rating != null) data.userRating = rating.round();
              });
              ScaffoldMessenger.of(context).showFlixieToast(
                FlixieToast(
                  type: FlixieToastType.success,
                  content: Text(
                      entry == null ? 'Watch logged' : 'Watch entry updated'),
                ),
              );
            }
          } catch (e) {
            didSubmit = false;
            if (context.mounted && isCurrent) {
              ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
                  type: FlixieToastType.error,
                  content: Text('Unable to save watch entry: $e')));
            }
            rethrow;
          }
        },
      ),
    );
    if (!context.mounted || !isCurrent) return didSubmit;
    if (didSubmit) {
      final user = authProvider.dbUser;
      if (user != null) {
        await AppReviewService.recordMovieInteraction(
          user.id,
          hasCompletedSetup: user.completedSetup,
        );
      }
    }
    if (context.mounted && didSubmit && writeReview && isCurrent) {
      await showWriteReviewSheet(
        context,
        watchEntryId: reviewWatchEntryId,
        initialRating: reviewRating,
        initialRecommended: reviewRecommended,
      );
    }
    if (context.mounted && didSubmit && reviewRating != null && isCurrent) {
      final user = authProvider.dbUser;
      final movie = data.movie;
      if (user != null && movie != null) {
        promptShareCard(
          context,
          ShareCardData.rating(
            mediaType: ShareCardMediaType.movie,
            mediaId: movieId,
            title: movie.title,
            posterPath: movie.posterPath,
            user: user,
            rating: reviewRating!.round(),
            recommended: reviewRecommended,
            note: shareNote,
          ),
        );
      }
    }
    return didSubmit;
  }

  Future<void> deleteWatchEntry(MovieWatchEntry entry) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final movieId = data.movieId;
    if (userId == null || movieId == null) return;
    try {
      await data.actions.deleteMovieWatch(userId, entry.id);
      if (!context.mounted || !isCurrent) return;
      data.change(() {
        data.movieWatchHistory.removeWhere((watch) => watch.id == entry.id);
        data.isWatched = data.movieWatchHistory.isNotEmpty;
      });
      final auth = context.read<AuthProvider>();
      if (!data.isWatched) {
        auth.updateUserList(
            watchedMovies: (auth.dbUser?.watchedMovies ?? [])
                .where((movie) => movie.movieId != movieId)
                .toList());
      }
      auth.markActivityChanged();
      await data.loadWatchHistory(userId, movieId);
      if (context.mounted && isCurrent) {
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.success,
            content: const Text('Watch entry deleted')));
      }
    } catch (e) {
      if (context.mounted && isCurrent) {
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.error,
            content: Text('Unable to delete watch entry: $e')));
      }
    }
  }

  Future<void> showWriteReviewSheet(
    BuildContext context, {
    String? watchEntryId,
    double? initialRating,
    bool? initialRecommended,
  }) async {
    if (!await GuestAccess.require(context,
        title: 'Share your thoughts',
        message:
            'Create an account to write your review and discuss it with other film fans.',
        path: '/movies/${data.movieId}',
        intent: 'review')) return;
    if (!context.mounted) return;
    final user = context.read<AuthProvider>().dbUser;
    if (user == null) return;
    final movieId = data.movieId;
    if (movieId == null) return;

    await showModalBottomSheet<Review>(
      useSafeArea: true,
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WriteReviewSheet(
        movieId: movieId,
        watchEntryId: watchEntryId,
        watchEntries: data.movieWatchHistory,
        userId: user.id,
        initialRating: initialRating ?? data.userRating?.toDouble(),
        initialRecommended: initialRecommended,
        onSubmitted: (review) {
          if (!context.mounted || !isCurrent) return;
          final auth = context.read<AuthProvider>();
          data.change(() => data.reviews = [
                review,
                ...data.reviews.where((item) => item.id != review.id)
              ]);
          auth.invalidateCachedReviews();
          auth.markActivityChanged();
        },
      ),
    );
  }
}
