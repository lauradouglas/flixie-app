import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/friend_recommendation.dart';
import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/models/movie_credits.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';
import 'package:flixie_app/models/movie_friend_list_entry.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/similar_movie.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/watchlist/presentation/controllers/watchlist_actions_controller.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/models/friend_summary.dart';
import 'package:flixie_app/features/movies/presentation/widgets/cast_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/external_links_section.dart';
import 'package:flixie_app/features/movies/presentation/widgets/film_info_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/friend_activity_row.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/movies/presentation/widgets/genre_chip.dart';
import 'package:flixie_app/features/movies/presentation/widgets/add_to_list_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/review_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/similar_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/video_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_lists_section.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({
    super.key,
    required this.movieId,
    this.fromMovieMatch = false,
  });

  final String movieId;
  final bool fromMovieMatch;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

enum ListUpdateType { watchlist, watched, favorite }

enum FriendActivityTab { all, watched, watchlist, ratings, reviews, lists }

enum WatchProviderTab { stream, rent, buy }

enum MovieDetailTab { overview, reviews, activity, details }

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  static const double _sectionSpacing = 24;
  Movie? _movie;
  List<Review> _reviews = [];
  List<SimilarMovie> _similar = [];
  List<MovieCastMember> _cast = [];
  List<WatchProvider> _watchProviders = [];
  Set<int> _userProviderIds = {};
  WatchProviderTab _watchProviderTab = WatchProviderTab.stream;
  MovieDetailTab _movieDetailTab = MovieDetailTab.overview;
  CrewMember? _director;
  List<String> _producers = [];
  List<String> _writers = [];
  bool _isLoading = true;
  String? _error;
  bool _inWatchlist = false;
  bool _isWatched = false;
  bool _isFavorite = false;
  int? _userRating;
  bool? _userRecommends;
  bool _isRatingLoading = false;
  ListUpdateType? _currentlyUpdating;
  List<MovieFriendActivity> _friendsActivity = [];
  FriendRecommendationResponse? _friendRecommendation;
  bool _friendRecommendationLoading = false;
  Object? _friendRecommendationError;
  FriendSummaryResponse? _friendSummary;
  bool _friendSummaryLoading = false;
  Object? _friendSummaryError;
  List<MovieList> _myListsContainingMovie = [];
  List<MovieFriendListEntry> _friendsListsContainingMovie = [];
  bool _listsContainingMovieLoading = false;
  List<MovieWatchEntry> _movieWatchHistory = [];
  bool _watchHistoryLoading = false;
  FriendActivityTab _friendsActivityTab = FriendActivityTab.all;
  bool _showFullSynopsis = false;
  static const List<Color> _kGenreChipColors = [
    FlixieColors.primary,
    FlixieColors.secondary,
    FlixieColors.tertiary,
    FlixieColors.warning,
  ];
  int get _watchCount => _movieWatchHistory.length;

  // ---- Data loading ---------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _refresh() async {
    final id = int.tryParse(widget.movieId);
    if (id != null) context.read<MovieService>().evictMovie(id);
    await _load();
  }

  Future<void> _load() async {
    final id = int.tryParse(widget.movieId);
    if (id == null || id <= 0) {
      if (mounted) {
        setState(() {
          _error = 'Invalid movie ID.';
          _isLoading = false;
        });
      }
      return;
    }

    // Get userId from AuthProvider
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.dbUser?.id;

    try {
      final movieService = context.read<MovieService>();
      final region = authProvider.dbUser?.countryAbbreviation ?? 'GB';
      final futures = <Future>[
        movieService.getMovieById(id, userId: userId),
        movieService.getMovieRecommendations(id),
        movieService.getMovieCredits(id),
        movieService.getMovieWatchProviders(id, region),
        if (userId != null)
          WatchlistActionsController.instance
              .getUserWatchProviders(userId)
              .catchError((_) => <WatchProvider>[])
        else
          Future.value(<WatchProvider>[]),
      ];
      if (userId != null) {
        futures.add(movieService.getUserMovieRating(id, userId));
        futures.add(movieService.getFriendsMovieActivity(id, userId));
      }
      final results = await Future.wait(futures);
      if (mounted) {
        setState(() {
          final loadedMovie = results[0] as Movie;
          _movie = loadedMovie;
          _similar = results[1] as List<SimilarMovie>;
          final credits = results[2] as MovieCredits;
          _cast = credits.castMembers;
          _director = credits.crewMembers
              .where((crew) => crew.job == 'Director')
              .firstOrNull;
          final execProducers = credits.crewMembers
              .where((crew) => crew.job == 'Executive Producer')
              .map((crew) => crew.name)
              .toList();
          final producers = credits.crewMembers
              .where((crew) => crew.job == 'Producer')
              .map((crew) => crew.name)
              .toList();
          _producers = <String>{...execProducers, ...producers}.toList();
          _writers = credits.crewMembers
              .where((crew) =>
                  crew.job == 'Screenplay' || crew.job == 'Head of Story')
              .map((crew) => crew.name)
              .toSet()
              .toList();
          _watchProviders = results[3] as List<WatchProvider>;
          final userProviders = results[4] as List<WatchProvider>;
          _userProviderIds =
              userProviders.map((provider) => provider.id).toSet();
          _reviews = (loadedMovie.reviews ?? []).toList();

          // Check movie status in user's lists
          final user = authProvider.dbUser;
          if (user != null) {
            _inWatchlist = user.isMovieInWatchlist(id);
            _isWatched = user.isMovieWatched(id);
            _isFavorite = user.isMovieFavorite(id);
          }
          // Load existing user rating from API
          if (userId != null && results.length > 5) {
            final userRating = results[5] as ({int? rating, bool? recommended});
            _userRating = userRating.rating;
            _userRecommends = userRating.recommended;
            _friendsActivity = results[6] as List<MovieFriendActivity>? ?? [];
          }

          _isLoading = false;
        });
        if (userId != null) {
          _loadWatchHistory(userId, id);
          _loadListsContainingMovie(userId, id);
          _loadFriendRecommendation(id);
          _loadFriendSummary(id);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadWatchHistory(String userId, int movieId) async {
    if (!mounted) return;
    setState(() => _watchHistoryLoading = true);
    try {
      final history = await WatchlistActionsController.instance
          .getMovieWatchHistory(userId, movieId);
      if (mounted) {
        setState(() {
          _movieWatchHistory = history;
          _watchHistoryLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _watchHistoryLoading = false);
      }
    }
  }

  Future<void> _loadFriendRecommendation(int movieId) async {
    if (!mounted) return;
    setState(() {
      _friendRecommendationLoading = true;
      _friendRecommendationError = null;
    });
    try {
      final result =
          await context.read<MovieService>().getFriendRecommendation(movieId);
      if (!mounted) return;
      setState(() {
        _friendRecommendation = result;
        _friendRecommendationLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _friendRecommendationError = e;
        _friendRecommendationLoading = false;
      });
    }
  }

  Future<void> _loadFriendSummary(int movieId) async {
    if (!mounted) return;
    setState(() {
      _friendSummaryLoading = true;
      _friendSummaryError = null;
    });
    try {
      final result =
          await context.read<MovieService>().getFriendSummary(movieId);
      if (!mounted) return;
      setState(() {
        _friendSummary = result;
        _friendSummaryLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _friendSummaryError = e;
        _friendSummaryLoading = false;
      });
    }
  }

  Future<void> _loadListsContainingMovie(String userId, int movieId) async {
    if (!mounted) return;
    setState(() => _listsContainingMovieLoading = true);
    try {
      final results = await Future.wait([
        WatchlistActionsController.instance
            .getMyListsContainingMovie(userId, movieId),
        WatchlistActionsController.instance
            .getFriendsListsContainingMovie(userId, movieId),
      ]);
      if (!mounted) return;
      setState(() {
        _myListsContainingMovie = results[0] as List<MovieList>;
        _friendsListsContainingMovie = results[1] as List<MovieFriendListEntry>;
        _listsContainingMovieLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _myListsContainingMovie = const <MovieList>[];
        _friendsListsContainingMovie = const <MovieFriendListEntry>[];
        _listsContainingMovieLoading = false;
      });
    }
  }

  // ---- List Management ------------------------------------------------------

  Future<void> _toggleWatchlist() async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    final movieId = int.tryParse(widget.movieId);

    if (user == null || movieId == null) return;

    setState(() => _currentlyUpdating = ListUpdateType.watchlist);

    try {
      final result = await (_inWatchlist
          ? WatchlistActionsController.instance
              .removeFromWatchlist(user.id, movieId)
          : WatchlistActionsController.instance
              .addToWatchlist(user.id, movieId));
      if (_inWatchlist) {
        await analytics.watchlistItemRemoved(source: 'movie_detail');
        await analytics.movieRemovedFromWatchlist();
      } else {
        await analytics.watchlistItemAdded(source: 'movie_detail');
        await analytics.movieAddedToWatchlist();
      }

      // Successfully updated on server, toggle UI state and update user list
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _inWatchlist = !_inWatchlist;
          _currentlyUpdating = null;
        });

        // Keep existing entries, then append or remove the affected entry.
        final currentWatchlist =
            List<WatchlistMovie>.from(user.movieWatchlist ?? []);

        if (_inWatchlist) {
          // Added
          currentWatchlist.removeWhere((item) => item.movieId == movieId);
          currentWatchlist.add(result);
          authProvider.markActivityChanged();
          authProvider.updateUserList(movieWatchlist: currentWatchlist);
        } else {
          // Removed
          currentWatchlist.removeWhere((item) => item.movieId == movieId);
          authProvider.updateUserList(movieWatchlist: currentWatchlist);
          // Offer to mark as watched if not already
          if (!_isWatched && mounted) {
            final markWatched = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Did you watch it?',
                    style: TextStyle(color: FlixieColors.light)),
                content: const Text('Want to add this to your watched list?',
                    style: TextStyle(color: FlixieColors.medium)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('No',
                        style: TextStyle(color: FlixieColors.medium)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Yes!',
                        style: TextStyle(color: FlixieColors.primary)),
                  ),
                ],
              ),
            );
            if (markWatched == true && mounted) {
              final committed = await _showLogWatchSheet();
              if (committed && mounted) {
                setState(() => _isWatched = true);
              }
            }
          }
        }
      }
    } catch (e) {
      logger.e('Error toggling watchlist: $e');
      if (mounted) {
        setState(() => _currentlyUpdating = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update watchlist: $e')),
        );
      }
    }
  }

  Future<void> _toggleWatched() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.dbUser;
    final movieId = int.tryParse(widget.movieId);

    if (user == null || movieId == null) return;

    if (!_isWatched) {
      setState(() => _currentlyUpdating = ListUpdateType.watched);
      try {
        final committed = await _showLogWatchSheet();
        if (!mounted) return;
        setState(() {
          if (committed) _isWatched = true;
          _currentlyUpdating = null;
        });
        if (committed) HapticFeedback.lightImpact();
      } catch (e) {
        logger.e('Error marking movie watched: $e');
        if (mounted) {
          setState(() => _currentlyUpdating = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to mark as watched')),
          );
        }
      }
      return;
    }

    setState(() => _currentlyUpdating = ListUpdateType.watched);

    try {
      await WatchlistActionsController.instance
          .removeFromWatched(user.id, movieId);

      // Successfully updated on server, toggle UI state and update user list
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _isWatched = !_isWatched;
          _currentlyUpdating = null;
        });

        // _isWatched is now false (was toggled above); remove from local list
        final updatedWatched = (user.watchedMovies ?? [])
            .where((item) => item.movieId != movieId)
            .toList();
        authProvider.updateUserList(watchedMovies: updatedWatched);
      }
    } catch (e) {
      logger.e('Error toggling watched: $e');
      if (mounted) {
        setState(() => _currentlyUpdating = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update watched list: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    final movieId = int.tryParse(widget.movieId);

    if (user == null || movieId == null) return;

    setState(() => _currentlyUpdating = ListUpdateType.favorite);
    try {
      final FavoriteMovie? addedFavorite;
      if (_isFavorite) {
        await WatchlistActionsController.instance
            .removeFromFavorites(user.id, movieId);
        await analytics.movieUnfavourited();
        addedFavorite = null;
      } else {
        addedFavorite = await WatchlistActionsController.instance
            .addToFavorites(user.id, movieId);
        await analytics.movieFavourited();
      }

      // Successfully updated on server, toggle UI state and update user list
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _isFavorite = !_isFavorite;
          _currentlyUpdating = null;
        });

        List<FavoriteMovie> updatedFavorites;
        if (_isFavorite) {
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
      }
    } catch (e) {
      logger.e('Error toggling favorite: $e');
      if (mounted) {
        setState(() => _currentlyUpdating = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorites: $e')),
        );
      }
    }
  }

  Future<void> _showAddToListSheet() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final movieId = int.tryParse(widget.movieId);
    if (movieId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddToListSheet(
        movieId: movieId,
        movieTitle: _movie?.title,
        moviePosterPath: _movie?.posterPath,
        movieReleaseDate: _movie?.releaseDate,
        movieRuntimeMinutes: _movie?.runtime,
        movieRatingLabel: _movie?.voteAverage != null
            ? '★ ${_movie!.voteAverage!.toStringAsFixed(1)}'
            : null,
      ),
    );
    if (userId != null) {
      await _loadListsContainingMovie(userId, movieId);
    }
  }

  Future<bool> _showLogWatchSheet({MovieWatchEntry? entry}) async {
    final movieId = int.tryParse(widget.movieId);
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final movieService = context.read<MovieService>();
    final userId = authProvider.dbUser?.id;
    if (movieId == null || userId == null) return false;
    var didSubmit = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RewatchLogSheet(
        initial: entry,
        onSubmit: ({
          required String watchedAt,
          required double? rating,
          required bool? recommended,
          required String? notes,
        }) async {
          try {
            if (entry == null) {
              await WatchlistActionsController.instance.logMovieWatch(
                userId,
                LogMovieWatchRequest(
                  movieId: movieId,
                  watchedAt: watchedAt,
                  rating: rating,
                  recommended: recommended,
                  notes: notes,
                ),
              );
              // Also mark the movie as watched in the main watched list and
              // update local user state, then offer to remove from watchlist.
              final watchedResult = await WatchlistActionsController.instance
                  .addToWatched(userId, movieId);
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
              if (_inWatchlist && mounted) {
                final remove = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove from Watchlist?',
                        style: TextStyle(color: FlixieColors.light)),
                    content: const Text(
                        "This movie is in your watchlist. Remove it now that you've watched it?",
                        style: TextStyle(color: FlixieColors.medium)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Keep it',
                            style: TextStyle(color: FlixieColors.medium)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Remove',
                            style: TextStyle(color: FlixieColors.primary)),
                      ),
                    ],
                  ),
                );
                if (remove == true && mounted) {
                  await WatchlistActionsController.instance
                      .removeFromWatchlist(userId, movieId);
                  await analytics.watchlistItemRemoved(source: 'movie_detail');
                  await analytics.movieRemovedFromWatchlist();
                  final updatedWatchlist =
                      (authProvider.dbUser?.movieWatchlist ?? [])
                          .where((item) => item.movieId != movieId)
                          .toList();
                  if (mounted) setState(() => _inWatchlist = false);
                  authProvider.updateUserList(
                      movieWatchlist: updatedWatchlist,
                      watchedMovies: updatedWatched);
                }
              }
            } else {
              await WatchlistActionsController.instance.updateMovieWatch(
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
            await _loadWatchHistory(userId, movieId);
            // Evict the cache and re-fetch the movie so the updated
            // community rating (voteAverage / voteCount) is reflected.
            movieService.evictMovie(movieId);
            final updatedMovie =
                await movieService.getMovieById(movieId, userId: userId);
            if (mounted) {
              setState(() {
                _isWatched = true;
                _movie = updatedMovie;
                if (rating != null) _userRating = rating.round();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      entry == null ? 'Watch logged' : 'Watch entry updated'),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unable to save watch entry: $e')));
            }
          }
        },
      ),
    );
    return didSubmit;
  }

  Future<void> _deleteWatchEntry(MovieWatchEntry entry) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final movieId = int.tryParse(widget.movieId);
    if (userId == null || movieId == null) return;
    try {
      await WatchlistActionsController.instance
          .deleteMovieWatch(userId, entry.id);
      await _loadWatchHistory(userId, movieId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Watch entry deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to delete watch entry: $e')));
      }
    }
  }

  // ---- Helpers --------------------------------------------------------------

  /// Extracts a 4-digit year from a date string like "2024-03-15".
  String _extractYear(String? dateStr) {
    if (dateStr == null || dateStr.length < 4) return '';
    return dateStr.substring(0, 4);
  }

  /// Formats runtime in minutes to "Xh Ym".
  String _formatRuntime(int? minutes) {
    if (minutes == null || minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static const List<(FriendActivityTab, String)> _kFriendActivityTabs = [
    (FriendActivityTab.all, 'All'),
    (FriendActivityTab.watched, 'Watched'),
    (FriendActivityTab.watchlist, 'Watchlist'),
    (FriendActivityTab.ratings, 'Ratings'),
    (FriendActivityTab.reviews, 'Recommendations'),
    // TODO(release): Restore the Lists filter when list activity is returned
    // by the friends activity API.
  ];

  String _contentRating(Movie movie) {
    // TODO(laura): replace fallback with certification/country rating from API.
    return 'PG-13';
  }

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: FlixieColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: FlixieColors.background,
        appBar: AppBar(
          backgroundColor: FlixieColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: FlixieColors.light),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: FlixieColors.danger,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load movie',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _load();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final movie = _movie;
    if (movie == null) {
      return Scaffold(
        backgroundColor: FlixieColors.background,
        appBar: AppBar(
          backgroundColor: FlixieColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: FlixieColors.light),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'Movie data is unavailable.',
            style: TextStyle(color: FlixieColors.medium),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: FlixieColors.background,
      body: RefreshIndicator(
        color: FlixieColors.primary,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildSliverAppBar(context, movie),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    _buildMovieIntro(context, movie),
                    const SizedBox(height: 10),
                    _buildActionButtons(),
                    const SizedBox(height: 14),
                    _buildWhereToWatchSection(context),
                    const SizedBox(height: 12),
                    _buildFriendSummarySection(context),
                    const SizedBox(height: 14),
                    _buildMovieDetailTabs(),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: KeyedSubtree(
                        key: ValueKey(_movieDetailTab),
                        child: _buildSelectedMovieTab(context, movie),
                      ),
                    ),
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Compact top actions -------------------------------------------------

  Widget _buildSliverAppBar(BuildContext context, Movie movie) {
    return SliverAppBar(
      toolbarHeight: 60,
      pinned: true,
      backgroundColor: FlixieColors.background,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          _heroIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => context.pop(),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            padding: EdgeInsets.zero,
            color: FlixieColors.tabBarBackgroundFocused,
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: FlixieColors.light,
              size: 21,
            ),
            onSelected: (value) {
              if (value == 'rewatch') {
                if (_isWatched) {
                  _showLogWatchSheet();
                }
              } else if (value == 'list') {
                _showAddToListSheet();
              } else if (value == 'request') {
                _showWatchRequestSheet();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'rewatch',
                child: Row(
                  children: [
                    Icon(Icons.replay_rounded,
                        color: FlixieColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text('Log rewatch',
                        style: TextStyle(color: FlixieColors.light)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'list',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add_rounded,
                        color: FlixieColors.secondary, size: 20),
                    SizedBox(width: 8),
                    Text('Add to list',
                        style: TextStyle(color: FlixieColors.light)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'request',
                child: Row(
                  children: [
                    Icon(Icons.group_add_outlined,
                        color: FlixieColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text('Request to watch',
                        style: TextStyle(color: FlixieColors.light)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 46,
      height: 46,
      child: IconButton(
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.45),
          shape: const CircleBorder(),
        ),
        icon: Icon(icon, color: FlixieColors.light, size: 21),
      ),
    );
  }

  Widget _buildMovieIntro(BuildContext context, Movie movie) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
        final posterWidth =
            compact ? constraints.maxWidth * 0.42 : constraints.maxWidth * 0.46;
        // The compact information column can be taller than a 2:3 poster when
        // a tagline, director, genres and trailer are all present.
        final heroHeight = posterWidth * 1.5 + (compact ? 22 : 0);
        return SizedBox(
          height: heroHeight,
          child: Container(
            decoration: BoxDecoration(
              color: FlixieColors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: FlixieColors.light.withValues(alpha: 0.2),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: posterWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: movie.posterPath == null
                        ? Container(
                            color: FlixieColors.tabBarBackgroundFocused,
                            child: const Icon(Icons.movie_outlined,
                                color: FlixieColors.medium, size: 42),
                          )
                        : CachedNetworkImage(
                            imageUrl:
                                'https://image.tmdb.org/t/p/w780${movie.posterPath}',
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.movie_outlined,
                                  color: FlixieColors.medium, size: 42),
                            ),
                          ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 12 : 24,
                      compact ? 10 : 18,
                      compact ? 10 : 18,
                      compact ? 10 : 18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: _buildHeroFlixScoreBadge(context, movie),
                        ),
                        SizedBox(height: compact ? 9 : 16),
                        _buildTitleBlock(context, movie, compact: compact),
                        if ((movie.tagline ?? '').isNotEmpty) ...[
                          SizedBox(height: compact ? 9 : 16),
                          Text(
                            movie.tagline!,
                            maxLines: compact ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: FlixieColors.success,
                              fontSize: compact ? 13 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (_director != null) ...[
                          SizedBox(height: compact ? 9 : 16),
                          Wrap(
                            children: [
                              Text(
                                'Directed by ',
                                style: TextStyle(
                                  color: FlixieColors.medium,
                                  fontSize: compact ? 12 : 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    context.push('/people/${_director!.id}'),
                                child: Text(
                                  _director!.name,
                                  style: TextStyle(
                                    color: FlixieColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: compact ? 12 : 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: compact ? 9 : 16),
                        _buildGenrePills(movie, compact: compact),
                        SizedBox(height: compact ? 9 : 16),
                        _buildHeroLinks(movie, compact: compact),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Title + meta --------------------------------------------------------

  Widget _buildTitleBlock(BuildContext context, Movie movie,
      {bool compact = false}) {
    final year = _extractYear(movie.releaseDate);
    final runtime = _formatRuntime(movie.runtime);
    final rating = _contentRating(movie);
    final meta =
        [year, runtime, rating].where((s) => s.isNotEmpty).join('  •  ');
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = compact ? 25.0 : (width < 700 ? 32.0 : 38.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          movie.title,
          style: TextStyle(
            color: FlixieColors.white,
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            height: 1.02,
            letterSpacing: 0.1,
          ),
        ),
        if (meta.isNotEmpty) ...[
          SizedBox(height: compact ? 9 : 8),
          Text(
            meta,
            style: TextStyle(
              color: FlixieColors.light,
              fontSize: compact ? 12 : 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeroFlixScoreBadge(BuildContext context, Movie movie) {
    final score = movie.voteAverage;
    final voteCount = movie.voteCount ?? 0;
    final hasScore = score != null && score > 0 && voteCount > 0;
    final color = !hasScore
        ? FlixieColors.medium
        : score >= 8
            ? FlixieColors.success
            : score >= 7
                ? FlixieColors.tertiary
                : score >= 6
                    ? FlixieColors.warning
                    : FlixieColors.danger;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _showFlixScoreInfo(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.65)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: color, size: 17),
              const SizedBox(width: 6),
              Text(
                hasScore ? score.toStringAsFixed(1) : '–',
                style: const TextStyle(
                  color: FlixieColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'FlixScore',
                style: TextStyle(
                    color: FlixieColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroLinks(Movie movie, {required bool compact}) {
    final videos = movie.videos ?? const [];
    final trailer = videos
            .where((video) =>
                video.videoTypeName.toLowerCase().contains('trailer'))
            .firstOrNull ??
        videos.firstOrNull;

    return Wrap(
      spacing: compact ? 12 : 24,
      runSpacing: 6,
      children: [
        _heroTextAction(
          icon: Icons.ios_share_rounded,
          label: 'Share',
          compact: compact,
          onTap: () => _shareMovie(movie),
        ),
        if (trailer != null)
          _heroTextAction(
            icon: Icons.play_circle_outline_rounded,
            label: 'Watch trailer',
            compact: compact,
            onTap: () => _openTrailer(trailer.youtubeUrl),
          ),
      ],
    );
  }

  Widget _heroTextAction({
    required IconData icon,
    required String label,
    required bool compact,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: FlixieColors.light, size: compact ? 18 : 22),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: FlixieColors.light,
                fontSize: compact ? 10.5 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareMovie(Movie movie) async {
    final appLink = 'flixie:///movies/${movie.id}';
    final webFallback = 'https://www.themoviedb.org/movie/${movie.id}';
    await Share.share(
      'Check out ${movie.title} on Flixie\n$appLink\n\n'
      "Don't have Flixie yet? $webFallback",
      subject: '${movie.title} on Flixie',
    );
  }

  Future<void> _openTrailer(String trailerUrl) async {
    final uri = Uri.tryParse(trailerUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this trailer')),
        );
      }
    }
  }

  // ---- Genre pills ---------------------------------------------------------

  Widget _buildGenrePills(Movie movie, {bool compact = false}) {
    final genres = movie.genres;
    if (genres == null || genres.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: genres
          .take(compact ? 2 : genres.length)
          .toList()
          .asMap()
          .entries
          .map((entry) {
        return GenreChip(
          label: entry.value.name.toUpperCase(),
          color: _kGenreChipColors[entry.key % _kGenreChipColors.length],
          compact: true,
        );
      }).toList(),
    );
  }

  // ---- User Rating ----------------------------------------------------------

  Future<void> _setUserRating(int rating, bool recommended) async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    final movieId = int.tryParse(widget.movieId);
    if (user == null || movieId == null || _movie == null) return;

    setState(() => _isRatingLoading = true);
    try {
      final movieService = context.read<MovieService>();
      // Add rating and get updated vote average and count
      final response = await movieService.addMovieRating(
          movieId, user.id, rating, recommended);
      await analytics.ratingSaved(source: 'movie_detail');

      // Extract updated vote data from response (safely parse types)
      final newVoteAverage = _parseDouble(response['voteAverage']);
      final newVoteCount = _parseInt(response['voteCount']);

      // Update the movie with new vote data
      final updatedMovie = _movie!.copyWith(
        voteAverage: newVoteAverage,
        voteCount: newVoteCount,
      );

      // Update cache with the new movie data
      movieService.updateCachedMovie(updatedMovie);

      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _userRating = rating;
          _userRecommends = recommended;
          _movie = updatedMovie;
          _isRatingLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to set rating: $e');
      if (mounted) setState(() => _isRatingLoading = false);
    }
  }

  void _showRatingSheet() {
    var selectedRating = _userRating;
    var recommended = _userRecommends ?? ((_userRating ?? 0) >= 7);
    showModalBottomSheet<void>(
      context: context,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          color: FlixieColors.tabBarBackgroundFocused,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rate this movie',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text(
                  'Choose a score, then decide whether you recommend it.',
                  style: TextStyle(color: FlixieColors.medium, fontSize: 13),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: List.generate(10, (i) {
                    final rating = i + 1;
                    final isSelected = selectedRating == rating;
                    return InkWell(
                      onTap: () => setSheetState(() {
                        selectedRating = rating;
                        recommended = rating >= 7;
                      }),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? FlixieColors.primary
                              : FlixieColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$rating',
                          style: TextStyle(
                            color:
                                isSelected ? Colors.white : FlixieColors.medium,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: recommended,
                  onChanged: selectedRating == null
                      ? null
                      : (value) => setSheetState(() => recommended = value),
                  activeTrackColor: FlixieColors.success,
                  title: const Text(
                    'I recommend this movie',
                    style: TextStyle(
                      color: FlixieColors.light,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Scores of 7 or higher select this automatically. You can change it.',
                    style: TextStyle(color: FlixieColors.medium, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedRating == null
                        ? null
                        : () {
                            final rating = selectedRating!;
                            Navigator.pop(ctx);
                            _setUserRating(rating, recommended);
                          },
                    child: const Text('Save rating'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Movie dashboard -----------------------------------------------------

  // Kept for the standalone dashboard treatment while the Reviews tab uses
  // the focused review feed layout.
  // ignore: unused_element
  Widget _buildMovieDashboard(BuildContext context, Movie movie) {
    final score = movie.voteAverage;
    final voteCount = movie.voteCount ?? 0;
    final hasCommunityRatings = voteCount > 0 && score != null && score > 0;
    final recentWatch =
        _movieWatchHistory.isNotEmpty ? _movieWatchHistory.first : null;
    final hasHistory = recentWatch != null;
    final watchDate = hasHistory
        ? _formatReadableDate(recentWatch.watchedAt)
        : 'Not watched yet';
    final statusLabel = _isWatched
        ? 'Watched $_watchCount ${_watchCount == 1 ? 'time' : 'times'}'
        : _inWatchlist
            ? 'On your watchlist'
            : 'Not tracked yet';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: FlixieColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your movie dashboard',
                      style: TextStyle(
                        color: FlixieColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ratings, history, and your status in one place.',
                      style: TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'About FlixScore',
                onPressed: () => _showFlixScoreInfo(context),
                icon: const Icon(
                  Icons.info_outline_rounded,
                  color: FlixieColors.medium,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 520;
              final tiles = [
                _DashboardTile(
                  title: 'FlixScore',
                  value: hasCommunityRatings
                      ? '${score.toStringAsFixed(1)}/10'
                      : '- /10',
                  icon: Icons.star_border_rounded,
                  color: Colors.deepOrangeAccent,
                  onTap: () => _showFlixScoreInfo(context),
                ),
                _DashboardTile(
                  title: 'Ratings',
                  value: _formatVoteCount(voteCount),
                  icon: Icons.people_outline_rounded,
                  color: FlixieColors.tertiary,
                  onTap: () => _showFlixScoreInfo(context),
                ),
                _DashboardTile(
                  title: 'Your rating',
                  value: _userRating != null ? '${_userRating!}/10' : '+ Rate',
                  icon: Icons.star_rounded,
                  color: FlixieColors.warning,
                  onTap: _isRatingLoading ? null : _showRatingSheet,
                ),
                _DashboardTile(
                  title: 'Your status',
                  value: statusLabel,
                  icon: _isWatched
                      ? Icons.check_circle_rounded
                      : _inWatchlist
                          ? Icons.bookmark_rounded
                          : Icons.radio_button_unchecked_rounded,
                  color: _isWatched
                      ? FlixieColors.success
                      : _inWatchlist
                          ? FlixieColors.warning
                          : FlixieColors.medium,
                ),
                _DashboardTile(
                  title: 'Last watched',
                  value: watchDate,
                  icon: Icons.schedule_rounded,
                  color: FlixieColors.light,
                ),
              ];

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: tiles
                      .map(
                        (tile) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: tile,
                          ),
                        ),
                      )
                      .toList(),
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tiles
                    .map(
                      (tile) => SizedBox(
                        width: (constraints.maxWidth - 8) / 2,
                        child: tile,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showFlixScoreInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'FLIXSCORE',
          style: TextStyle(
            color: FlixieColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Community ratings from Flixie.',
              style: TextStyle(
                color: FlixieColors.light,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Rating Guide:',
              style: TextStyle(
                color: FlixieColors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '🔥 8.1+ · Loved\n'
              '😀 7.0-8.1 · Liked\n'
              '🙂 6.0-7.0 · Okay\n'
              '😐 5.0-6.0 · Meh\n'
              '😕 Below 5.0 · Disliked\n'
              'N/A · No ratings yet.',
              style: TextStyle(
                color: FlixieColors.light,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: FlixieColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatVoteCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  // ---- Type parsing helpers ------------------------------------------------

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

  // ---- Synopsis ------------------------------------------------------------

  Widget _buildSynopsis(BuildContext context, Movie movie) {
    final text = movie.overview;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final showToggle = text.length > 250;
    final metadata = <String>[
      _formatReadableDate(movie.releaseDate),
      _formatRuntime(movie.runtime),
      _contentRating(movie),
    ].where((value) => value.isNotEmpty && value != 'Unknown').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Story'),
        const SizedBox(height: 8),
        Text(
          text,
          maxLines: _showFullSynopsis ? null : 4,
          overflow:
              _showFullSynopsis ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
            color: FlixieColors.light,
            fontSize: 14,
            height: 1.48,
          ),
        ),
        if (showToggle) ...[
          const SizedBox(height: 7),
          GestureDetector(
            onTap: () => setState(() => _showFullSynopsis = !_showFullSynopsis),
            child: Text(
              _showFullSynopsis ? 'Show less' : 'Read more',
              style: const TextStyle(
                color: FlixieColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...?movie.genres?.take(2).map(
                    (genre) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GenreChip(
                        label: genre.name,
                        color: FlixieColors.primary,
                        compact: true,
                      ),
                    ),
                  ),
              for (var index = 0; index < metadata.length; index++) ...[
                if (index > 0 || (movie.genres?.isNotEmpty ?? false))
                  Container(
                    width: 1,
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: FlixieColors.medium.withValues(alpha: 0.55),
                  ),
                Text(
                  metadata[index],
                  style: const TextStyle(
                    color: FlixieColors.light,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---- Watch request -------------------------------------------------------

  void _showWatchRequestSheet() {
    final auth = context.read<AuthProvider>();
    final friends = auth.cachedFriends?.friendships ?? [];
    final userId = auth.dbUser?.id;

    if (userId == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MovieWatchRequestSheet(
        movieId: int.tryParse(widget.movieId),
        movieTitle: _movie?.title,
        requesterId: userId,
        friends: friends,
        fromMovieMatch: widget.fromMovieMatch,
        onSuccess: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Watch invite sent!')),
            );
          }
        },
        onError: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to send invite')),
            );
          }
        },
      ),
    );
  }

  // ---- CTA buttons ---------------------------------------------------------

  Widget _buildActionButtons() {
    final primaryIsLoading = _currentlyUpdating == ListUpdateType.watched;
    final hasWatchEntries = _watchCount > 0;
    final primaryIcon =
        hasWatchEntries ? Icons.replay_rounded : Icons.video_call_outlined;
    final primaryLabel =
        hasWatchEntries ? 'Log another watch' : 'Log first watch';
    final VoidCallback primaryAction = hasWatchEntries || _isWatched
        ? () => _showLogWatchSheet()
        : _toggleWatched;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: hasWatchEntries
                      ? FlixieColors.success.withValues(alpha: 0.9)
                      : FlixieColors.primary.withValues(alpha: 0.11),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasWatchEntries
                      ? Icons.check_rounded
                      : Icons.slow_motion_video_rounded,
                  color: hasWatchEntries
                      ? FlixieColors.background
                      : FlixieColors.primary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasWatchEntries
                          ? 'Watched ${_watchCount == 1 ? 'once' : '$_watchCount times'}'
                          : 'Not watched yet',
                      style: const TextStyle(
                        color: FlixieColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    if (hasWatchEntries && _lastWatchedLabel() != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Last watched ${_lastWatchedLabel()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                    ] else if (!hasWatchEntries) ...[
                      const SizedBox(height: 3),
                      const Text(
                        'Log your first watch to start your history',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: FlixieColors.light,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _currentlyUpdating != null
                        ? null
                        : () => primaryAction(),
                    icon: primaryIsLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(primaryIcon, size: 20),
                    label: Text(primaryLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlixieColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rate and review each watch separately',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _statusActionItem(
                  icon: Icons.star_outline_rounded,
                  label: 'Rate',
                  badge: _userRating != null ? '${_userRating!}/10' : null,
                  color: FlixieColors.tertiary,
                  isActive: _userRating != null,
                  isLoading: _isRatingLoading,
                  onTap: _currentlyUpdating != null || _isRatingLoading
                      ? null
                      : _showRatingSheet,
                ),
              ),
              Expanded(
                child: _statusActionItem(
                  icon: _inWatchlist ? Icons.bookmark : Icons.bookmark_outline,
                  label: 'Watchlist',
                  color: FlixieColors.warning,
                  isActive: _inWatchlist,
                  isLoading: _currentlyUpdating == ListUpdateType.watchlist,
                  onTap: _currentlyUpdating != null ? null : _toggleWatchlist,
                ),
              ),
              Expanded(
                child: _statusActionItem(
                  icon: _isFavorite ? Icons.favorite : Icons.favorite_outline,
                  label: 'Favourite',
                  color: FlixieColors.danger,
                  isActive: _isFavorite,
                  isLoading: _currentlyUpdating == ListUpdateType.favorite,
                  onTap: _currentlyUpdating != null ? null : _toggleFavorite,
                ),
              ),
              Expanded(
                child: _statusActionItem(
                  icon: _myListsContainingMovie.isNotEmpty
                      ? Icons.playlist_add_check_rounded
                      : Icons.playlist_add_rounded,
                  label: 'List',
                  color: FlixieColors.secondary,
                  isActive: _myListsContainingMovie.isNotEmpty,
                  isLoading: _listsContainingMovieLoading,
                  onTap:
                      _currentlyUpdating != null ? null : _showAddToListSheet,
                ),
              ),
              Expanded(
                child: _statusActionItem(
                  icon: Icons.group_add_outlined,
                  label: 'Invite',
                  color: FlixieColors.primary,
                  isActive: false,
                  isLoading: false,
                  onTap: _currentlyUpdating != null
                      ? null
                      : _showWatchRequestSheet,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _lastWatchedLabel() {
    if (_movieWatchHistory.isEmpty) return null;
    final dates = _movieWatchHistory
        .map((entry) => DateTime.tryParse(entry.watchedAt ?? ''))
        .whereType<DateTime>()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (dates.isEmpty) return null;
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final date = dates.first.toLocal();
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _statusActionItem({
    required IconData icon,
    required String label,
    String? badge,
    required Color color,
    required bool isActive,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    final iconColor = isActive ? color : FlixieColors.medium;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 38,
                  height: 34,
                  child: Center(
                    child: isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(iconColor),
                            ),
                          )
                        : Icon(icon, size: 27, color: iconColor),
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 14,
                  child: Text(
                    badge == null ? label : '$label $badge',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isActive ? color : FlixieColors.light,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 1.05,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWatchHistorySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Watch History'),
        const SizedBox(height: 10),
        if (_watchHistoryLoading)
          const Center(child: CircularProgressIndicator())
        else if (_movieWatchHistory.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FlixieColors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Text(
              'No watch history yet for this movie.',
              style: TextStyle(color: FlixieColors.medium),
            ),
          )
        else
          ..._movieWatchHistory.take(5).map(
                (entry) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: FlixieColors.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      title: Text(
                        _formatWatchDate(entry.watchedAt),
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (entry.rating != null)
                            'Rating: ${entry.rating!.toStringAsFixed(0)}/10',
                          if (entry.notes != null && entry.notes!.isNotEmpty)
                            entry.notes!,
                        ].join(' • '),
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        iconColor: FlixieColors.light,
                        color: FlixieColors.tabBarBackgroundFocused,
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showLogWatchSheet(entry: entry);
                            return;
                          }
                          _deleteWatchEntry(entry);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(
                              'Edit',
                              style: TextStyle(color: FlixieColors.light),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete',
                              style: TextStyle(color: FlixieColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  String _formatWatchDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '');
    if (dt == null) return 'Unknown date';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatReadableDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '');
    if (dt == null) return 'Unknown';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  // Retained while the compact friend view replaces the old recommendation UI.
  // ignore: unused_element
  void _showAllFriendRecommendations(BuildContext context) {
    final data = _friendRecommendation;
    if (data == null) return;
    final watchedFriends = data.friends.where((f) => f.watched).toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlixieColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Friend Recommendations',
                    style: TextStyle(
                      color: FlixieColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${data.recommendPercent}% recommend',
                    style: const TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(
                height: 1, thickness: 1, color: FlixieColors.tabBarBorder),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: watchedFriends.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, thickness: 1, color: FlixieColors.tabBarBorder),
                itemBuilder: (_, index) {
                  final f = watchedFriends[index];
                  final name = f.username;
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor:
                          FlixieColors.primary.withValues(alpha: 0.18),
                      backgroundImage: f.avatarUrl != null
                          ? NetworkImage(f.avatarUrl!)
                          : null,
                      child: f.avatarUrl == null
                          ? Text(
                              initial,
                              style: const TextStyle(
                                  color: FlixieColors.primary,
                                  fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    title: Text(name,
                        style: const TextStyle(color: FlixieColors.light)),
                    subtitle: f.rating != null
                        ? Text(
                            '${f.rating!.toStringAsFixed(1)} / 10',
                            style: const TextStyle(
                                color: FlixieColors.medium, fontSize: 12),
                          )
                        : null,
                    trailing: f.recommends
                        ? const Icon(Icons.thumb_up_rounded,
                            color: FlixieColors.success, size: 18)
                        : const Icon(Icons.thumb_down_rounded,
                            color: FlixieColors.danger, size: 18),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/friends/${f.userId}');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Friend summary ----------------------------------------------------

  Widget _buildFriendSummarySection(BuildContext context) {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return const SizedBox.shrink();
    final movieId = int.tryParse(widget.movieId);
    final loading = _friendSummaryLoading || _friendRecommendationLoading;
    if (loading && _friendsActivity.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_friendsActivity.isEmpty && _friendSummary?.friendCount != null) {
      return const SizedBox.shrink();
    }
    if (_friendsActivity.isEmpty &&
        (_friendSummaryError != null || _friendRecommendationError != null)) {
      return TextButton.icon(
        onPressed: movieId == null
            ? null
            : () {
                _loadFriendSummary(movieId);
                _loadFriendRecommendation(movieId);
              },
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Reload friend activity'),
      );
    }

    final activities = _friendsActivity;
    final watched = activities.where((item) => item.watched).length;
    final rated = activities.where((item) => item.rating != null).length;
    final recommended =
        activities.where((item) => item.recommended == true).length;
    final watchlisted = activities.where((item) => item.onWatchlist).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Friends',
                style: TextStyle(
                  color: FlixieColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (activities.length > 3)
              TextButton.icon(
                onPressed: () => _showAllFriendsActivity(context, activities),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded, size: 17),
                label: const Text('View all'),
                style: TextButton.styleFrom(
                  foregroundColor: FlixieColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        Text(
          '${activities.length} ${activities.length == 1 ? 'friend' : 'friends'} interacted',
          style: const TextStyle(color: FlixieColors.medium, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: _friendPanelDecoration(),
          child: Row(
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  width: 58,
                  height: 28,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: activities
                        .take(3)
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) => Positioned(
                              left: entry.key * 17,
                              top: 0,
                              child:
                                  _compactFriendAvatar(entry.value, size: 28),
                            ))
                        .toList(),
                  ),
                ),
              ),
              _friendStat(watched, 'watched'),
              _friendStat(rated, 'rated'),
              _friendStat(recommended, 'recommend'),
              _friendStat(watchlisted, 'watchlist'),
            ],
          ),
        ),
        const SizedBox(height: 7),
        ...activities.take(3).map(_compactFriendRow),
      ],
    );
  }

  BoxDecoration _friendPanelDecoration() => BoxDecoration(
        color: FlixieColors.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      );

  Widget _friendStat(int value, String label) => Expanded(
        child: Column(
          children: [
            Text('$value',
                style: const TextStyle(
                    color: FlixieColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style:
                    const TextStyle(color: FlixieColors.medium, fontSize: 9.5)),
          ],
        ),
      );

  Widget _compactFriendAvatar(MovieFriendActivity activity,
      {double size = 30}) {
    final hex =
        activity.iconColor?['hexCode']?.toString().replaceFirst('#', '');
    final value = hex == null
        ? null
        : int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    final color = value == null ? FlixieColors.primary : Color(value);
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: const BoxDecoration(
        color: FlixieColors.surface,
        shape: BoxShape.circle,
      ),
      child: ProfileAvatarView(
        avatar: activity.avatar,
        fallbackText: activity.username.isEmpty
            ? '?'
            : activity.username[0].toUpperCase(),
        fallbackColor: color,
        size: size - 3,
        profileBadges: activity.profileBadges,
      ),
    );
  }

  Widget _compactFriendRow(MovieFriendActivity activity) {
    final chips = <Widget>[
      if (activity.watched)
        _compactFriendChip(
          (activity.watchCount ?? 0) > 2
              ? 'Watched ${activity.watchCount} times'
              : activity.isRewatch || activity.watchCount == 2
                  ? 'Watched twice'
                  : 'Watched',
          Icons.check_rounded,
          FlixieColors.success,
        ),
      if (activity.onWatchlist)
        _compactFriendChip(
          'In watchlist',
          Icons.bookmark_outline_rounded,
          FlixieColors.primary,
        ),
      if (activity.favorited)
        _compactFriendChip(
          'Favourite',
          Icons.favorite_rounded,
          FlixieColors.danger,
        ),
      if (activity.reviewed)
        _compactFriendChip(
          'Reviewed',
          Icons.check_box_rounded,
          const Color(0xFF70A7FF),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => context.push('/friends/${activity.userId}'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: _friendPanelDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _compactFriendAvatar(activity, size: 38),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.username,
                      style: const TextStyle(
                        color: FlixieColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: chips,
                      ),
                    ],
                  ],
                ),
              ),
              if (activity.recommended != null) ...[
                const SizedBox(width: 7),
                Tooltip(
                  message: activity.recommended!
                      ? 'Recommends'
                      : "Doesn't recommend",
                  child: Icon(
                    activity.recommended!
                        ? Icons.thumb_up_alt_rounded
                        : Icons.thumb_down_alt_rounded,
                    color: activity.recommended!
                        ? FlixieColors.success
                        : FlixieColors.danger,
                    size: 17,
                  ),
                ),
              ],
              if (activity.rating != null) ...[
                const SizedBox(width: 9),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: FlixieColors.warning, size: 16),
                    const SizedBox(width: 2),
                    Text(
                      '${activity.rating}/10',
                      style: const TextStyle(
                        color: FlixieColors.light,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: FlixieColors.primary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactFriendChip(String label, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.65)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 10),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 9, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _buildMovieDetailTabs() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: FlixieColors.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: MovieDetailTab.values.map((tab) {
          final selected = _movieDetailTab == tab;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _movieDetailTab = tab),
              borderRadius: BorderRadius.circular(11),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? FlixieColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  switch (tab) {
                    MovieDetailTab.overview => 'Overview',
                    MovieDetailTab.reviews => 'Reviews',
                    MovieDetailTab.activity => 'My Activity',
                    MovieDetailTab.details => 'Details',
                  },
                  maxLines: 1,
                  style: TextStyle(
                    color: selected ? FlixieColors.white : FlixieColors.light,
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildSelectedMovieTab(BuildContext context, Movie movie) {
    return switch (_movieDetailTab) {
      MovieDetailTab.overview => _tabContent([
          _buildSynopsis(context, movie),
          _buildTopCastSection(context),
          _buildTrailersSection(context, movie),
          _buildMoreLikeThisSection(context),
          _buildDirectorLink(context),
        ]),
      MovieDetailTab.reviews => _tabContent([
          _buildUserReviewsSection(context),
        ]),
      MovieDetailTab.activity => _tabContent([
          _buildWatchHistorySection(context),
          _buildListsSection(context),
        ]),
      MovieDetailTab.details => _tabContent([
          FilmInfoCard(
            director: null,
            writers: _writers,
            producers: _producers,
            movie: movie,
          ),
          ExternalLinksSection(movie: movie),
        ]),
    };
  }

  Widget _tabContent(List<Widget> sections) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          sections[index],
          if (index != sections.length - 1)
            const SizedBox(height: _sectionSpacing),
        ],
      ],
    );
  }

  // ---- Friends activity --------------------------------------------------

  // Retained for the full filtered activity treatment if it is restored later.
  // ignore: unused_element
  Widget _buildFriendsActivityContent(BuildContext context) {
    final filtered = _filteredFriendsActivity();
    final yourActivityBadges = _buildYourActivityBadges();
    final showYourActivityFooter = yourActivityBadges.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity',
          style: TextStyle(
            color: FlixieColors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _kFriendActivityTabs.map((tab) {
              final selected = _friendsActivityTab == tab.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _friendsActivityTab = tab.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? FlixieColors.primary.withValues(alpha: 0.22)
                          : FlixieColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? FlixieColors.primary.withValues(alpha: 0.55)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      tab.$2,
                      style: TextStyle(
                        color: selected
                            ? FlixieColors.primary
                            : FlixieColors.light,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (filtered.isEmpty)
              Text(
                _friendsActivity.isEmpty
                    ? 'No friend activity yet for this movie.'
                    : 'No ${_friendTabLabel(_friendsActivityTab).toLowerCase()} activity yet.',
                style: const TextStyle(color: FlixieColors.medium),
              )
            else
              Column(
                children: filtered
                    .take(3)
                    .map((a) => FriendActivityRow(activity: a))
                    .toList(growable: false),
              ),
            if (filtered.length > 3) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _showAllFriendsActivity(context, filtered),
                  icon: const Icon(Icons.people_outline_rounded, size: 18),
                  label: Text('View all ${filtered.length} activities'),
                ),
              ),
            ],
            if (showYourActivityFooter) ...[
              if (filtered.isNotEmpty) const SizedBox(height: 4),
              const Divider(
                height: 20,
                thickness: 1,
                color: FlixieColors.tabBarBorder,
              ),
              const Text(
                'Your activity',
                style: TextStyle(
                  color: FlixieColors.light,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: yourActivityBadges,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _showAllFriendsActivity(
    BuildContext context,
    List<MovieFriendActivity> activities,
  ) {
    var selectedTab = FriendActivityTab.all;
    var query = '';
    final watchedCount = activities.where((item) => item.watched).length;
    final ratedCount = activities.where((item) => item.rating != null).length;
    final recommendCount =
        activities.where((item) => item.recommended == true).length;
    final watchlistCount = activities.where((item) => item.onWatchlist).length;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final visible = activities.where((activity) {
            final matchesQuery = query.isEmpty ||
                activity.username.toLowerCase().contains(query);
            final matchesTab = switch (selectedTab) {
              FriendActivityTab.all => true,
              FriendActivityTab.watched => activity.watched,
              FriendActivityTab.watchlist => activity.onWatchlist,
              FriendActivityTab.ratings => activity.rating != null,
              FriendActivityTab.reviews => activity.recommended == true,
              FriendActivityTab.lists => true,
            };
            return matchesQuery && matchesTab;
          }).toList(growable: false);
          final tabs = <(FriendActivityTab, String, int)>[
            (FriendActivityTab.all, 'All', activities.length),
            (FriendActivityTab.watched, 'Watched', watchedCount),
            (FriendActivityTab.ratings, 'Rated', ratedCount),
            (FriendActivityTab.reviews, 'Recommend', recommendCount),
            (FriendActivityTab.watchlist, 'Watchlist', watchlistCount),
          ];

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.55,
            maxChildSize: 0.96,
            expand: false,
            builder: (context, controller) => Container(
              decoration: const BoxDecoration(
                color: FlixieColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: FlixieColors.medium,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Friends',
                            style: TextStyle(
                              color: FlixieColors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${activities.length} ${activities.length == 1 ? 'friend' : 'friends'} interacted with this movie',
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: _friendPanelDecoration(),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 96,
                            height: 34,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ...activities
                                    .take(3)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map((entry) => Positioned(
                                          left: entry.key * 20,
                                          child: _compactFriendAvatar(
                                              entry.value,
                                              size: 34),
                                        )),
                                if (activities.length > 3)
                                  Positioned(
                                    left: 58,
                                    child: Container(
                                      width: 31,
                                      height: 31,
                                      margin: const EdgeInsets.all(1.5),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: FlixieColors.surfaceElevated,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: FlixieColors.medium),
                                      ),
                                      child: Text(
                                        '+${activities.length - 3}',
                                        style: const TextStyle(
                                          color: FlixieColors.light,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _friendStat(watchedCount, 'watched'),
                          _friendStat(ratedCount, 'rated'),
                          _friendStat(recommendCount, 'recommend'),
                          _friendStat(watchlistCount, 'watchlist'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      onChanged: (value) => setSheetState(
                        () => query = value.trim().toLowerCase(),
                      ),
                      style: const TextStyle(color: FlixieColors.white),
                      decoration: InputDecoration(
                        hintText: 'Search friends',
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        filled: true,
                        fillColor:
                            FlixieColors.background.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: tabs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 7),
                      itemBuilder: (_, index) {
                        final tab = tabs[index];
                        final selected = selectedTab == tab.$1;
                        return ChoiceChip(
                          selected: selected,
                          showCheckmark: false,
                          label: Text('${tab.$2}  ${tab.$3}'),
                          onSelected: (_) =>
                              setSheetState(() => selectedTab = tab.$1),
                          selectedColor: FlixieColors.primary,
                          backgroundColor: Colors.transparent,
                          side: BorderSide(
                            color: selected
                                ? FlixieColors.primary
                                : FlixieColors.medium.withValues(alpha: 0.5),
                          ),
                          labelStyle: TextStyle(
                            color: selected
                                ? FlixieColors.white
                                : FlixieColors.light,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: FlixieColors.tabBarBorder),
                  Expanded(
                    child: visible.isEmpty
                        ? const Center(
                            child: Text('No matching friends',
                                style: TextStyle(color: FlixieColors.medium)),
                          )
                        : ListView.builder(
                            controller: controller,
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                            itemCount: visible.length,
                            itemBuilder: (_, index) =>
                                _compactFriendRow(visible[index]),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<MovieFriendActivity> _filteredFriendsActivity() {
    return _friendsActivity.where((activity) {
      switch (_friendsActivityTab) {
        case FriendActivityTab.all:
          return true;
        case FriendActivityTab.watched:
          return activity.watched;
        case FriendActivityTab.watchlist:
          return activity.onWatchlist;
        case FriendActivityTab.ratings:
          return activity.rating != null;
        case FriendActivityTab.reviews:
          return activity.recommended != null;
        case FriendActivityTab.lists:
          return false;
      }
    }).toList(growable: false);
  }

  List<Widget> _buildYourActivityBadges() {
    final badges = <Widget>[];
    if (_isFavorite) {
      badges.add(_buildYourActivityChip(
        icon: Icons.favorite,
        label: 'In favourites',
        color: Colors.redAccent,
      ));
    }
    if (_isWatched) {
      badges.add(_buildYourActivityChip(
        icon: Icons.check_circle,
        label: 'Watched',
        color: FlixieColors.success,
      ));
    }
    if (_inWatchlist) {
      badges.add(_buildYourActivityChip(
        icon: Icons.bookmark,
        label: 'In watchlist',
        color: FlixieColors.warning,
      ));
    }
    if (_userRating != null) {
      badges.add(_buildYourActivityChip(
        icon: Icons.star_rounded,
        label: '${_userRating!}/10',
        color: FlixieColors.tertiary,
      ));
    }
    if (_userRecommends != null) {
      badges.add(_buildYourActivityChip(
        icon: _userRecommends!
            ? Icons.thumb_up_alt_rounded
            : Icons.thumb_down_alt_rounded,
        label: _userRecommends! ? 'Recommended' : 'Not recommended',
        color: _userRecommends! ? FlixieColors.success : FlixieColors.medium,
      ));
    }
    return badges;
  }

  Widget _buildYourActivityChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildYourListsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Your Lists'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: _listsContainingMovieLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _myListsContainingMovie.isEmpty
                          ? "This movie isn't in any of your lists yet."
                          : 'This movie is in ${_myListsContainingMovie.length} of your lists',
                      style: const TextStyle(color: FlixieColors.medium),
                    ),
                    if (_myListsContainingMovie.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._myListsContainingMovie.map(
                        (list) => Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(list.name),
                            subtitle: Text('${list.movieCount ?? 0} film(s)'),
                            trailing: const Icon(
                              Icons.check_circle,
                              color: FlixieColors.primary,
                              size: 18,
                            ),
                            onTap: () => context.push(
                              '/movie-lists/${list.id}?name=${Uri.encodeComponent(list.name)}&owner=${Uri.encodeComponent(list.userId ?? '')}',
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showAddToListSheet,
                        icon: const Icon(Icons.add),
                        label: const Text('Add to List'),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildListsSection(BuildContext context) {
    final ownLists = _myListsContainingMovie
        .map((list) => MediaDetailListItem(
              id: list.id,
              name: list.name,
              visibility: list.visibility,
              posterUrls: list.previewPosterUrls,
              itemCount: list.itemCount ??
                  (list.movieCount ?? 0) + (list.showCount ?? 0),
              ownerId: list.userId,
            ))
        .toList(growable: false);
    final friendLists = _friendsListsContainingMovie
        .map((entry) => MediaDetailListItem(
              id: entry.listId,
              name: entry.listName,
              visibility: entry.visibility ?? 'PUBLIC',
              posterUrls: entry.previewPosterUrls,
              itemCount: entry.movieCount ?? 0,
              ownerId: entry.friendUserId,
              ownerUsername: entry.friendName,
              ownerAvatar: entry.friendAvatar,
            ))
        .toList(growable: false);

    return MediaListsSection(
      ownLists: ownLists,
      friendLists: friendLists,
      loading: _listsContainingMovieLoading,
      itemLabel: 'films',
      onEdit: _showAddToListSheet,
      onSeeAll: () => context.push('/movie-lists'),
      onOpenList: (item) => context.push(
        '/movie-lists/${item.id}'
        '?name=${Uri.encodeComponent(item.name)}'
        '&owner=${Uri.encodeComponent(item.ownerId ?? '')}',
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFriendsListsSection(BuildContext context) {
    final totalFriends = _friendsListsContainingMovie
        .map((entry) => entry.friendUserId)
        .toSet()
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Friends Lists'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: _listsContainingMovieLoading
              ? const Center(child: CircularProgressIndicator())
              : _friendsListsContainingMovie.isEmpty
                  ? const Text(
                      "None of your friends have added this to a list yet.",
                      style: TextStyle(color: FlixieColors.medium),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This movie is in $totalFriends friends\' lists',
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._friendsListsContainingMovie.take(6).map(
                              (entry) => Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: ProfileAvatarView(
                                    avatar: entry.friendAvatar,
                                    fallbackText: (entry.friendName.isNotEmpty
                                            ? entry.friendName[0]
                                            : '?')
                                        .toUpperCase(),
                                    fallbackColor: FlixieColors.primary,
                                    size: 40,
                                  ),
                                  title: Text(
                                    "${entry.friendName} · ${entry.listName}",
                                    style: const TextStyle(
                                      color: FlixieColors.light,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle:
                                      Text('${entry.movieCount ?? 0} films'),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: FlixieColors.medium,
                                  ),
                                  onTap: () => context.push(
                                    '/movie-lists/${entry.listId}'
                                    '?name=${Uri.encodeComponent(entry.listName)}'
                                    '&owner=${Uri.encodeComponent(entry.friendUserId)}',
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: const TextStyle(
        color: FlixieColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
    );
  }

  String _friendTabLabel(FriendActivityTab tab) {
    return _kFriendActivityTabs
            .where((entry) => entry.$1 == tab)
            .map((entry) => entry.$2)
            .firstOrNull ??
        'Activity';
  }

  // ---- Trailers -----------------------------------------------------------

  Widget _buildTrailersSection(BuildContext context, Movie movie) {
    final videos = movie.videos;
    if (videos == null || videos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(context, 'Trailers'),
            if (videos.length > 1)
              TextButton(
                onPressed: () => _showAllTrailersSheet(context, videos),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    color: FlixieColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: videos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => VideoCard(video: videos[i]),
          ),
        ),
      ],
    );
  }

  void _showAllTrailersSheet(BuildContext context, List<dynamic> videos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: FlixieColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            itemCount: videos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) => VideoCard(video: videos[i]),
          ),
        ),
      ),
    );
  }

  // ---- Where to watch ------------------------------------------------------

  Widget _buildWhereToWatchSection(BuildContext context) {
    if (_watchProviders.isEmpty) return const SizedBox.shrink();
    final providers = _providersForTab(_watchProviderTab);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Where to watch'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: WatchProviderTab.values
                .map(
                  (tab) => Expanded(
                    child: _watchProviderTabButton(tab),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 8),
        if (providers.isNotEmpty)
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: providers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) =>
                  _buildCompactProviderCard(providers[index]),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            alignment: Alignment.center,
            child: Text(
              'No ${_providerTabLabel(_watchProviderTab).toLowerCase()} options in your region yet.',
              style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 12,
              ),
            ),
          ),
        if (providers.length > 3)
          SizedBox(
            height: 30,
            child: TextButton.icon(
              onPressed: () => _showAllProviderOptions(providers),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right_rounded, size: 17),
              label: Text('All ${providers.length} options'),
              style: TextButton.styleFrom(
                foregroundColor: FlixieColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );
  }

  Widget _watchProviderTabButton(WatchProviderTab tab) {
    final selected = _watchProviderTab == tab;
    return InkWell(
      onTap: () => setState(() => _watchProviderTab = tab),
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? FlixieColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(
          _providerTabLabel(tab),
          style: TextStyle(
            color: selected ? FlixieColors.white : FlixieColors.light,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _providerTabLabel(WatchProviderTab tab) => switch (tab) {
        WatchProviderTab.stream => 'Stream',
        WatchProviderTab.rent => 'Rent',
        WatchProviderTab.buy => 'Buy',
      };

  List<WatchProvider> _providersForTab(WatchProviderTab tab) {
    final matching = switch (tab) {
      WatchProviderTab.stream =>
        _watchProviders.where((provider) => provider.isStreaming),
      WatchProviderTab.rent =>
        _watchProviders.where((provider) => provider.isRental),
      WatchProviderTab.buy =>
        _watchProviders.where((provider) => provider.isPurchase),
    };
    return _sortedProviders(_dedupeProviders(matching));
  }

  Widget _buildCompactProviderCard(WatchProvider provider) {
    final isUserProvider = _userProviderIds.contains(provider.id);
    final availabilityLabel = switch (_watchProviderTab) {
      WatchProviderTab.stream => isUserProvider ? 'Included' : 'Subscription',
      WatchProviderTab.rent => 'Available to rent',
      WatchProviderTab.buy => 'Available to buy',
    };
    return Container(
      width: 150,
      height: 58,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isUserProvider && _watchProviderTab == WatchProviderTab.stream
            ? FlixieColors.success.withValues(alpha: 0.08)
            : FlixieColors.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUserProvider && _watchProviderTab == WatchProviderTab.stream
              ? FlixieColors.success.withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.1),
          width: isUserProvider && _watchProviderTab == WatchProviderTab.stream
              ? 1.4
              : 1,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              width: 34,
              height: 34,
              child: provider.logoPath.isEmpty
                  ? const ColoredBox(
                      color: FlixieColors.surfaceElevated,
                      child: Icon(Icons.play_circle_outline_rounded,
                          color: FlixieColors.medium),
                    )
                  : CachedNetworkImage(
                      imageUrl: provider.logoUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: FlixieColors.surfaceElevated,
                        child: Icon(Icons.play_circle_outline_rounded,
                            color: FlixieColors.medium),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlixieColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  availabilityLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlixieColors.success,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: FlixieColors.primary, size: 17),
        ],
      ),
    );
  }

  void _showAllProviderOptions(List<WatchProvider> providers) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlixieColors.background,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_providerTabLabel(_watchProviderTab)} options',
                style: const TextStyle(
                  color: FlixieColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: providers.map(_buildCompactProviderCard).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Iterable<WatchProvider> _dedupeProviders(Iterable<WatchProvider> providers) {
    final byId = <int, WatchProvider>{};
    for (final provider in providers) {
      byId.putIfAbsent(provider.id, () => provider);
    }
    return byId.values;
  }

  List<WatchProvider> _sortedProviders(Iterable<WatchProvider> providers) {
    return providers.toList()
      ..sort((a, b) {
        final aMatches = _userProviderIds.contains(a.id);
        final bMatches = _userProviderIds.contains(b.id);
        if (aMatches != bMatches) return aMatches ? -1 : 1;
        return a.displayPriority.compareTo(b.displayPriority);
      });
  }

  // ---- Top cast ------------------------------------------------------------

  void _showAllCast(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllCastSheet(cast: _cast),
    );
  }

  Widget _buildTopCastSection(BuildContext context) {
    if (_cast.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(context, 'Top Cast'),
            TextButton(
              onPressed: () => _showAllCast(context),
              child: const Row(
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      color: FlixieColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: FlixieColors.primary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 232,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _cast.length > 6 ? 6 : _cast.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => CastCard(member: _cast[i]),
          ),
        ),
      ],
    );
  }

  // ---- Write review -------------------------------------------------------

  Future<void> _showWriteReviewSheet(BuildContext context) async {
    final user = context.read<AuthProvider>().dbUser;
    if (user == null) return;
    final movieId = int.tryParse(widget.movieId);
    if (movieId == null) return;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WriteReviewSheet(
        movieId: movieId,
        userId: user.id,
        onSubmitted: (review) {
          final auth = context.read<AuthProvider>();
          setState(() => _reviews = [review, ..._reviews]);
          auth.invalidateCachedReviews();
          auth.markActivityChanged();
        },
      ),
    );
  }

  // ---- User reviews --------------------------------------------------------

  void _showAllReviews(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: FlixieColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlixieColors.medium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Reviews (${_reviews.length})',
                      style: const TextStyle(
                        color: FlixieColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: FlixieColors.light),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: FlixieColors.tabBarBorder, height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _reviews.length,
                  itemBuilder: (_, i) => ReviewCard(
                    review: _reviews[i],
                    currentUserId: currentUserId,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserReviewsSection(BuildContext context) {
    const previewCount = 4;
    final preview = _reviews.take(previewCount).toList();
    final hasMore = _reviews.length > previewCount;
    final currentUserId = context.read<AuthProvider>().dbUser?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Reviews',
                style: TextStyle(
                  color: FlixieColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_reviews.isNotEmpty)
              TextButton(
                onPressed: () => _showAllReviews(context),
                style: TextButton.styleFrom(
                  foregroundColor: FlixieColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  'See all ${_reviews.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: FlixieColors.primary,
                side: const BorderSide(color: FlixieColors.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _showWriteReviewSheet(context),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Write review',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No reviews yet. Be the first to write one!',
              style: TextStyle(color: FlixieColors.medium, fontSize: 13),
            ),
          )
        else ...[
          ...preview.map((r) => ReviewCard(
                review: r,
                currentUserId: currentUserId,
              )),
          if (hasMore) const SizedBox.shrink(),
        ],
      ],
    );
  }

  // ---- More like this ------------------------------------------------------

  Widget _buildMoreLikeThisSection(BuildContext context) {
    if (_similar.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'More like this'),
        const SizedBox(height: 8),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _similar.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SimilarMovieCard(movie: _similar[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectorLink(BuildContext context) {
    final director = _director;
    if (director == null) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/people/${director.id}'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.movie_filter_outlined,
                  color: FlixieColors.primary, size: 23),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Directed by ${director.name}',
                  style: const TextStyle(
                    color: FlixieColors.light,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: FlixieColors.light, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllCastSheet extends StatefulWidget {
  const _AllCastSheet({required this.cast});

  final List<MovieCastMember> cast;

  @override
  State<_AllCastSheet> createState() => _AllCastSheetState();
}

class _AllCastSheetState extends State<_AllCastSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _sortByName = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MovieCastMember> get _filteredCast {
    final query = _query.trim().toLowerCase();
    final cast = (query.isEmpty
            ? widget.cast
            : widget.cast.where((member) {
                return member.name.toLowerCase().contains(query) ||
                    member.character.toLowerCase().contains(query);
              }))
        .toList();
    if (_sortByName) {
      cast.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      cast.sort((a, b) => a.order.compareTo(b.order));
    }
    return cast;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCast;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.97,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: FlixieColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 10),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: FlixieColors.medium.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cast',
                          style: TextStyle(
                            color: FlixieColors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${widget.cast.length} cast members',
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: FlixieColors.light),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(color: FlixieColors.white),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search actor or character',
                  hintStyle: const TextStyle(color: FlixieColors.medium),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: FlixieColors.medium),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded,
                              color: FlixieColors.medium),
                        ),
                  filled: true,
                  fillColor: FlixieColors.surface.withValues(alpha: 0.72),
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: FlixieColors.primary),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 18, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'TOP BILLED',
                      style: TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  PopupMenuButton<bool>(
                    tooltip: 'Sort cast',
                    initialValue: _sortByName,
                    onSelected: (value) => setState(() => _sortByName = value),
                    color: FlixieColors.surfaceElevated,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: false, child: Text('Billing order')),
                      PopupMenuItem(value: true, child: Text('Actor name')),
                    ],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _sortByName ? 'Actor name' : 'Billing order',
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: FlixieColors.medium, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const _EmptyCastSearch()
                  : ListView.separated(
                      controller: scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => SizedBox(
                        height: 9,
                        child: Center(
                          child: Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                        ),
                      ),
                      itemBuilder: (context, index) =>
                          _FullCastCard(member: filtered[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullCastCard extends StatelessWidget {
  const _FullCastCard({required this.member});

  final MovieCastMember member;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final router = GoRouter.of(context);
          Navigator.pop(context);
          router.push('/people/${member.id}');
        },
        child: SizedBox(
          height: 94,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 76,
                  height: double.infinity,
                  child: member.profileImageUrl == null
                      ? const ColoredBox(
                          color: FlixieColors.surfaceElevated,
                          child: Icon(Icons.person_rounded,
                              color: FlixieColors.medium, size: 36),
                        )
                      : CachedNetworkImage(
                          imageUrl: member.profileImageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: FlixieColors.surfaceElevated,
                            child: Icon(Icons.person_rounded,
                                color: FlixieColors.medium, size: 36),
                          ),
                        ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                          height: 1.2,
                        ),
                      ),
                      if (member.character.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          member.character,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: FlixieColors.medium, size: 26),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCastSearch extends StatelessWidget {
  const _EmptyCastSearch();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_rounded,
              color: FlixieColors.medium, size: 42),
          SizedBox(height: 10),
          Text('No cast members found',
              style: TextStyle(
                  color: FlixieColors.light, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.medium,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return tile;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: tile,
      ),
    );
  }
}
