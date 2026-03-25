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
  final List<Review> _reviews = [];
  List<SimilarMovie> _similar = [];
  List<MovieCastMember> _cast = [];
  List<WatchProvider> _watchProviders = [];
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
      ]);
      if (mounted) {
        setState(() {
          _movie = results[0] as Movie;
          _similar = results[1] as List<SimilarMovie>;
          final credits = results[2] as MovieCredits;
          _cast = credits.castMembers;
          _watchProviders = results[3] as List<WatchProvider>;
          
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
      
      // Successfully updated on server, toggle UI state
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _inWatchlist = !_inWatchlist;
          _currentlyUpdating = null;
          _watchlistBounceKey++;
        });
      }
    } catch (e) {
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
      
      // Successfully updated on server, toggle UI state
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _isWatched = !_isWatched;
          _currentlyUpdating = null;
          _watchedBounceKey++;
        });
      }
    } catch (e) {
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
      
      // Successfully updated on server, toggle UI state
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _isFavorite = !_isFavorite;
          _currentlyUpdating = null;
          _favoriteBounceKey++;
        });
      }
    } catch (e) {
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

  /// Derives two-letter initials from a userId string.
  String _initials(String userId) {
    if (userId.isEmpty) return '?';
    return userId
        .substring(0, userId.length >= 2 ? 2 : userId.length)
        .toUpperCase();
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
                  const SizedBox(height: 16),
                  _buildScores(context, movie),
                  const Divider(height: 32, color: Color(0xFF1E2D40)),
                  _buildSynopsis(context, movie),
                  const SizedBox(height: 24),
                  _buildWatchNowButton(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
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
        background: _HeroBackdrop(
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
    return _GenreChip(label: tagline.toUpperCase());
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
          _ScoreTile(
            value: _formatFlixScore(score),
            label: 'FLIXSCORE',
            onInfoTap: () => _showFlixScoreInfo(context),
          ),
        if (score != null && voteCount != null) const SizedBox(width: 28),
        if (voteCount != null)
          _ScoreTile(
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

  Widget _buildWatchNowButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: FlixieColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text(
          'Watch Now',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        onPressed: () {},
      ),
    );
  }

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
            itemBuilder: (context, i) => _WatchProviderCard(provider: _watchProviders[i]),
          ),
        ),
      ],
    );
  }

  // ---- Top cast ------------------------------------------------------------

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
              onPressed: () {},
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
            itemBuilder: (context, i) => _CastCard(member: _cast[i]),
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
          ..._reviews.map((r) => _ReviewCard(
                review: r,
                avatarInitials: _initials(r.userId),
              )),
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
            itemBuilder: (context, i) => _SimilarCard(movie: _similar[i]),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        imagePath != null
            ? CachedNetworkImage(
                imageUrl: imagePath!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
        // Dark gradient overlay
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x44000000),
                Color(0xBB000000),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1B2E42),
      child: const Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: FlixieColors.medium,
          size: 64,
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: FlixieColors.primary.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: FlixieColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.value,
    required this.label,
    this.valueColor = FlixieColors.white,
    this.onInfoTap,
  });

  final String value;
  final String label;
  final Color valueColor;
  final VoidCallback? onInfoTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onInfoTap != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onInfoTap,
                child: const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: FlixieColors.medium,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _CastCard extends StatelessWidget {
  const _CastCard({required this.member});

  final MovieCastMember member;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile image
          Container(
            height: 120,
            width: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF1B2E42),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: member.profileImage != null
                ? CachedNetworkImage(
                    imageUrl: 'https://image.tmdb.org/t/p/w185${member.profileImage}',
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _avatarFallback(),
                  )
                : _avatarFallback(),
          ),
          const SizedBox(height: 6),
          Text(
            member.name,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            member.character,
            style: const TextStyle(
              color: FlixieColors.medium,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: const Color(0xFF253A50),
      child: const Center(
        child: Icon(Icons.person, color: FlixieColors.medium, size: 40),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.avatarInitials});

  final Review review;
  final String avatarInitials;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2E42),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: FlixieColors.primary.withValues(alpha: 0.3),
                child: Text(
                  avatarInitials,
                  style: const TextStyle(
                    color: FlixieColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.title,
                      style: const TextStyle(
                        color: FlixieColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (review.createdAt != null)
                      Text(
                        review.createdAt!,
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, color: FlixieColors.warning, size: 14),
                  const SizedBox(width: 3),
                  Text(
                    '${review.rating}/10',
                    style: const TextStyle(
                      color: FlixieColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.body,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimilarCard extends StatelessWidget {
  const _SimilarCard({required this.movie});

  final SimilarMovie movie;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/movies/${movie.id}'),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1B2E42),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: movie.posterPath != null
                  ? CachedNetworkImage(
                      imageUrl:
                          'https://image.tmdb.org/t/p/w342${movie.posterPath!}',
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _posterFallback(),
                    )
                  : _posterFallback(),
            ),
            const SizedBox(height: 6),
            Text(
              movie.title,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _posterFallback() {
    return Container(
      color: const Color(0xFF253A50),
      child: const Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: FlixieColors.medium,
          size: 36,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Watch Provider Card
// ---------------------------------------------------------------------------

class _WatchProviderCard extends StatelessWidget {
  const _WatchProviderCard({required this.provider});

  final WatchProvider provider;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF1B2E42),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: CachedNetworkImage(
              imageUrl: 'https://image.tmdb.org/t/p/w92${provider.logoPath}',
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _logoFallback(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            provider.providerName,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _logoFallback() {
    return Container(
      color: const Color(0xFF253A50),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          color: FlixieColors.medium,
          size: 28,
        ),
      ),
    );
  }
}
