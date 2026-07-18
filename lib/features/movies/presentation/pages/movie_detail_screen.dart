import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
import 'package:flixie_app/features/movies/presentation/widgets/friend_summary_section.dart';
import 'package:flixie_app/features/movies/presentation/widgets/external_links_section.dart';
import 'package:flixie_app/features/movies/presentation/widgets/film_info_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/friend_activity_row.dart';
import 'package:flixie_app/features/movies/presentation/widgets/genre_chip.dart';
import 'package:flixie_app/features/movies/presentation/widgets/hero_backdrop.dart';
import 'package:flixie_app/features/movies/presentation/widgets/add_to_list_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/review_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/similar_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/video_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_provider_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId});

  final String movieId;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

enum ListUpdateType { watchlist, watched, favorite }

enum FriendActivityTab { all, watched, watchlist, ratings, reviews, lists }

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  Movie? _movie;
  List<Review> _reviews = [];
  List<SimilarMovie> _similar = [];
  List<MovieCastMember> _cast = [];
  List<WatchProvider> _watchProviders = [];
  Set<int> _userProviderIds = {};
  bool _showPurchaseProviders = false;
  String? _director;
  List<String> _producers = [];
  List<String> _writers = [];
  bool _isLoading = true;
  String? _error;
  bool _inWatchlist = false;
  bool _isWatched = false;
  bool _isFavorite = false;
  int? _userRating;
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
              .map((crew) => crew.name)
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
            _userRating = results[5] as int?;
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
              final watchedResult = await WatchlistActionsController.instance
                  .addToWatched(user.id, movieId);
              final updatedWatched =
                  List<WatchedMovie>.from(user.watchedMovies ?? []);
              updatedWatched.removeWhere((item) => item.movieId == movieId);
              updatedWatched.add(watchedResult ??
                  WatchedMovie(
                    id: '',
                    userId: user.id,
                    movieId: movieId,
                    watchedAt: DateTime.now().toIso8601String(),
                  ));
              setState(() => _isWatched = true);
              authProvider.updateUserList(watchedMovies: updatedWatched);
              authProvider.markActivityChanged();
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

    // When not yet watched, open the log watch sheet so the user can record
    // date/rating/notes. The sheet marks the movie as watched on success.
    if (!_isWatched) {
      await _showLogWatchSheet();
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
    final user = authProvider.dbUser;
    final movieId = int.tryParse(widget.movieId);

    if (user == null || movieId == null) return;

    setState(() => _currentlyUpdating = ListUpdateType.favorite);
    try {
      final FavoriteMovie? addedFavorite;
      if (_isFavorite) {
        await WatchlistActionsController.instance
            .removeFromFavorites(user.id, movieId);
        addedFavorite = null;
      } else {
        addedFavorite = await WatchlistActionsController.instance
            .addToFavorites(user.id, movieId);
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

  Future<void> _showLogWatchSheet({MovieWatchEntry? entry}) async {
    final movieId = int.tryParse(widget.movieId);
    final authProvider = context.read<AuthProvider>();
    final movieService = context.read<MovieService>();
    final userId = authProvider.dbUser?.id;
    if (movieId == null || userId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RewatchLogSheet(
        initial: entry,
        onSubmit: ({
          required String watchedAt,
          required double? rating,
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
                  notes: notes,
                ),
              );
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
    (FriendActivityTab.reviews, 'Reviews'),
    (FriendActivityTab.lists, 'Lists'),
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    _buildMovieIntro(context, movie),
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                    _buildWhereToWatchSection(context),
                    const SizedBox(height: 24),
                    _buildSynopsis(context, movie),
                    const SizedBox(height: 24),
                    _buildFriendSummarySection(context),
                    const SizedBox(height: 24),
                    _buildFriendsActivitySection(context),
                    const SizedBox(height: 24),
                    _buildMovieDashboard(context, movie),
                    const SizedBox(height: 24),
                    _buildTrailersSection(context, movie),
                    const SizedBox(height: 24),
                    _buildTopCastSection(context),
                    const SizedBox(height: 24),
                    _buildUserReviewsSection(context),
                    const SizedBox(height: 24),
                    _buildMoreLikeThisSection(context),
                    const SizedBox(height: 24),
                    _buildYourListsSection(context),
                    const SizedBox(height: 16),
                    _buildFriendsListsSection(context),
                    const SizedBox(height: 24),
                    _buildWatchHistorySection(context),
                    const SizedBox(height: 24),
                    FilmInfoCard(
                      director: _director,
                      writers: _writers,
                      producers: _producers,
                      movie: movie,
                    ),
                    const SizedBox(height: 24),
                    ExternalLinksSection(movie: movie),
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

  // ---- Sliver app bar with hero image --------------------------------------

  Widget _buildSliverAppBar(BuildContext context, Movie movie) {
    final useBackdrop = MediaQuery.sizeOf(context).shortestSide >= 600;
    final preferredImage = useBackdrop ? movie.backdropPath : movie.posterPath;
    final fallbackImage = useBackdrop ? movie.posterPath : movie.backdropPath;
    final heroImagePath = preferredImage ?? fallbackImage;

    return SliverAppBar(
      expandedHeight: 430,
      pinned: false,
      backgroundColor: FlixieColors.background,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            MovieHeroBackdrop(
              imagePath: heroImagePath == null
                  ? null
                  : 'https://image.tmdb.org/t/p/w780$heroImagePath',
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.16, 0.66, 0.86, 1.0],
                  colors: [
                    Color(0x4A000000),
                    Color(0x00000000),
                    Color(0x00120A24),
                    Color(0x9A120A24),
                    FlixieColors.background,
                  ],
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _heroIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => context.pop(),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _heroIconButton(
                              icon: Icons.share_outlined,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Share is coming soon'),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            PopupMenuButton<String>(
                              tooltip: 'More actions',
                              padding: EdgeInsets.zero,
                              color: FlixieColors.tabBarBackgroundFocused,
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                color: FlixieColors.light,
                                size: 21,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Colors.black.withValues(alpha: 0.45),
                                minimumSize: const Size(46, 46),
                                shape: const CircleBorder(),
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
                                          color: FlixieColors.primary,
                                          size: 20),
                                      SizedBox(width: 8),
                                      Text('Log rewatch',
                                          style: TextStyle(
                                              color: FlixieColors.light)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'list',
                                  child: Row(
                                    children: [
                                      Icon(Icons.playlist_add_rounded,
                                          color: FlixieColors.secondary,
                                          size: 20),
                                      SizedBox(width: 8),
                                      Text('Add to list',
                                          style: TextStyle(
                                              color: FlixieColors.light)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'request',
                                  child: Row(
                                    children: [
                                      Icon(Icons.group_add_outlined,
                                          color: FlixieColors.primary,
                                          size: 20),
                                      SizedBox(width: 8),
                                      Text('Request to watch',
                                          style: TextStyle(
                                              color: FlixieColors.light)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    _buildHeroFlixScoreBadge(context, movie),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleBlock(context, movie),
        if ((movie.tagline ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildTaglineChip(movie.tagline ?? ''),
        ],
        const SizedBox(height: 12),
        _buildGenrePills(movie),
      ],
    );
  }

  // ---- Tagline chip --------------------------------------------------------

  Widget _buildTaglineChip(String tagline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: FlixieColors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: FlixieColors.secondary.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Text(
        tagline,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: FlixieColors.secondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ---- Title + meta --------------------------------------------------------

  Widget _buildTitleBlock(BuildContext context, Movie movie) {
    final year = _extractYear(movie.releaseDate);
    final runtime = _formatRuntime(movie.runtime);
    final rating = _contentRating(movie);
    final meta =
        [year, runtime, rating].where((s) => s.isNotEmpty).join('  •  ');
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 380 ? 34.0 : 38.0;

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
          const SizedBox(height: 6),
          Text(
            meta,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 16,
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
                hasScore
                    ? '${score.toStringAsFixed(1)}/10'
                    : 'No FlixScore yet',
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
                    color: FlixieColors.light,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Genre pills ---------------------------------------------------------

  Widget _buildGenrePills(Movie movie) {
    final genres = movie.genres;
    if (genres == null || genres.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: genres.asMap().entries.map((entry) {
        return GenreChip(
          label: entry.value.name.toUpperCase(),
          color: _kGenreChipColors[entry.key % _kGenreChipColors.length],
        );
      }).toList(),
    );
  }

  // ---- User Rating ----------------------------------------------------------

  Future<void> _setUserRating(int rating) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.dbUser;
    final movieId = int.tryParse(widget.movieId);
    if (user == null || movieId == null || _movie == null) return;

    setState(() => _isRatingLoading = true);
    try {
      final movieService = context.read<MovieService>();
      // Add rating and get updated vote average and count
      final response =
          await movieService.addMovieRating(movieId, user.id, rating);

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
    showModalBottomSheet<void>(
      context: context,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          color: FlixieColors.tabBarBackgroundFocused,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rate this movie',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a score from 1–10',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: FlixieColors.medium),
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
                    final isSelected = _userRating == rating;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _setUserRating(rating);
                      },
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
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Movie dashboard -----------------------------------------------------

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Overview'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                maxLines: _showFullSynopsis ? null : 5,
                overflow: _showFullSynopsis
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              if (showToggle)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _showFullSynopsis = !_showFullSynopsis),
                    style: TextButton.styleFrom(
                      foregroundColor: FlixieColors.primary,
                      padding: const EdgeInsets.only(top: 4),
                      minimumSize: Size.zero,
                    ),
                    child: Text(_showFullSynopsis ? 'Show less' : 'Show more'),
                  ),
                ),
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
    final primaryIcon =
        _isWatched ? Icons.replay_rounded : Icons.check_circle_outline_rounded;
    final primaryLabel = _isWatched ? 'Log rewatch' : 'Mark watched';
    final primaryAction = _isWatched ? _showLogWatchSheet : _toggleWatched;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FlixieColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _currentlyUpdating != null ? null : () => primaryAction(),
              icon: primaryIsLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(primaryIcon),
              label: Text(primaryLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: FlixieColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
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
              _statusDivider(),
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
              _statusDivider(),
              Expanded(
                child: _statusActionItem(
                  icon: Icons.star_rounded,
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
              _statusDivider(),
              Expanded(
                child: _statusActionItem(
                  icon: Icons.playlist_add_rounded,
                  label: 'List',
                  color: FlixieColors.secondary,
                  isActive: _myListsContainingMovie.isNotEmpty,
                  isLoading: _listsContainingMovieLoading,
                  onTap:
                      _currentlyUpdating != null ? null : _showAddToListSheet,
                ),
              ),
              _statusDivider(),
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
        ],
      ),
    );
  }

  Widget _statusDivider() {
    return Container(
      width: 1,
      height: 26,
      color: Colors.white.withValues(alpha: 0.1),
    );
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isActive
                        ? color.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? color.withValues(alpha: 0.32)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
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
                        : Icon(icon, size: 23, color: iconColor),
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  height: 14,
                  child: Text(
                    badge ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isActive ? color : Colors.transparent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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

    return FriendSummarySection(
      isLoading: _friendSummaryLoading,
      data: _friendSummary,
      error: _friendSummaryError,
      onRetry: movieId != null ? () => _loadFriendSummary(movieId) : null,
      recommendationLoading: _friendRecommendationLoading,
      recommendationData: _friendRecommendation,
      recommendationError: _friendRecommendationError,
      onRecommendationRetry:
          movieId != null ? () => _loadFriendRecommendation(movieId) : null,
      onSeeAllRecommendations: _friendRecommendation != null &&
              _friendRecommendation!.friends.where((f) => f.watched).length > 3
          ? () => _showAllFriendRecommendations(context)
          : null,
    );
  }

  // ---- Friends activity --------------------------------------------------

  Widget _buildFriendsActivitySection(BuildContext context) {
    final filtered = _filteredFriendsActivity();
    final yourActivityBadges = _buildYourActivityBadges();
    final showYourActivityFooter = yourActivityBadges.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Friends Activity'),
        const SizedBox(height: 12),
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (filtered.isEmpty)
                Text(
                  _friendsActivity.isEmpty
                      ? 'No friend activity yet for this movie.'
                      : _friendsActivityTab == FriendActivityTab.lists
                          ? 'Lists activity is coming soon.'
                          : 'No ${_friendTabLabel(_friendsActivityTab).toLowerCase()} activity yet.',
                  style: const TextStyle(color: FlixieColors.medium),
                )
              else
                Column(
                  children: filtered
                      .map((a) => FriendActivityRow(activity: a))
                      .toList(growable: false),
                ),
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
        ),
      ],
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
          return activity.reviewRecommended != null;
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
                        (list) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(list.name),
                          subtitle: Text('${list.movieCount ?? 0} films'),
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
                              (entry) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: FlixieColors.primary
                                      .withValues(alpha: 0.2),
                                  child: Text(
                                    (entry.friendName.isNotEmpty
                                            ? entry.friendName[0]
                                            : '?')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: FlixieColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: FlixieColors.white,
            fontWeight: FontWeight.bold,
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
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
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
    final streamProviders = _sortedProviders(
      _watchProviders.where((provider) => provider.isStreaming),
    );
    final purchaseProviders = _sortedProviders(
      _dedupeProviders(
        _watchProviders.where(
          (provider) => provider.isPurchase || provider.isRental,
        ),
      ),
    );
    final canStreamNow = streamProviders.any(
      (provider) => _userProviderIds.contains(provider.id),
    );
    final shouldShowPurchaseProviders =
        streamProviders.isEmpty || _showPurchaseProviders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWatchProviderHeader(
          hasPurchaseProviders:
              purchaseProviders.isNotEmpty && streamProviders.isNotEmpty,
          shouldShowPurchaseProviders: shouldShowPurchaseProviders,
        ),
        const SizedBox(height: 12),
        if (streamProviders.isNotEmpty)
          _buildProviderGroup(
            canStreamNow ? 'Streaming on your providers' : 'Streaming on',
            streamProviders,
            highlightUserProviders: true,
          )
        else
          const Text(
            'Not streaming on your region providers yet.',
            style: TextStyle(color: FlixieColors.medium, fontSize: 13),
          ),
        if (purchaseProviders.isNotEmpty && shouldShowPurchaseProviders) ...[
          const SizedBox(height: 10),
          _buildProviderGroup('Buy or rent', purchaseProviders),
        ],
      ],
    );
  }

  Widget _buildWatchProviderHeader({
    required bool hasPurchaseProviders,
    required bool shouldShowPurchaseProviders,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildSectionHeader(context, 'Where to Watch')),
        if (hasPurchaseProviders)
          TextButton.icon(
            onPressed: () {
              setState(
                () => _showPurchaseProviders = !_showPurchaseProviders,
              );
            },
            icon: Icon(
              shouldShowPurchaseProviders
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 18,
            ),
            label: Text(
              shouldShowPurchaseProviders ? 'Hide' : 'Buy or rent',
            ),
            style: TextButton.styleFrom(
              foregroundColor: FlixieColors.medium,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
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

  Widget _buildProviderGroup(
    String title,
    List<WatchProvider> providers, {
    bool highlightUserProviders = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: highlightUserProviders &&
                    providers.any(
                        (provider) => _userProviderIds.contains(provider.id))
                ? FlixieColors.success
                : FlixieColors.medium,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 94,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: providers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final provider = providers[i];
              final isUserProvider = _userProviderIds.contains(provider.id);
              return WatchProviderCard(
                provider: provider,
                isUserProvider: isUserProvider,
                showUserProviderHighlight: highlightUserProviders,
              );
            },
          ),
        ),
      ],
    );
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
            Text(
              'Top Cast',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: FlixieColors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () => _showAllCast(context),
              child: const Row(
                children: [
                  Text(
                    'See All',
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
        const SizedBox(height: 12),
        SizedBox(
          height: 194,
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

  void _showWriteReviewSheet(BuildContext context) {
    final user = context.read<AuthProvider>().dbUser;
    if (user == null) return;
    final movieId = int.tryParse(widget.movieId);
    if (movieId == null) return;

    showModalBottomSheet(
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
    const previewCount = 5;
    final preview = _reviews.take(previewCount).toList();
    final hasMore = _reviews.length > previewCount;
    final currentUserId = context.read<AuthProvider>().dbUser?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'User Reviews',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: FlixieColors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: FlixieColors.primary,
                side: const BorderSide(color: FlixieColors.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _showWriteReviewSheet(context),
              child: const Text(
                'Write Review',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
          if (hasMore)
            TextButton(
              onPressed: () => _showAllReviews(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View all ${_reviews.length} reviews',
                    style: const TextStyle(
                      color: FlixieColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: FlixieColors.primary, size: 18),
                ],
              ),
            ),
        ],
      ],
    );
  }

  // ---- More like this ------------------------------------------------------

  Widget _buildMoreLikeThisSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More Like This',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: FlixieColors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MovieCastMember> get _filteredCast {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.cast;
    return widget.cast.where((member) {
      return member.name.toLowerCase().contains(query) ||
          member.character.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCast;
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: FlixieColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: FlixieColors.medium.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 8, 10),
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
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${widget.cast.length} cast members',
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12,
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(color: FlixieColors.white),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search cast or character',
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
                  fillColor: FlixieColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
            Expanded(
              child: filtered.isEmpty
                  ? const _EmptyCastSearch()
                  : ListView.separated(
                      controller: scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
      color: FlixieColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          context.push('/people/${member.id}');
        },
        child: SizedBox(
          height: 104,
          child: Row(
            children: [
              SizedBox(
                width: 82,
                height: double.infinity,
                child: member.profileImage == null
                    ? const ColoredBox(
                        color: FlixieColors.surfaceElevated,
                        child: Icon(Icons.person_rounded,
                            color: FlixieColors.medium, size: 36),
                      )
                    : CachedNetworkImage(
                        imageUrl:
                            'https://image.tmdb.org/t/p/w185${member.profileImage}',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: FlixieColors.surfaceElevated,
                          child: Icon(Icons.person_rounded,
                              color: FlixieColors.medium, size: 36),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FlixieColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
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
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: FlixieColors.medium),
              const SizedBox(width: 10),
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
