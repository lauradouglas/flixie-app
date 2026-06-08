import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/favorite_movie.dart';
import '../models/friend_recommendation.dart';
import '../models/movie.dart';
import '../models/movie_credits.dart';
import '../models/movie_friend_activity.dart';
import '../models/movie_friend_list_entry.dart';
import '../models/movie_list.dart';
import '../models/movie_watch_entry.dart';
import '../models/review.dart';
import '../models/similar_movie.dart';
import '../models/watch_provider.dart';
import '../models/watched_movie.dart';
import '../models/watchlist_movie.dart';
import '../providers/auth_provider.dart';
import '../services/movie_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../models/friend_summary.dart';
import 'movie_detail/cast_card.dart';
import 'movie_detail/friend_summary_section.dart';
import 'movie_detail/external_links_section.dart';
import 'movie_detail/film_info_card.dart';
import 'movie_detail/friend_activity_row.dart';
import 'movie_detail/genre_chip.dart';
import 'movie_detail/hero_backdrop.dart';
import 'movie_detail/add_to_list_sheet.dart';
import 'movie_detail/rewatch_log_sheet.dart';
import 'movie_detail/review_card.dart';
import 'movie_detail/similar_card.dart';
import 'movie_detail/video_card.dart';
import 'movie_detail/watch_provider_card.dart';
import 'movie_detail/watch_request_sheet.dart';
import 'movie_detail/should_i_watch_this_card.dart';
import 'movie_detail/write_review_sheet.dart';

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
          _reviews = (loadedMovie.reviews ?? []).toList();

          // Check movie status in user's lists
          final user = authProvider.dbUser;
          if (user != null) {
            _inWatchlist = user.isMovieInWatchlist(id);
            _isWatched = user.isMovieWatched(id);
            _isFavorite = user.isMovieFavorite(id);
          }
          // Load existing user rating from API
          if (userId != null && results.length > 4) {
            _userRating = results[4] as int?;
            _friendsActivity = results[5] as List<MovieFriendActivity>? ?? [];
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
      final history = await UserService.getMovieWatchHistory(userId, movieId);
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
        UserService.getMyListsContainingMovie(userId, movieId),
        UserService.getFriendsListsContainingMovie(userId, movieId),
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
          ? UserService.removeFromWatchlist(user.id, movieId)
          : UserService.addToWatchlist(user.id, movieId));

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
              final watchedResult =
                  await UserService.addToWatched(user.id, movieId);
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
      await UserService.removeFromWatched(user.id, movieId);

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
        await UserService.removeFromFavorites(user.id, movieId);
        addedFavorite = null;
      } else {
        addedFavorite = await UserService.addToFavorites(user.id, movieId);
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
    final userId = context.read<AuthProvider>().dbUser?.id;
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
              await UserService.logMovieWatch(
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
              final watchedResult =
                  await UserService.addToWatched(userId, movieId);
              final authProvider = context.read<AuthProvider>();
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
                  await UserService.removeFromWatchlist(userId, movieId);
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
              await UserService.updateMovieWatch(
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
            final movieService = context.read<MovieService>();
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
      await UserService.deleteMovieWatch(userId, entry.id);
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
                    const SizedBox(height: 12),
                    _buildScores(context, movie),
                    const SizedBox(height: 12),
                    _buildWatchSummaryCard(context),
                    const SizedBox(height: 12),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                    _buildSynopsis(context, movie),
                    const SizedBox(height: 24),
                    _buildWhereToWatchSection(context),
                    const SizedBox(height: 24),
                    _buildYourListsSection(context),
                    const SizedBox(height: 16),
                    _buildTrailersSection(context, movie),
                    const SizedBox(height: 24),
                    _buildTopCastSection(context),
                    const SizedBox(height: 24),
                    _buildWatchHistorySection(context),
                    const SizedBox(height: 24),
                    _buildShouldIWatchThisSection(context),
                    const SizedBox(height: 24),
                    _buildFriendSummarySection(context),
                    const SizedBox(height: 24),
                    _buildFriendsActivitySection(context),
                    const SizedBox(height: 24),
                    _buildFriendsListsSection(context),
                    const SizedBox(height: 24),
                    _buildUserReviewsSection(context),
                    const SizedBox(height: 24),
                    _buildMoreLikeThisSection(context),
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
    return SliverAppBar(
      expandedHeight: 560,
      pinned: false,
      backgroundColor: FlixieColors.background,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            MovieHeroBackdrop(
              imagePath: movie.backdropPath != null
                  ? 'https://image.tmdb.org/t/p/w780${movie.backdropPath}'
                  : (movie.posterPath != null
                      ? 'https://image.tmdb.org/t/p/w780${movie.posterPath}'
                      : null),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.12, 0.5, 0.72, 0.9, 1.0],
                  colors: [
                    Color(0x4A000000),
                    Color(0x14000000),
                    Color(0x00000000),
                    Color(0x730F0921),
                    Color(0xD9120A24),
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
                    _buildTitleBlock(context, movie),
                    const SizedBox(height: 12),
                    if ((movie.tagline ?? '').isNotEmpty) ...[
                      _buildTaglineChip(movie.tagline ?? ''),
                      const SizedBox(height: 8),
                    ],
                    _buildGenrePills(movie),
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
        tagline.toUpperCase(),
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
    final titleSize = width < 380 ? 40.0 : 44.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          movie.title.toUpperCase(),
          style: TextStyle(
            color: FlixieColors.white,
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            height: 1.0,
            letterSpacing: 0.1,
            shadows: const [
              Shadow(
                color: Color(0xC0000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
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
              shadows: [
                Shadow(
                  color: Color(0xAA000000),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ],
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

  // ---- Score row -----------------------------------------------------------

  Widget _buildScores(BuildContext context, Movie movie) {
    final score = movie.voteAverage;
    final voteCount = movie.voteCount ?? 0;
    final hasCommunityRatings = voteCount > 0 && score != null && score > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      child: Row(
        children: [
          Expanded(
            child: _scoreMetric(
              value: hasCommunityRatings
                  ? '${score.toStringAsFixed(1)}/10'
                  : '- /10',
              label: 'FLIXISCORE',
              valueColor: FlixieColors.white,
              leadingIcon: Icons.star_border_rounded,
              leadingColor: Colors.deepOrangeAccent,
              showInfo: true,
              onTap: () => _showFlixScoreInfo(context),
            ),
          ),
          _scoreDivider(),
          Expanded(
            child: _scoreMetric(
              value: _formatVoteCount(voteCount),
              label: 'RATINGS',
              valueColor: FlixieColors.tertiary,
              showInfo: true,
              onTap: () => _showFlixScoreInfo(context),
            ),
          ),
          _scoreDivider(),
          Expanded(
            child: _scoreMetric(
              value: _userRating != null ? '${_userRating!}/10' : '+ Rate',
              label: 'YOUR RATING',
              valueColor: _userRating != null
                  ? FlixieColors.light
                  : FlixieColors.medium,
              alignEnd: true,
              onTap: _isRatingLoading ? null : _showRatingSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreDivider() {
    return Container(
      width: 1,
      height: 56,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _scoreMetric({
    required String value,
    required String label,
    required Color valueColor,
    VoidCallback? onTap,
    IconData? leadingIcon,
    Color? leadingColor,
    bool showInfo = false,
    bool alignEnd = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment:
              alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, size: 18, color: leadingColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                if (showInfo) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.info_outline,
                    size: 12,
                    color: FlixieColors.medium,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchSummaryCard(BuildContext context) {
    final recentWatch =
        _movieWatchHistory.isNotEmpty ? _movieWatchHistory.first : null;
    final hasHistory = recentWatch != null;
    final watchCount = _watchCount;
    final ratingLabel =
        _userRating != null ? '${_userRating!}/10' : 'Not rated';
    final watchDate = hasHistory
        ? _formatReadableDate(recentWatch.watchedAt)
        : 'Not watched yet';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasHistory ? "You've watched this movie" : 'Track this movie',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlixieColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (watchCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: FlixieColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$watchCount ${watchCount == 1 ? 'TIME' : 'TIMES'}',
                    style: const TextStyle(
                      color: FlixieColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;

              final summaryRow = Row(
                children: [
                  Expanded(
                    child: _watchSummaryItem(
                      title: 'Your rating',
                      value: ratingLabel,
                      icon: Icons.star_rounded,
                      iconColor: Colors.orangeAccent,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 52,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  Expanded(
                    child: _watchSummaryItem(
                      title: 'Last watched',
                      value: watchDate,
                      icon: Icons.schedule_rounded,
                      iconColor: FlixieColors.light,
                    ),
                  ),
                ],
              );

              final rewatchButton = OutlinedButton.icon(
                onPressed: _isWatched ? () => _showLogWatchSheet() : null,
                icon: const Icon(Icons.replay_rounded, size: 16),
                label: const Text('Rewatch'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FlixieColors.primary,
                  side: BorderSide(
                    color: _isWatched
                        ? FlixieColors.primary
                        : FlixieColors.medium.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
              );

              if (compact) {
                return Column(
                  children: [
                    summaryRow,
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: rewatchButton),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: summaryRow),
                  const SizedBox(width: 8),
                  SizedBox(width: 116, child: rewatchButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _watchSummaryItem({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: FlixieColors.medium,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlixieColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
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
    final showToggle = text.length > 160;

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
                maxLines: _showFullSynopsis ? null : 3,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: FlixieColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statusActionItem(
              icon:
                  _isWatched ? Icons.check_circle : Icons.check_circle_outline,
              label: 'Watched',
              color: FlixieColors.success,
              isActive: _isWatched,
              isLoading: _currentlyUpdating == ListUpdateType.watched,
              onTap: _currentlyUpdating != null ? null : _toggleWatched,
            ),
          ),
          _statusDivider(),
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
    required Color color,
    required bool isActive,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    final iconColor = isActive ? color : FlixieColors.medium;
    final labelColor = isActive
        ? FlixieColors.light
        : FlixieColors.medium.withValues(alpha: 0.95);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 120;
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: compact ? 8 : 10,
            ),
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoading)
                        SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(iconColor),
                          ),
                        )
                      else
                        Icon(icon, size: 20, color: iconColor),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLoading)
                        SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(iconColor),
                          ),
                        )
                      else
                        Icon(icon, size: 22, color: iconColor),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
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

  // ---- Should I Watch This? -----------------------------------------------

  Widget _buildShouldIWatchThisSection(BuildContext context) {
    // Only shown when the user is logged in (we need friend data).
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return const SizedBox.shrink();

    final movieId = int.tryParse(widget.movieId);

    return ShouldIWatchThisCard(
      isLoading: _friendRecommendationLoading,
      data: _friendRecommendation,
      error: _friendRecommendationError,
      onRetry:
          movieId != null ? () => _loadFriendRecommendation(movieId) : null,
      onSeeAll: _friendRecommendation != null &&
              _friendRecommendation!.friends.where((f) => f.watched).length > 3
          ? () => _showAllFriendRecommendations(context)
          : null,
    );
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
                  final name = f.displayName ?? f.username;
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
        label: 'In favorites',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Where to Watch'),
        const SizedBox(height: 4),
        const Text(
          'Provider availability only',
          style: TextStyle(color: FlixieColors.medium, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _watchProviders.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                WatchProviderCard(provider: _watchProviders[i]),
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
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: FlixieColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlixieColors.medium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Full Cast (${_cast.length})',
                      style: const TextStyle(
                        color: FlixieColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: FlixieColors.light),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: FlixieColors.tabBarBorder, height: 1),
              // Cast list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _cast.length,
                  itemBuilder: (context, index) {
                    final member = _cast[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FlixieColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Profile image
                          Container(
                            width: 60,
                            height: 80,
                            decoration: BoxDecoration(
                              color: FlixieColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: member.profileImage != null
                                ? CachedNetworkImage(
                                    imageUrl:
                                        'https://image.tmdb.org/t/p/w185${member.profileImage}',
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.person,
                                      color: FlixieColors.medium,
                                      size: 32,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    color: FlixieColors.medium,
                                    size: 32,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          // Name and character
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.name,
                                  style: const TextStyle(
                                    color: FlixieColors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  member.character,
                                  style: const TextStyle(
                                    color: FlixieColors.medium,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
          height: 170,
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
          setState(() => _reviews = [review, ..._reviews]);
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
