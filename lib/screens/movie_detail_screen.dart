import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/favorite_movie.dart';
import '../models/movie.dart';
import '../models/movie_credits.dart';
import '../models/movie_friend_activity.dart';
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
import 'movie_detail/cast_card.dart';
import 'movie_detail/external_links_section.dart';
import 'movie_detail/film_info_card.dart';
import 'movie_detail/friend_activity_row.dart';
import 'movie_detail/genre_chip.dart';
import 'movie_detail/hero_backdrop.dart';
import 'movie_detail/action_button.dart';
import 'movie_detail/add_to_list_sheet.dart';
import 'movie_detail/rewatch_log_sheet.dart';
import 'movie_detail/review_card.dart';
import 'movie_detail/score_tile.dart';
import 'movie_detail/similar_card.dart';
import 'movie_detail/video_card.dart';
import 'movie_detail/watch_provider_card.dart';
import 'movie_detail/watch_request_sheet.dart';
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
  int _watchlistBounceKey = 0;
  int _watchedBounceKey = 0;
  int _favoriteBounceKey = 0;
  List<MovieFriendActivity> _friendsActivity = [];
  List<MovieWatchEntry> _movieWatchHistory = [];
  bool _watchHistoryLoading = false;
  FriendActivityTab _friendsActivityTab = FriendActivityTab.all;
  bool _showFullSynopsis = false;
  static const int _kPlaceholderWatchedPercent = 92;
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
      final futures = <Future>[
        movieService.getMovieById(id, userId: userId),
        movieService.getMovieRecommendations(id),
        movieService.getMovieCredits(id),
        movieService.getMovieWatchProviders(
            id, 'US'), // TODO: Get region from user profile
      ];
      if (userId != null) {
        futures.add(movieService.getUserMovieRating(id, userId));
        futures.add(movieService.getFriendsMovieActivity(id, userId));
      }
      final results = await Future.wait(futures);
      if (mounted) {
        setState(() {
          _movie = results[0] as Movie;
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
          _reviews = (_movie!.reviews ?? []).toList();

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
          _watchlistBounceKey++;
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
                backgroundColor: FlixieColors.tabBarBackgroundFocused,
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
          _watchedBounceKey++;
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
          _favoriteBounceKey++;
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
    final movieId = int.tryParse(widget.movieId);
    if (movieId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      builder: (_) => AddToListSheet(movieId: movieId),
    );
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
                    backgroundColor: FlixieColors.tabBarBackgroundFocused,
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

  static const List<(FriendActivityTab, String)> _friendActivityTabs = [
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

  Widget _inlineMetric({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: FlixieColors.light,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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

    final movie = _movie!;
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
                    const SizedBox(height: 10),
                    if (movie.tagline != null && movie.tagline!.isNotEmpty)
                      _buildTaglineChip(movie.tagline!),
                    const SizedBox(height: 12),
                    _buildTitleBlock(context, movie),
                    const SizedBox(height: 12),
                    _buildGenrePills(movie),
                    const SizedBox(height: 16),
                    _buildScores(context, movie),
                    const SizedBox(height: 12),
                    _buildActionButtons(),
                    const SizedBox(height: 16),
                    _buildPersonalActivitySection(context),
                    const SizedBox(height: 16),
                    _buildTrailersSection(context, movie),
                    const SizedBox(height: 24),
                    _buildWhereToWatchSection(context),
                    const SizedBox(height: 24),
                    _buildTopCastSection(context),
                    const SizedBox(height: 24),
                    _buildSynopsis(context, movie),
                    const SizedBox(height: 24),
                    _buildWatchHistorySection(context),
                    const SizedBox(height: 24),
                    _buildFriendsActivitySection(context),
                    const SizedBox(height: 24),
                    _buildFriendsRatingsSection(context),
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
      expandedHeight: 420,
      pinned: true,
      backgroundColor: FlixieColors.background,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: FlixieColors.light),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: FlixieColors.light),
          onPressed: () {
            // TODO(laura): wire native share flow for movie links.
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: MovieHeroBackdrop(
          imagePath: movie.backdropPath != null
              ? 'https://image.tmdb.org/t/p/w780${movie.backdropPath}'
              : (movie.posterPath != null
                  ? 'https://image.tmdb.org/t/p/w780${movie.posterPath}'
                  : null),
        ),
      ),
    );
  }

  // ---- Tagline chip --------------------------------------------------------

  Widget _buildTaglineChip(String tagline) {
    return GenreChip(label: tagline.toUpperCase());
  }

  // ---- Title + meta --------------------------------------------------------

  Widget _buildTitleBlock(BuildContext context, Movie movie) {
    final year = _extractYear(movie.releaseDate);
    final runtime = _formatRuntime(movie.runtime);
    final rating = _contentRating(movie);
    final meta = [year, runtime, rating].where((s) => s.isNotEmpty).join('  •  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          movie.title.toUpperCase(),
          style: const TextStyle(
            color: FlixieColors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            meta,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 13,
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
        final colors = [
          FlixieColors.primary,
          FlixieColors.secondary,
          FlixieColors.tertiary,
          FlixieColors.warning,
        ];
        return GenreChip(
          label: entry.value.name.toUpperCase(),
          color: colors[entry.key % colors.length],
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
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
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

  String _formatFlixScore(double score) {
    if (score > 8.1) {
      return '${score.toStringAsFixed(1)} 🔥';
    } else if (score > 7.0) {
      return '${score.toStringAsFixed(1)} 👍';
    } else if (score > 6.0) {
      return '${score.toStringAsFixed(1)} 😐';
    } else if (score > 5.0) {
      return '${score.toStringAsFixed(1)} 😕';
    } else if (score == 0) {
      return 'N/A';
    } else {
      return '${score.toStringAsFixed(1)} 👎';
    }
  }

  Widget _buildScores(BuildContext context, Movie movie) {
    final score = movie.voteAverage;
    final voteCount = movie.voteCount;
    final ratings = _friendsActivity
        .where((activity) => activity.rating != null)
        .map((activity) => activity.rating!.toDouble())
        .toList();
    final avgFriendScore = ratings.isEmpty
        ? null
        : ((ratings.reduce((a, b) => a + b) / ratings.length) * 10).round();
    final friendAvatars = _friendsActivity.take(3).toList();
    final watchedPercent =
        voteCount != null && voteCount > 0 ? _kPlaceholderWatchedPercent : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _inlineMetric(
                      icon: Icons.star_border_rounded,
                      iconColor: Colors.deepOrangeAccent,
                      label: 'FLIXIE SCORE',
                    ),
                    const SizedBox(height: 6),
                    ScoreTile(
                      value:
                          score != null ? '${score.toStringAsFixed(1)}/10' : 'N/A',
                      label: voteCount != null
                          ? '${_formatVoteCount(voteCount)} RATINGS'
                          : 'NO RATINGS',
                      valueColor: FlixieColors.white,
                      onInfoTap: () => _showFlixScoreInfo(context),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _isRatingLoading ? null : _showRatingSheet,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userRating != null ? '${_userRating!}/10' : '+ Rate',
                          style: TextStyle(
                            color: _userRating != null
                                ? FlixieColors.tertiary
                                : FlixieColors.light,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'YOUR RATING',
                          style: TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                        if (watchedPercent != null)
                          Text(
                            '$watchedPercent% watched',
                            style: const TextStyle(
                              color: FlixieColors.primary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (avgFriendScore != null || friendAvatars.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: FlixieColors.tabBarBorder, height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.people_alt_outlined,
                    size: 16, color: FlixieColors.secondary),
                const SizedBox(width: 6),
                Text(
                  avgFriendScore != null
                      ? 'Avg Friend Score: $avgFriendScore%'
                      : 'Friends Activity',
                  style: const TextStyle(
                    color: FlixieColors.light,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (friendAvatars.isNotEmpty)
                  SizedBox(
                    width: 74,
                    child: Stack(
                      children: List.generate(friendAvatars.length, (index) {
                        final friend = friendAvatars[index];
                        final initial = friend.username.isNotEmpty
                            ? friend.username[0].toUpperCase()
                            : '?';
                        return Positioned(
                          left: index * 18,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor:
                                FlixieColors.surfaceElevated.withValues(alpha: 0.95),
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: FlixieColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWatchSummaryCard(BuildContext context) {
    final recentWatch = _movieWatchHistory.isNotEmpty ? _movieWatchHistory.first : null;
    final hasHistory = recentWatch != null;
    final watchCount = _watchCount;
    final ratingLabel = _userRating != null ? '${_userRating!}/10' : 'Not rated';
    final watchDate = hasHistory ? _formatReadableDate(recentWatch.watchedAt) : 'Not watched yet';

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
              Text(
                hasHistory ? "You've watched this movie" : 'Track this movie',
                style: const TextStyle(
                  color: FlixieColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (watchCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          Row(
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
              const SizedBox(width: 12),
              SizedBox(
                width: 132,
                child: OutlinedButton.icon(
                  onPressed: _isWatched ? () => _showLogWatchSheet() : null,
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Rewatch'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FlixieColors.primary,
                    side: BorderSide(
                      color: _isWatched
                          ? FlixieColors.primary
                          : FlixieColors.medium.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ],
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
        backgroundColor: FlixieColors.surface,
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
      backgroundColor: FlixieColors.surface,
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FlixieColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: MovieActionButton(
              icon:
                  _isWatched ? Icons.check_circle : Icons.check_circle_outline,
              label: 'Watched',
              isActive: _isWatched,
              color: FlixieColors.success,
              isLoading: _currentlyUpdating == ListUpdateType.watched,
              bounceKey: _watchedBounceKey,
              onPressed: _currentlyUpdating != null ? null : _toggleWatched,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MovieActionButton(
              icon: _inWatchlist ? Icons.bookmark : Icons.bookmark_outline,
              label: 'Watchlist',
              isActive: _inWatchlist,
              color: FlixieColors.warning,
              isLoading: _currentlyUpdating == ListUpdateType.watchlist,
              bounceKey: _watchlistBounceKey,
              onPressed: _currentlyUpdating != null ? null : _toggleWatchlist,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MovieActionButton(
              icon: _isFavorite ? Icons.favorite : Icons.favorite_outline,
              label: 'Favourite',
              isActive: _isFavorite,
              color: FlixieColors.danger,
              isLoading: _currentlyUpdating == ListUpdateType.favorite,
              bounceKey: _favoriteBounceKey,
              onPressed: _currentlyUpdating != null ? null : _toggleFavorite,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MovieActionButton(
              icon: Icons.replay_rounded,
              label: 'Rewatch',
              subtitle: _watchCount > 0 ? '$_watchCount times' : null,
              isActive: _isWatched,
              color: FlixieColors.primary,
              isLoading: false,
              bounceKey: _watchCount,
              onPressed: _isWatched ? _showLogWatchSheet : null,
            ),
          ),
        ],
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: ListTile(
                    title: Text(_formatWatchDate(entry.watchedAt)),
                    subtitle: Text(
                      [
                        if (entry.rating != null)
                          'Rating: ${entry.rating!.toStringAsFixed(0)}/10',
                        if (entry.notes != null && entry.notes!.isNotEmpty)
                          entry.notes!,
                      ].join(' • '),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showLogWatchSheet(entry: entry);
                          return;
                        }
                        _deleteWatchEntry(entry);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
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

  Widget _buildPersonalActivitySection(BuildContext context) {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final myReview =
        userId == null ? null : _reviews.where((r) => r.userId == userId).firstOrNull;
    final lastWatch = _movieWatchHistory.isNotEmpty ? _movieWatchHistory.first : null;
    final hasAnyActivity = lastWatch != null || _userRating != null || myReview != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR ACTIVITY',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: FlixieColors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasAnyActivity)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _activityColumn(
                        title: 'Watch count',
                        value: '$_watchCount',
                        icon: Icons.replay_circle_filled_rounded,
                        color: FlixieColors.primary,
                      ),
                    ),
                    _verticalDivider(),
                    Expanded(
                      child: _activityColumn(
                        title: 'Your rating',
                        value: _userRating != null ? '${_userRating!}/10' : '—',
                        icon: Icons.star_rounded,
                        color: FlixieColors.warning,
                      ),
                    ),
                    _verticalDivider(),
                    Expanded(
                      child: _activityColumn(
                        title: 'Last watched',
                        value: lastWatch != null
                            ? _formatReadableDate(lastWatch.watchedAt)
                            : '—',
                        icon: Icons.check_circle_outline,
                        color: FlixieColors.success,
                      ),
                    ),
                  ],
                )
              else
                const Text(
                  'No personal activity yet for this movie.',
                  style: TextStyle(color: FlixieColors.medium),
                ),
              const SizedBox(height: 12),
              if (myReview?.body.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    myReview?.body ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.light,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isWatched ? _showLogWatchSheet : _toggleWatched,
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Rewatch & Update Rating'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FlixieColors.primary,
                    side: BorderSide(
                      color: FlixieColors.primary.withValues(alpha: 0.7),
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

  Widget _activityColumn({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    int maxLines = 2,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                title,
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.white,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 78,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  // ---- Friends activity --------------------------------------------------

  Widget _buildFriendsActivitySection(BuildContext context) {
    final filtered = _filteredFriendsActivity();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Friends Activity'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _friendActivityTabs.map((tab) {
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
                        color:
                            selected ? FlixieColors.primary : FlixieColors.light,
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
          child: filtered.isEmpty
              ? Text(
                  _friendsActivity.isEmpty
                      ? 'No friend activity yet for this movie.'
                      : _friendsActivityTab == FriendActivityTab.lists
                          ? 'Lists activity is coming soon.'
                      : 'No ${_friendsActivityTab.name} activity yet.',
                  style: const TextStyle(color: FlixieColors.medium),
                )
              : Column(
                  children: filtered
                      .map((a) => FriendActivityRow(activity: a))
                      .toList(growable: false),
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

  Widget _buildFriendsRatingsSection(BuildContext context) {
    final ratings = _friendsActivity
        .where((activity) => activity.rating != null)
        .map((activity) => activity.rating!)
        .toList();
    final average = ratings.isEmpty
        ? null
        : ratings.reduce((a, b) => a + b) / ratings.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Friends Ratings'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ratings.isEmpty
              ? const Text(
                  'No friend ratings yet.',
                  style: TextStyle(color: FlixieColors.medium),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average friend rating: ${average?.toStringAsFixed(1) ?? '0.0'}/10',
                      style: const TextStyle(
                        color: FlixieColors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _friendsActivity
                          .where((a) => a.rating != null)
                          .take(6)
                          .map(
                            (a) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: FlixieColors.surfaceElevated
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${a.username}: ${a.rating}/10',
                                style: const TextStyle(
                                  color: FlixieColors.light,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFriendsListsSection(BuildContext context) {
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
          child: const Text(
            'Friends list activity is not available for this movie yet.',
            style: TextStyle(color: FlixieColors.medium),
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
