import 'package:flixie_app/core/reviews/app_review_service.dart';
import 'dart:async';
import '../../taste/data/taste_setup_store.dart';
import '../../watchlist/data/guest_watchlist_store.dart';
import 'widgets/title_rating_editor.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'controllers/show_detail_controller.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_ranking_sheet.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/share_card_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/utils/favourite_limits.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_limit_sheet.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/movies/presentation/widgets/add_show_to_list_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';

/// TV save/undo actions and sheets, scoped to their initiating viewer/load.
class ShowDetailActionFlow {
  ShowDetailActionFlow(
      {required this.context, required ShowDetailController data})
      : _data = data,
        _generation = data.generation,
        _viewer = data.auth.dbUser?.id;
  final BuildContext context;
  final ShowDetailController _data;
  final int _generation;
  final String? _viewer;
  bool get mounted => context.mounted && _data.owns(_generation, _viewer);
  void _tasteReady() {
    if (!mounted) return;
    final id = context.read<AuthProvider>().dbUser?.id;
    if (id != null) {
      unawaited(const TasteSetupStore().enable(id).catchError((Object _) {}));
    }
  }

  Future<void> toggleWatchlist({bool offerUndo = true}) async {
    if (!await GuestAccess.require(context,
        title: 'Save this show for later',
        message:
            'Create an account to keep your watchlist and come back to this show whenever you’re ready.',
        path: '/shows/${_data.showId}',
        mediaTitle: _data.show?.name,
        mediaPoster: _data.show?.posterPath,
        intent: 'watchlist')) {
      if (mounted && _data.auth.dbUser == null) {
        _data.change(() => _data.inWatchlist = GuestWatchlistStore
            .instance.homeKeys
            .contains(-(_data.showId ?? 0)));
      }
      return;
    }
    if (!context.mounted) return;
    if (_data.updatingAction != null || !context.mounted || !mounted) return;
    final user = context.read<AuthProvider>().dbUser;
    final analytics = context.read<AnalyticsController>();
    final showId = _data.show?.id;
    if (!mounted || user == null || showId == null) return;

    _data.change(() => _data.updatingAction = ShowDetailAction.watchlist);
    try {
      final nextInWatchlist = !_data.inWatchlist;
      if (_data.inWatchlist) {
        await ShowService.removeFromWatchlist(user.id, showId);
        await analytics.watchlistRemoved(
          contentType: 'show',
          contentId: showId,
          source: 'show_detail',
        );
      } else {
        await ShowService.addToWatchlist(user.id, showId);
        await AppReviewService.recordMovieInteraction(user.id,
            hasCompletedSetup: user.completedSetup,
            eventId: 'watchlist:show:$showId');
        await analytics.watchlistAdded(
          contentType: 'show',
          contentId: showId,
          source: 'show_detail',
        );
      }
      if (!context.mounted || !mounted) return;
      HapticFeedback.lightImpact();
      _data.change(() {
        _data.inWatchlist = nextInWatchlist;
        _data.updatingAction = null;
      });
      context.read<AuthProvider>()
        ..updateUserList(
          showWatchlist: _data.updatedShowIdList(
            user.showWatchlist,
            showId,
            nextInWatchlist,
          ),
        )
        ..markActivityChanged();
      _tasteReady();
      final savedState = _data.inWatchlist;
      ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
        type: FlixieToastType.success,
        content: Text(savedState
            ? (GuestAccess.bookmarkSetupPath != null
                ? '${_data.show?.name ?? 'Title'} is on your watchlist'
                : 'Added to watchlist')
            : 'Removed from watchlist'),
        action: savedState &&
                !user.completedSetup &&
                GuestAccess.bookmarkSetupPath != null
            ? SnackBarAction(
                label: 'Set up Flixie',
                onPressed: () {
                  if (context.mounted) context.go('/onboarding');
                })
            : offerUndo
                ? SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      if (mounted &&
                          _data.updatingAction == null &&
                          _data.inWatchlist == savedState) {
                        toggleWatchlist(offerUndo: false);
                      }
                    })
                : null,
      ));
    } catch (e) {
      if (!context.mounted || !mounted) return;
      _data.change(() => _data.updatingAction = null);
      ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
        type: FlixieToastType.error,
        content: const Text('Couldn’t update your watchlist'),
        action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              if (mounted && _data.updatingAction == null) toggleWatchlist();
            }),
      ));
    }
  }

  Future<void> toggleFavorite({bool offerUndo = true}) async {
    if (!await GuestAccess.require(context,
        title: 'Save your favourites',
        path: '/shows/${_data.showId}',
        mediaTitle: _data.show?.name,
        mediaPoster: _data.show?.posterPath,
        intent: 'favorite')) {
      return;
    }
    if (!context.mounted) return;
    if (_data.updatingAction != null || !context.mounted || !mounted) return;
    final user = context.read<AuthProvider>().dbUser;
    final analytics = context.read<AnalyticsController>();
    final showId = _data.show?.id;
    if (!mounted || user == null || showId == null) return;

    final activeFavouriteCount = (user.favoriteShows ?? const <dynamic>[])
        .where(isActiveFavouriteShow)
        .length;
    if (!_data.isFavorite && activeFavouriteCount >= maxFavouriteShows) {
      showFavouriteLimitPrompt(
        context,
        type: FavouriteLimitType.show,
        onSpaceMade: toggleFavorite,
      );
      return;
    }

    _data.change(() => _data.updatingAction = ShowDetailAction.favorite);
    try {
      final nextIsFavorite = !_data.isFavorite;
      Map<String, dynamic>? addedFavorite;
      if (_data.isFavorite) {
        await ShowService.removeFromFavourites(user.id, showId);
        await analytics.showUnfavourited();
      } else {
        addedFavorite = await ShowService.addToFavourites(user.id, showId);
        await analytics.showFavourited();
      }
      if (!context.mounted || !mounted) return;
      HapticFeedback.lightImpact();
      _data.change(() {
        _data.isFavorite = nextIsFavorite;
        _data.updatingAction = null;
      });
      context.read<AuthProvider>()
        ..updateUserList(
          favoriteShows: nextIsFavorite && addedFavorite != null
              ? <dynamic>[
                  ...(user.favoriteShows ?? const <dynamic>[]).where(
                      (item) => !_data.dynamicShowIdMatches(item, showId)),
                  addedFavorite,
                ]
              : _data.updatedShowIdList(
                  user.favoriteShows,
                  showId,
                  nextIsFavorite,
                ),
        )
        ..markActivityChanged();
      _tasteReady();
      final savedState = _data.isFavorite;
      ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
        type: FlixieToastType.success,
        content: Text(
            savedState ? 'Added to favourites' : 'Removed from favourites'),
        action: savedState
            ? SnackBarAction(
                label: 'Rank',
                onPressed: () {
                  if (context.mounted && mounted) {
                    showFavouriteRankingSheet(context, shows: true);
                  }
                })
            : offerUndo
                ? SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      if (mounted &&
                          _data.updatingAction == null &&
                          _data.isFavorite == savedState) {
                        toggleFavorite(offerUndo: false);
                      }
                    })
                : null,
      ));
    } catch (error) {
      if (!context.mounted || !mounted) return;
      _data.change(() => _data.updatingAction = null);
      if (isFavouriteLimitError(error)) {
        showFavouriteLimitPrompt(
          context,
          type: FavouriteLimitType.show,
          onSpaceMade: toggleFavorite,
        );
      } else {
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
          type: FlixieToastType.error,
          content: const Text('Couldn’t update your favourites'),
          action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                if (mounted && _data.updatingAction == null) toggleFavorite();
              }),
        ));
      }
    }
  }

  Future<void> showAddToListSheet() async {
    if (!await GuestAccess.require(context,
        title: 'Build your lists',
        path: '/shows/${_data.showId}',
        intent: 'list')) {
      return;
    }
    if (!context.mounted) return;
    if (!context.mounted || !mounted) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    final show = _data.show;
    if (!mounted || userId == null || show == null) return;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddShowToListSheet(
        showId: show.id,
        showTitle: show.name,
        showPosterPath: show.posterPath,
        firstAirDate: show.firstAirDate,
        ratingLabel: show.voteAverage != null
            ? '★ ${show.voteAverage!.toStringAsFixed(1)}'
            : null,
      ),
    );
    if (changed == true && context.mounted && mounted) {
      await _data.loadListsContainingShow(userId, show.id);
    }
  }

  Future<void> setSeasonWatched(TvSeason season, bool watched) async {
    if (!await GuestAccess.require(context,
        title: 'Keep track of what you watch',
        path: '/shows/${_data.showId}',
        mediaTitle: _data.show?.name,
        mediaPoster: _data.show?.posterPath,
        intent: watched ? 'season' : null,
        selectedSeasonNumber: season.seasonNumber)) {
      return;
    }
    if (!context.mounted) return;
    if (!context.mounted || !mounted) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    final show = _data.show;
    if (userId == null ||
        show == null ||
        _data.updatingSeasonNumbers.contains(season.seasonNumber) ||
        show
            .episodesForSeason(season.seasonNumber)
            .any((e) => _data.updatingEpisodeIds.contains(e.id))) {
      return;
    }
    final changes = show
        .episodesForSeason(season.seasonNumber)
        .where((episode) =>
            TvShowEpisodeProgress(show).isReleased(episode) &&
            episode.watched != watched)
        .toList();
    if (changes.isEmpty) return;
    final confirmed = await showFlixiePromptSheet<bool>(
      context: context,
      builder: (context) => FlixiePromptSheetContent(
        title:
            Text(watched ? 'Mark season watched?' : 'Mark season unwatched?'),
        content: Text(
            '${changes.length} released episodes will be marked ${watched ? 'watched' : 'unwatched'}. Upcoming episodes stay unchanged.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(watched ? 'Mark watched' : 'Mark unwatched')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted || !mounted) return;
    await applySeasonProgress(
        userId, show.id, season.seasonNumber, changes, watched);
  }

  Future<void> catchUpToEpisode(TvEpisode selected,
      {required bool includeSelected}) async {
    if (!mounted) return;
    if (!await GuestAccess.require(context,
        title: 'Keep track of what you watch',
        path: '/shows/${_data.showId}')) {
      return;
    }
    if (!mounted) return;
    final show = _data.show;
    final userId = _data.auth.dbUser?.id;
    if (show == null || userId == null) return;
    final progress = TvShowEpisodeProgress(show);
    final changes = show
        .episodesForSeason(selected.seasonNumber)
        .where((e) =>
            !e.watched &&
            progress.isReleased(e) &&
            (e.episodeNumber < selected.episodeNumber ||
                (includeSelected && e.episodeNumber == selected.episodeNumber)))
        .toList();
    if (changes.isEmpty) return;
    await applySeasonProgress(
        userId, show.id, selected.seasonNumber, changes, true,
        recordWatchDate: false);
  }

  Future<void> applySeasonProgress(String userId, int showId, int seasonNumber,
      List<TvEpisode> episodes, bool watched,
      {bool undo = false, bool recordWatchDate = true}) async {
    if (!mounted || _data.updatingSeasonNumbers.contains(seasonNumber)) return;
    if (episodes.any((e) => _data.updatingEpisodeIds.contains(e.id))) return;
    _data.change(() => _data.updatingSeasonNumbers.add(seasonNumber));
    final applied = <TvEpisode>[];
    for (final episode in episodes) {
      if (!context.mounted || !mounted) return;
      try {
        await ShowService.updateEpisodeProgress(
          userId: userId,
          showId: showId,
          episodeId: episode.id,
          watched: watched,
          watchedAt: watched
              ? (undo
                      ? episode.watchedAt
                      : recordWatchDate
                          ? DateTime.now()
                          : null)
                  ?.toUtc()
                  .toIso8601String()
              : null,
        );
        applied.add(episode);
      } catch (_) {
        // Keep the successful subset so Undo never alters untouched episodes.
      }
    }
    if (!context.mounted || !mounted) return;
    _data.change(() {
      _data.show = _data.show!.withEpisodeProgress({
        for (final episode in applied)
          episode.id: episode.withWatched(
              watched,
              watched
                  ? (undo
                      ? episode.watchedAt
                      : recordWatchDate
                          ? DateTime.now()
                          : null)
                  : null),
      });
      _data.updatingSeasonNumbers.remove(seasonNumber);
    });
    context.read<AuthProvider>().markActivityChanged();
    _tasteReady();
    final failed = episodes.length - applied.length;
    if (applied.isEmpty) {
      _showSnack('Unable to update season progress',
          type: FlixieToastType.error);
      return;
    }
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
      type: failed > 0 ? FlixieToastType.warning : FlixieToastType.success,
      content: Text(failed > 0
          ? '${applied.length} episodes updated. $failed could not be saved.'
          : undo
              ? 'Episode watched states restored'
              : '${applied.length} episodes marked ${watched ? 'watched' : 'unwatched'}'),
      action: undo
          ? null
          : SnackBarAction(
              label: 'Undo',
              onPressed: () {
                applySeasonProgress(
                    userId, showId, seasonNumber, applied, !watched,
                    undo: true);
              }),
    ));
  }

  Future<void> setEpisodeWatched(TvEpisode episode, bool watched,
      {bool undo = false}) async {
    if (!await GuestAccess.require(context,
        title: 'Keep track of what you watch',
        path: '/shows/${_data.showId}',
        mediaTitle: _data.show?.name,
        mediaPoster: _data.show?.posterPath,
        intent: watched ? 'episode' : null,
        selectedEpisodeId: episode.id,
        selectedSeasonNumber: episode.seasonNumber,
        selectedEpisodeNumber: episode.episodeNumber,
        selectedEpisodeTitle: episode.name)) {
      return;
    }
    if (!context.mounted) return;
    if (!context.mounted || !mounted) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    final showId = _data.show?.id;
    if (!mounted ||
        userId == null ||
        showId == null ||
        _data.updatingEpisodeIds.contains(episode.id) ||
        _data.updatingSeasonNumbers.contains(episode.seasonNumber)) {
      return;
    }

    _data.change(() => _data.updatingEpisodeIds.add(episode.id));
    try {
      await ShowService.updateEpisodeProgress(
        userId: userId,
        showId: showId,
        episodeId: episode.id,
        watched: watched,
        watchedAt: watched
            ? (undo ? episode.watchedAt : DateTime.now())
                ?.toUtc()
                .toIso8601String()
            : null,
      );
      if (!context.mounted || !mounted) return;
      HapticFeedback.selectionClick();
      _data.change(() => _data.show = _data.show!.withEpisodeProgress({
            episode.id: episode.withWatched(watched,
                watched ? (undo ? episode.watchedAt : DateTime.now()) : null),
          }));
      context.read<AuthProvider>().markActivityChanged();
      _tasteReady();
      if (context.mounted && mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
          type: FlixieToastType.success,
          content: Text(
              watched ? 'Episode marked watched' : 'Episode marked unwatched'),
          action: undo
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  onPressed: () =>
                      setEpisodeWatched(episode, !watched, undo: true)),
        ));
      }
    } catch (_) {
      if (context.mounted && mounted) {
        _showSnack('Unable to update episode progress',
            type: FlixieToastType.error);
      }
    } finally {
      if (context.mounted && mounted) {
        _data.change(() => _data.updatingEpisodeIds.remove(episode.id));
      }
    }
  }

  void _showSnack(String message,
      {FlixieToastType type = FlixieToastType.success}) {
    ScaffoldMessenger.of(context)
        .showFlixieToast(FlixieToast(type: type, content: Text(message)));
  }

  Future<void> setUserRating(int rating,
      {bool offerUndo = true, String? recommendation}) async {
    if (!mounted || _data.isRatingLoading) return;
    final previousRating = _data.userRating;
    final previousRecommendation = _data.userRecommendation;
    if (!context.mounted || !mounted) return;
    final user = context.read<AuthProvider>().dbUser;
    final analytics = context.read<AnalyticsController>();
    final showId = _data.show?.id;
    if (!mounted || user == null || showId == null) return;

    _data.change(() => _data.isRatingLoading = true);
    try {
      final response = await ShowService.addShowRating(showId, user.id, rating,
          recommendation: recommendation);
      await analytics.ratingAdded(
        contentType: 'show',
        contentId: showId,
        source: 'show_detail',
      );
      final updatedVoteAverage = _parseDouble(response['voteAverage']);
      final updatedVoteCount = _parseInt(response['voteCount']);
      if (!context.mounted || !mounted) return;
      HapticFeedback.lightImpact();
      _data.change(() {
        _data.userRating = rating;
        _data.userRecommendation = recommendation;
        if (updatedVoteAverage != null || updatedVoteCount != null) {
          final current = _data.show!;
          _data.show = TvShow(
            id: current.id,
            name: current.name,
            firstAirDate: current.firstAirDate,
            lastAirDate: current.lastAirDate,
            overview: current.overview,
            posterPath: current.posterPath,
            backdropPath: current.backdropPath,
            popularity: current.popularity,
            voteAverage: updatedVoteAverage ?? current.voteAverage,
            tmdbRating: current.tmdbRating,
            imdbRating: current.imdbRating,
            imdbRatingLabel: current.imdbRatingLabel,
            rottenTomatoRatingLabel: current.rottenTomatoRatingLabel,
            metascoreRatingLabel: current.metascoreRatingLabel,
            flixieScore: current.flixieScore,
            friendRating: current.friendRating,
            friendRecommendPercent: current.friendRecommendPercent,
            voteCount: updatedVoteCount ?? current.voteCount,
            numberOfSeasons: current.numberOfSeasons,
            numberOfEpisodes: current.numberOfEpisodes,
            tagline: current.tagline,
            status: current.status,
            originalLanguage: current.originalLanguage,
            originCountry: current.originCountry,
            genres: current.genres,
            networks: current.networks,
            createdBy: current.createdBy,
            seasons: current.seasons,
            episodes: current.episodes,
            cast: current.cast,
            crew: current.crew,
            similarShows: current.similarShows,
            friendActivity: current.friendActivity,
            friendSummary: current.friendSummary,
            watchProviders: current.watchProviders,
            watchedEpisodeCount: current.watchedEpisodeCount,
            episodeRuntime: current.episodeRuntime,
          );
        }
        _data.isRatingLoading = false;
      });
      if (offerUndo && previousRating == null) {
        promptShareCard(
            context,
            ShareCardData.rating(
              mediaType: ShareCardMediaType.show,
              mediaId: showId,
              title: _data.show!.name,
              posterPath: _data.show!.posterPath,
              user: user,
              rating: rating,
              neutralRecommendation: recommendation == 'neutral',
              recommended: recommendation == 'recommend'
                  ? true
                  : recommendation == 'avoid'
                      ? false
                      : null,
            ));
        return;
      }
      ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
        type: FlixieToastType.success,
        content: const Text('Rating saved'),
        action: offerUndo && previousRating != null
            ? SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  if (mounted &&
                      !_data.isRatingLoading &&
                      _data.userRating == rating) {
                    setUserRating(previousRating,
                        offerUndo: false,
                        recommendation: previousRecommendation);
                  }
                })
            : null,
      ));
    } catch (_) {
      if (!context.mounted || !mounted) return;
      _data.change(() => _data.isRatingLoading = false);
      ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
        type: FlixieToastType.error,
        content: const Text('Couldn’t save your rating'),
        action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              if (mounted && !_data.isRatingLoading) {
                setUserRating(rating, recommendation: recommendation);
              }
            }),
      ));
    }
  }

  void showRatingSheet() async {
    if (!await GuestAccess.require(context,
        title: 'Rate this show',
        path: '/shows/${_data.showId}',
        mediaTitle: _data.show?.name,
        mediaPoster: _data.show?.posterPath,
        intent: 'rate')) {
      return;
    }
    if (!context.mounted) return;
    if (!context.mounted || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .85),
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: TitleRatingEditor(
                  title: 'Rate this show',
                  subtitle: 'Choose a score for the overall series.',
                  initialRating: _data.userRating,
                  initialRecommendation: _data.userRecommendation,
                  onSave: (rating, recommendation) async {
                    Navigator.pop(sheetContext);
                    await setUserRating(rating, recommendation: recommendation);
                  }))),
    );
  }

  Future<void> showWriteReviewSheet() async {
    if (!await GuestAccess.require(context,
        title: 'Share your thoughts',
        message:
            'Create an account to write your review and discuss it with other film fans.',
        path: '/shows/${_data.showId}',
        mediaTitle: _data.show?.name,
        mediaPoster: _data.show?.posterPath,
        intent: 'review')) {
      return;
    }
    if (!context.mounted) return;
    if (!context.mounted || !mounted) return;
    final user = context.read<AuthProvider>().dbUser;
    final show = _data.show;
    if (!mounted || user == null || show == null) return;
    await showModalBottomSheet<Review>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WriteReviewSheet(
        showId: show.id,
        mediaTitle: show.name,
        userId: user.id,
        initialRating: _data.userRating?.toDouble(),
        onSubmitted: (review) {
          if (!context.mounted || !mounted) return;
          _data.addReview(review);
          final auth = context.read<AuthProvider>();
          auth.invalidateCachedReviews();
          auth.markActivityChanged();
          _tasteReady();
        },
      ),
    );
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
