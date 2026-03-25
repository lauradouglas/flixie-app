import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/movie.dart';
import '../models/movie_credits.dart';
import '../models/review.dart';
import '../models/similar_movie.dart';
import '../models/watch_provider.dart';
import '../providers/auth_provider.dart';
import '../services/movie_service.dart';
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
  bool _isLoading = true;
  String? _error;
  bool _inWatchlist = false;
  bool _isWatched = false;
  bool _isFavorite = false;
  ListUpdateType? _currentlyUpdating;
  int _watchlistBounceKey = 0;
  int _watchedBounceKey = 0;
  int _favoriteBounceKey = 0;

  // ---- Data loading ---------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _load();
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
      final results = await Future.wait([
        MovieService.getMovieById(id, userId: userId),
        MovieService.getMovieRecommendations(id),
        MovieService.getMovieCredits(id),
        MovieService.getMovieWatchProviders(id, 'US'), // TODO: Get region from user profile
        MovieService.getMovieReviews(id),
      ]);
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
          _watchProviders = results[3] as List<WatchProvider>;
          _reviews = results[4] as List<Review>;
          
          // Check movie status in user's lists
          final user = authProvider.dbUser;
          if (user != null) {
            _inWatchlist = user.isMovieInWatchlist(id);
            _isWatched = user.isMovieWatched(id);
            _isFavorite = user.isMovieFavorite(id);
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
      await (_inWatchlist
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
        
        final currentWatchlist = user.movieWatchlist ?? [];
        final updatedWatchlist = <int>[];
        
        try {
          for (var item in currentWatchlist) {
            if (item is int) {
              updatedWatchlist.add(item);
            } else if (item is Map<String, dynamic>) {
              final id = item['movieId'] ?? item['id'];
              if (id is int) {
                updatedWatchlist.add(id);
              }
            }
          }
        } catch (e) {
          logger.w('Error processing watchlist: $e');
          logger.d('currentWatchlist type: ${currentWatchlist.runtimeType}');
          logger.d('currentWatchlist: $currentWatchlist');
        }
        
        if (_inWatchlist) {
          if (!updatedWatchlist.contains(movieId)) {
            updatedWatchlist.add(movieId);
          }
        } else {
          updatedWatchlist.remove(movieId);
        }
        authProvider.updateUserList(movieWatchlist: updatedWatchlist);
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
      body: CustomScrollView(
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
                  _buildActionButtons(),
                  const SizedBox(height: 28),
                  _buildTrailersSection(context, movie),
                  const SizedBox(height: 28),
                  _buildWhereToWatchSection(context),
                  const SizedBox(height: 28),
                  _buildTopCastSection(context),
                  const SizedBox(height: 28),
                  _buildUserReviewsSection(context),
                  const SizedBox(height: 28),
                  _buildMoreLikeThisSection(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Sliver app bar with hero image --------------------------------------

  Widget _buildSliverAppBar(BuildContext context, Movie movie) {
    return SliverAppBar(
      expandedHeight: 240,
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
        if (_director != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                'Directed by ',
                style: TextStyle(
                  color: FlixieColors.medium,
                  fontSize: 13,
                ),
              ),
              Text(
                _director!,
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
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

  // ---- CTA buttons ---------------------------------------------------------

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: _isWatched ? Icons.check_circle : Icons.check_circle_outline,
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
            label: 'Favorite',
            isActive: _isFavorite,
            color: Colors.red,
            isLoading: _currentlyUpdating == ListUpdateType.favorite,
            bounceKey: _favoriteBounceKey,
            onPressed: _currentlyUpdating != null ? null : _toggleFavorite,
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
          height: 200,
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
            itemBuilder: (context, i) => WatchProviderCard(provider: _watchProviders[i]),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                                    imageUrl: 'https://image.tmdb.org/t/p/w185${member.profileImage}',
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

  // ---- User reviews --------------------------------------------------------

  Widget _buildUserReviewsSection(BuildContext context) {
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
              onPressed: () {},
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
        else
          ..._reviews.map((r) => ReviewCard(review: r)),
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
