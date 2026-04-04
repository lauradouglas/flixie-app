import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/movie.dart';
import '../models/movie_credits.dart';
import '../models/movie_friend_activity.dart';
import '../models/friendship.dart';
import '../models/review.dart';
import '../models/similar_movie.dart';
import '../models/watch_provider.dart';
import '../providers/auth_provider.dart';
import '../services/movie_service.dart';
import '../services/request_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import 'movie_detail/cast_card.dart';
import 'movie_detail/genre_chip.dart';
import 'movie_detail/hero_backdrop.dart';
import 'movie_detail/review_card.dart';
import 'movie_detail/score_tile.dart';
import 'movie_detail/similar_card.dart';
import 'movie_detail/video_card.dart';
import 'movie_detail/watch_provider_card.dart';

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

  // ---- Data loading ---------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _refresh() async {
    final id = int.tryParse(widget.movieId);
    if (id != null) MovieService.evictMovie(id);
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
      final futures = <Future>[
        MovieService.getMovieById(id, userId: userId),
        MovieService.getMovieRecommendations(id),
        MovieService.getMovieCredits(id),
        MovieService.getMovieWatchProviders(
            id, 'US'), // TODO: Get region from user profile
      ];
      if (userId != null) {
        futures.add(MovieService.getUserMovieRating(id, userId));
        futures.add(MovieService.getFriendsMovieActivity(id, userId));
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

        // Keep all existing Map entries (so WatchlistScreen can parse them),
        // then append or remove the affected entry.
        final currentWatchlist = List<dynamic>.from(user.movieWatchlist ?? []);

        if (_inWatchlist) {
          // Added — append the full Map returned by the API
          currentWatchlist.removeWhere((item) {
            if (item is Map<String, dynamic>) {
              return (item['movieId'] ?? item['id']) == movieId;
            }
            return item == movieId;
          });
          currentWatchlist.add(result.toJson());
          authProvider.markActivityChanged();
        } else {
          // Removed — strip out the entry
          currentWatchlist.removeWhere((item) {
            if (item is Map<String, dynamic>) {
              return (item['movieId'] ?? item['id']) == movieId;
            }
            return item == movieId;
          });
        }
        authProvider.updateUserList(movieWatchlist: currentWatchlist);
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

    setState(() => _currentlyUpdating = ListUpdateType.watched);

    try {
      await (_isWatched
          ? UserService.removeFromWatched(user.id, movieId)
          : UserService.addToWatched(user.id, movieId));

      // Successfully updated on server, toggle UI state and update user list
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _isWatched = !_isWatched;
          _currentlyUpdating = null;
          _watchedBounceKey++;
        });

        final currentWatched = user.watchedMovies ?? [];
        final updatedWatched = <int>[];

        try {
          for (var item in currentWatched) {
            if (item is int) {
              updatedWatched.add(item);
            } else if (item is Map<String, dynamic>) {
              final id = item['movieId'] ?? item['id'];
              if (id is int) {
                updatedWatched.add(id);
              }
            }
          }
        } catch (e) {
          logger.w('Error processing watched list: $e');
          logger.d('currentWatched type: ${currentWatched.runtimeType}');
          logger.d('currentWatched: $currentWatched');
        }

        if (_isWatched) {
          if (!updatedWatched.contains(movieId)) {
            updatedWatched.add(movieId);
          }
          authProvider.markActivityChanged();
        } else {
          updatedWatched.remove(movieId);
        }
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
      await (_isFavorite
          ? UserService.removeFromFavorites(user.id, movieId)
          : UserService.addToFavorites(user.id, movieId));

      // Successfully updated on server, toggle UI state and update user list
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _isFavorite = !_isFavorite;
          _currentlyUpdating = null;
          _favoriteBounceKey++;
        });

        final currentFavorites = user.favoriteMovies ?? [];
        final updatedFavorites = <int>[];

        for (var item in currentFavorites) {
          try {
            int? movieIdToAdd;

            if (item is int) {
              movieIdToAdd = item;
            } else if (item is Map) {
              final map = item;
              movieIdToAdd = map['movieId'] as int?;
              movieIdToAdd ??= map['id'] as int?;
            }

            if (movieIdToAdd != null) {
              updatedFavorites.add(movieIdToAdd);
            }
          } catch (e) {
            logger.w('Skipping problematic item in favorites: $e');
            logger.d('Item type: ${item.runtimeType}');
            logger.d('Item value: $item');
          }
        }

        if (_isFavorite) {
          if (!updatedFavorites.contains(movieId)) {
            updatedFavorites.add(movieId);
          }
          authProvider.markActivityChanged();
        } else {
          updatedFavorites.remove(movieId);
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

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1B2A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1B2A),
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
      backgroundColor: const Color(0xFF0D1B2A),
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
                    const SizedBox(height: 16),
                    if (movie.tagline != null && movie.tagline!.isNotEmpty)
                      _buildTaglineChip(movie.tagline!),
                    const SizedBox(height: 12),
                    _buildTitleBlock(context, movie),
                    const SizedBox(height: 12),
                    _buildGenrePills(movie),
                    const SizedBox(height: 16),
                    _buildScores(context, movie),
                    const Divider(height: 32, color: Color(0xFF1E2D40)),
                    _buildSynopsis(context, movie),
                    const SizedBox(height: 16),
                    _buildFilmInfoCard(movie),
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                    const SizedBox(height: 28),
                    _buildFriendsActivitySection(context),
                    const SizedBox(height: 28),
                    _buildTrailersSection(context, movie),
                    const SizedBox(height: 28),
                    _buildWhereToWatchSection(context),
                    const SizedBox(height: 28),
                    _buildTopCastSection(context),
                    const SizedBox(height: 28),
                    _buildUserReviewsSection(context),
                    const SizedBox(height: 28),
                    _buildExternalLinksSection(context, movie),
                    const SizedBox(height: 28),
                    _buildMoreLikeThisSection(context),
                    const SizedBox(height: 32),
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
      expandedHeight: 450,
      pinned: true,
      backgroundColor: const Color(0xFF0D1B2A),
      title: const Text(
        'FLIXIE',
        style: TextStyle(
          color: FlixieColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 2,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: FlixieColors.light),
          onPressed: () => context.go('/search'),
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: FlixieColors.light),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: MovieHeroBackdrop(
          imagePath: movie.backdropPath != null
              ? 'https://image.tmdb.org/t/p/w780${movie.posterPath}'
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
    final meta = [year, runtime].where((s) => s.isNotEmpty).join('  •  ');

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
              color: FlixieColors.medium,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  // ---- Genre pills ---------------------------------------------------------

  Widget _buildGenrePills(Movie movie) {
    if (movie.genres == null || movie.genres!.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF10B981), // Green
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEF4444), // Red
      const Color(0xFF14B8A6), // Teal
    ];

    final random = Random();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: movie.genres!
          .map((genre) => GenreChip(
                label: genre.name.toUpperCase(),
                color: colors[random.nextInt(colors.length)],
              ))
          .toList(),
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
      // Add rating and get updated vote average and count
      final response =
          await MovieService.addMovieRating(movieId, user.id, rating);

      // Extract updated vote data from response (safely parse types)
      final newVoteAverage = _parseDouble(response['voteAverage']);
      final newVoteCount = _parseInt(response['voteCount']);

      // Update the movie with new vote data
      final updatedMovie = _movie!.copyWith(
        voteAverage: newVoteAverage,
        voteCount: newVoteCount,
      );

      // Update cache with the new movie data
      MovieService.updateCachedMovie(updatedMovie);

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
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

    return Row(
      children: [
        if (score != null)
          ScoreTile(
            value: _formatFlixScore(score),
            label: 'FLIXSCORE',
            onInfoTap: () => _showFlixScoreInfo(context),
          ),
        if (score != null && voteCount != null) const SizedBox(width: 28),
        if (voteCount != null)
          ScoreTile(
            value: _formatVoteCount(voteCount),
            valueColor: FlixieColors.success,
            label: 'RATING(S)',
          ),
        const Spacer(),
        GestureDetector(
          onTap: _isRatingLoading ? null : _showRatingSheet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isRatingLoading)
                const SizedBox(
                  height: 26,
                  width: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: FlixieColors.tertiary,
                  ),
                )
              else
                Text(
                  _userRating != null ? '$_userRating /10' : '+ Rate',
                  style: TextStyle(
                    color: _userRating != null
                        ? FlixieColors.tertiary
                        : FlixieColors.medium,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 2),
              const Text(
                'YOUR RATING',
                style: TextStyle(
                  color: FlixieColors.medium,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFlixScoreInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B2E42),
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
              '👍 7.0-8.1 · Liked\n'
              '😐 6.0-7.0 · Mixed\n'
              '😕 5.0-6.0 · Meh\n'
              '👎 Below 5.0 · Disliked\n'
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

  // ---- Film info card (director / writers / budget) -----------------------

  Widget _buildFilmInfoCard(Movie movie) {
    final hasProducers = _producers.isNotEmpty;
    final hasDirector = _director != null;
    final hasWriters = _writers.isNotEmpty;
    final hasBudget = movie.budget != null && movie.budget! > 0;
    final hasCollection =
        movie.collection != null && movie.collection!['name'] != null;

    if (!hasProducers &&
        !hasDirector &&
        !hasWriters &&
        !hasBudget &&
        !hasCollection) {
      return const SizedBox.shrink();
    }

    Widget row(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: FlixieColors.medium,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    const divider = Column(
      children: [
        SizedBox(height: 12),
        Divider(color: Color(0xFF1E2D40), thickness: 1, height: 1),
        SizedBox(height: 12),
      ],
    );

    String formatBudget(int amount) {
      if (amount >= 1000000) {
        final m = amount / 1000000;
        return '\$${m % 1 == 0 ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}M';
      }
      if (amount >= 1000) {
        return '\$${(amount / 1000).toStringAsFixed(0)}K';
      }
      return '\$$amount';
    }

    final rows = <Widget>[];
    if (hasDirector) rows.add(row('Director', _director!));
    if (hasWriters) {
      if (rows.isNotEmpty) rows.add(divider);
      rows.add(row(
          _writers.length == 1 ? 'Writer' : 'Writers', _writers.join(', ')));
    }
    if (hasBudget) {
      if (rows.isNotEmpty) rows.add(divider);
      rows.add(row('Budget', formatBudget(movie.budget!)));
    }
    if (hasProducers) {
      if (rows.isNotEmpty) rows.add(divider);
      rows.add(row(_producers.length == 1 ? 'Producer' : 'Producers',
          _producers.join(', ')));
    }
    if (hasCollection) {
      if (rows.isNotEmpty) rows.add(divider);
      rows.add(row('Collection', movie.collection!['name'] as String));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2D40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  // ---- Synopsis ------------------------------------------------------------

  Widget _buildSynopsis(BuildContext context, Movie movie) {
    final text = movie.overview;
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Synopsis',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: FlixieColors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          text,
          style: const TextStyle(
            color: FlixieColors.light,
            fontSize: 14,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  // ---- Watch request -------------------------------------------------------

  void _showWatchRequestSheet() {
    final auth = context.read<AuthProvider>();
    final friends = auth.cachedFriends?.friendships ?? [];

    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add some friends to invite them to watch')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B2E42),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WatchRequestSheet(
        movieId: int.tryParse(widget.movieId),
        movieTitle: _movie?.title,
        requesterId: auth.dbUser?.id,
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: _isWatched
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                label: 'Watched',
                isActive: _isWatched,
                color: Colors.green,
                isLoading: _currentlyUpdating == ListUpdateType.watched,
                bounceKey: _watchedBounceKey,
                onPressed: _currentlyUpdating != null ? null : _toggleWatched,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                icon: _inWatchlist ? Icons.bookmark : Icons.bookmark_outline,
                label: 'Watchlist',
                isActive: _inWatchlist,
                color: Colors.amber,
                isLoading: _currentlyUpdating == ListUpdateType.watchlist,
                bounceKey: _watchlistBounceKey,
                onPressed: _currentlyUpdating != null ? null : _toggleWatchlist,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                icon: _isFavorite ? Icons.favorite : Icons.favorite_outline,
                label: 'Favourite',
                isActive: _isFavorite,
                color: Colors.red,
                isLoading: _currentlyUpdating == ListUpdateType.favorite,
                bounceKey: _favoriteBounceKey,
                onPressed: _currentlyUpdating != null ? null : _toggleFavorite,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.group_add_outlined, size: 18),
            label: const Text('Invite to Watch'),
            style: OutlinedButton.styleFrom(
              foregroundColor: FlixieColors.secondary,
              side: const BorderSide(color: FlixieColors.secondary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _showWatchRequestSheet,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color color,
    required bool isLoading,
    required int bounceKey,
    required VoidCallback? onPressed,
  }) {
    final buttonColor = isActive ? color : Colors.grey;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isActive ? color : Colors.grey.withOpacity(0.5),
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: isLoading
                ? CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(buttonColor),
                  )
                : TweenAnimationBuilder<double>(
                    key: ValueKey<String>('$icon-$bounceKey'),
                    duration: const Duration(milliseconds: 500),
                    tween: Tween<double>(begin: 1.4, end: 1.0),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: child,
                            );
                          },
                          child: Icon(
                            icon,
                            key: ValueKey<IconData>(icon),
                            size: 24,
                            color: buttonColor,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: buttonColor,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Friends activity --------------------------------------------------

  Widget _buildFriendsActivitySection(BuildContext context) {
    if (_friendsActivity.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Friends',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: FlixieColors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ..._friendsActivity.map((a) => _FriendActivityRow(activity: a)),
      ],
    );
  }

  // ---- Trailers -----------------------------------------------------------

  Widget _buildTrailersSection(BuildContext context, Movie movie) {
    final videos = movie.videos;
    if (videos == null || videos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trailers',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: FlixieColors.white,
                fontWeight: FontWeight.bold,
              ),
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

  // ---- Where to watch ------------------------------------------------------

  Widget _buildWhereToWatchSection(BuildContext context) {
    if (_watchProviders.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where to Watch',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: FlixieColors.white,
                fontWeight: FontWeight.bold,
              ),
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
            color: Color(0xFF0D1B2A),
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
              const Divider(color: Color(0xFF1E2D40), height: 1),
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
                        color: const Color(0xFF1B2E42),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Profile image
                          Container(
                            width: 60,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFF253A50),
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
      builder: (ctx) => _WriteReviewSheet(
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
            color: Color(0xFF0D1B2A),
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
              const Divider(color: Color(0xFF1E2D40), height: 1),
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

  // ---- External links -----------------------------------------------------

  Widget _buildExternalLinksSection(BuildContext context, Movie movie) {
    final hasImdb = movie.imdbId != null && movie.imdbId!.isNotEmpty;
    final hasHomepage = movie.homepage != null && movie.homepage!.isNotEmpty;
    final hasInstagram =
        movie.instagramId != null && movie.instagramId!.isNotEmpty;
    final hasTwitter = movie.twitterId != null && movie.twitterId!.isNotEmpty;

    if (!hasImdb && !hasHomepage && !hasInstagram && !hasTwitter) {
      return const SizedBox.shrink();
    }

    Future<void> launch(String url) async {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    Widget linkCard({
      required Widget leading,
      required String label,
      required VoidCallback onTap,
      bool fullWidth = false,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2033),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E2D40)),
          ),
          child: Row(
            mainAxisAlignment: fullWidth
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (fullWidth)
                const Icon(Icons.open_in_new,
                    color: FlixieColors.medium, size: 18),
            ],
          ),
        ),
      );
    }

    final hasSocials = hasInstagram || hasTwitter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'External Links',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: FlixieColors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (hasImdb)
          linkCard(
            fullWidth: true,
            leading: Container(
              width: 36,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF5C518),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: const Text(
                'IMDb',
                style: TextStyle(
                  color: Color(0xFF000000),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            label: 'Official Profile',
            onTap: () => launch('https://www.imdb.com/title/${movie.imdbId}'),
          ),
        if (hasImdb && (hasHomepage || hasSocials)) const SizedBox(height: 10),
        if (hasHomepage)
          linkCard(
            fullWidth: true,
            leading: const Icon(Icons.language,
                color: FlixieColors.medium, size: 20),
            label: 'Official Website',
            onTap: () => launch(movie.homepage!),
          ),
        if (hasHomepage && hasSocials) const SizedBox(height: 10),
        if (hasSocials)
          Row(
            children: [
              if (hasInstagram)
                Expanded(
                  child: linkCard(
                    leading: const Icon(Icons.language,
                        color: FlixieColors.medium, size: 20),
                    label: 'INSTAGRAM',
                    onTap: () => launch(
                        'https://www.instagram.com/${movie.instagramId}'),
                  ),
                ),
              if (hasInstagram && hasTwitter) const SizedBox(width: 10),
              if (hasTwitter)
                Expanded(
                  child: linkCard(
                    leading: const Text(
                      '@',
                      style: TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    label: 'TWITTER',
                    onTap: () =>
                        launch('https://twitter.com/${movie.twitterId}'),
                  ),
                ),
            ],
          ),
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

// (sub-widgets moved to lib/screens/movie_detail/)

// ---- Write Review bottom sheet --------------------------------------------

// ---------------------------------------------------------------------------
// Friend activity row
// ---------------------------------------------------------------------------

class _FriendActivityRow extends StatelessWidget {
  const _FriendActivityRow({required this.activity});

  final MovieFriendActivity activity;

  @override
  Widget build(BuildContext context) {
    final hexCode = activity.iconColor?['hexCode'] as String?;
    Color avatarColor = FlixieColors.primary;
    if (hexCode != null) {
      final hex = hexCode.replaceFirst('#', '');
      final value = int.tryParse(
          hex.length == 6
              ? 'FF$hex'
              : hex.length == 8
                  ? hex
                  : 'FF$hex',
          radix: 16);
      if (value != null) avatarColor = Color(value);
    }

    final displayName = activity.firstName?.isNotEmpty == true
        ? '${activity.username} (${activity.firstName})'
        : activity.username;
    final initial =
        activity.username.isNotEmpty ? activity.username[0].toUpperCase() : '?';

    final badges = <_ActivityBadge>[];
    if (activity.watched) {
      badges.add(const _ActivityBadge(
          icon: Icons.check_circle, label: 'Watched', color: Colors.green));
    }
    if (activity.onWatchlist) {
      badges.add(const _ActivityBadge(
          icon: Icons.bookmark, label: 'Watchlist', color: Colors.amber));
    }
    if (activity.favorited) {
      badges.add(const _ActivityBadge(
          icon: Icons.favorite, label: 'Favourite', color: Colors.red));
    }
    if (activity.rating != null) {
      badges.add(_ActivityBadge(
        icon: Icons.star_rounded,
        label: '${activity.rating}/10',
        color: FlixieColors.tertiary,
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: avatarColor.withValues(alpha: 0.25),
            child: Text(
              initial,
              style: TextStyle(
                color: avatarColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: FlixieColors.light,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: badges,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
}

// ---------------------------------------------------------------------------
// Watch-request bottom sheet
// ---------------------------------------------------------------------------

class _WatchRequestSheet extends StatefulWidget {
  const _WatchRequestSheet({
    required this.movieId,
    required this.movieTitle,
    required this.requesterId,
    required this.friends,
    required this.onSuccess,
    required this.onError,
  });

  final int? movieId;
  final String? movieTitle;
  final String? requesterId;
  final List<Friendship> friends;
  final VoidCallback onSuccess;
  final VoidCallback onError;

  @override
  State<_WatchRequestSheet> createState() => _WatchRequestSheetState();
}

class _WatchRequestSheetState extends State<_WatchRequestSheet> {
  final _messageController = TextEditingController();
  String? _selectedFriendId;
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_selectedFriendId == null || _isSending) return;
    setState(() => _isSending = true);
    try {
      final result = await RequestService.sendRequest({
        'requesterId': widget.requesterId,
        'recipientId': _selectedFriendId,
        'movieId': widget.movieId,
        'message': _messageController.text.trim(),
        'type': 'MOVIE_WATCH_REQUEST',
      });
      final notification = result?['notification'] as Map<String, dynamic>?;
      logger.d('[WatchRequest] notification created: $notification');

      if (mounted) Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      logger.e('Failed to send watch request: $e');
      if (mounted) setState(() => _isSending = false);
      widget.onError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite to Watch',
                style: Theme.of(context).textTheme.titleLarge),
            if (widget.movieTitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.movieTitle!,
                style:
                    const TextStyle(color: FlixieColors.medium, fontSize: 14),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'SELECT A FRIEND',
              style: TextStyle(
                color: FlixieColors.medium,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.friends.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final friend = widget.friends[i].friendUser;
                  if (friend == null) return const SizedBox.shrink();
                  final isSelected = _selectedFriendId == friend.id;
                  final iconColor = friend.iconColor;
                  final hex = ((iconColor?['hexCode'] ?? iconColor?['hex'])
                              as String? ??
                          '')
                      .replaceAll('#', '');
                  final pillColor = hex.isNotEmpty
                      ? Color(int.tryParse('0xFF$hex') ??
                          FlixieColors.primary.toARGB32())
                      : FlixieColors.primary;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFriendId = friend.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? pillColor
                            : pillColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected
                              ? pillColor
                              : pillColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        friend.displayName,
                        style: TextStyle(
                          color: isSelected ? Colors.white : FlixieColors.light,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'MESSAGE (OPTIONAL)',
              style: TextStyle(
                color: FlixieColors.medium,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 3,
              style: const TextStyle(color: FlixieColors.light),
              decoration: InputDecoration(
                hintText: 'e.g. Want to watch this together?',
                hintStyle:
                    const TextStyle(color: FlixieColors.medium, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF0F2033),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1E2D40)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1E2D40)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: FlixieColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isSending || _selectedFriendId == null ? null : _send,
                child: _isSending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Text('Send Invite'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WriteReviewSheet extends StatefulWidget {
  const _WriteReviewSheet({
    required this.movieId,
    required this.userId,
    required this.onSubmitted,
  });

  final int movieId;
  final String userId;
  final void Function(Review review) onSubmitted;

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  int _rating = 5;
  bool _recommended = true;
  bool _containsSpoilers = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool _submitted = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final draft = Review(
        id: '',
        userId: widget.userId,
        movieId: widget.movieId,
        showId: null,
        rating: _rating,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        upvotes: 0,
        downvotes: 0,
        containsSpoilers: _containsSpoilers,
        language: 'en',
        recommended: _recommended,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      final created = await UserService.addMovieReview(draft);
      if (mounted) {
        widget.onSubmitted(created);
        setState(() => _submitted = true);
        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to submit review: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Write a Review',
                  style: TextStyle(
                    color: FlixieColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: FlixieColors.light),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E2D40), height: 1),
          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating
                    const Text(
                      'Rating',
                      style: TextStyle(
                        color: FlixieColors.light,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(10, (i) {
                        final value = i + 1;
                        final isSelected = value <= _rating;
                        return GestureDetector(
                          onTap: () => setState(() => _rating = value),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              isSelected ? Icons.star : Icons.star_border,
                              color: isSelected
                                  ? Colors.amber
                                  : FlixieColors.medium,
                              size: 28,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_rating / 10',
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    const Text(
                      'Title',
                      style: TextStyle(
                        color: FlixieColors.light,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: FlixieColors.white),
                      decoration: InputDecoration(
                        hintText: 'Give your review a title',
                        hintStyle: const TextStyle(color: FlixieColors.medium),
                        filled: true,
                        fillColor: const Color(0xFF1B2E42),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    // Body
                    const Text(
                      'Review',
                      style: TextStyle(
                        color: FlixieColors.light,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bodyController,
                      style: const TextStyle(color: FlixieColors.white),
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Share your thoughts about the movie...',
                        hintStyle: const TextStyle(color: FlixieColors.medium),
                        filled: true,
                        fillColor: const Color(0xFF1B2E42),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    // Toggles
                    _ToggleTile(
                      label: 'I recommend this movie',
                      value: _recommended,
                      onChanged: (v) => setState(() => _recommended = v),
                    ),
                    const SizedBox(height: 8),
                    _ToggleTile(
                      label: 'Contains spoilers',
                      value: _containsSpoilers,
                      onChanged: (v) => setState(() => _containsSpoilers = v),
                    ),
                    const SizedBox(height: 28),
                    // Submit
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _submitted
                          ? Container(
                              key: const ValueKey('success'),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Review submitted!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SizedBox(
                              key: const ValueKey('button'),
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: FlixieColors.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isSubmitting ? null : _submit,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Submit Review',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ), // Flexible
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2E42),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: FlixieColors.light, fontSize: 14)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: FlixieColors.primary,
          ),
        ],
      ),
    );
  }
}
