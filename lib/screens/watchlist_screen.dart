import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import '../models/watchlist_movie.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<WatchlistMovie> _allWatchlist = [];
  List<WatchlistMovie> _filteredWatchlist = [];
  bool _loading = true;
  String _sortBy = 'recent'; // recent, titleAsc, titleDesc, ratingDesc

  @override
  void initState() {
    super.initState();
    _loadWatchlist();
    _searchController.addListener(_filterWatchlist);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadWatchlist() {
    final authProvider = context.read<AuthProvider>();
    final userWatchlist = authProvider.dbUser?.movieWatchlist;

    if (userWatchlist == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Parse the watchlist from user data
      final watchlist = userWatchlist
          .where((item) => item is Map<String, dynamic>)
          .map((item) => WatchlistMovie.fromJson(item as Map<String, dynamic>))
          .where((item) => item.removed != true)
          .toList();

      setState(() {
        _allWatchlist = watchlist;
        _filterWatchlist();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading watchlist: $e');
      setState(() => _loading = false);
    }
  }

  void _filterWatchlist() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredWatchlist = _allWatchlist.where((item) {
        if (item.movie == null) return false;
        final title = item.movie!.title.toLowerCase();
        return title.contains(query);
      }).toList();

      // Apply sorting
      switch (_sortBy) {
        case 'recent':
          _filteredWatchlist.sort((a, b) {
            final dateA = DateTime.tryParse(a.createdAt ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final dateB = DateTime.tryParse(b.createdAt ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          });
          break;
        case 'titleAsc':
          _filteredWatchlist.sort(
              (a, b) => (a.movie?.title ?? '').compareTo(b.movie?.title ?? ''));
          break;
        case 'titleDesc':
          _filteredWatchlist.sort(
              (a, b) => (b.movie?.title ?? '').compareTo(a.movie?.title ?? ''));
          break;
        case 'ratingDesc':
          _filteredWatchlist.sort((a, b) =>
              (b.movie?.voteAverage ?? 0).compareTo(a.movie?.voteAverage ?? 0));
          break;
      }
    });
  }

  Future<void> _markAsWatched(WatchlistMovie item) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.dbUser;
    if (user == null) return;

    try {
      // Remove from watchlist and add to watched
      await UserService.removeFromWatchlist(user.id, item.movieId);
      final watchedMovie =
          await UserService.addToWatched(user.id, item.movieId);

      // Update the local user lists
      final currentWatchlist = List<dynamic>.from(user.movieWatchlist ?? []);
      currentWatchlist.removeWhere((w) {
        if (w is Map<String, dynamic>) {
          return (w['movieId'] ?? w['id']) == item.movieId;
        }
        return w == item.movieId;
      });

      final currentWatched = List<dynamic>.from(user.watchedMovies ?? []);
      // Add the watched movie (prefer the API response, fallback to creating object)
      if (watchedMovie != null) {
        currentWatched.add(watchedMovie.toJson());
      } else {
        // If API didn't return data, create a basic watched record
        currentWatched.add({
          'movieId': item.movieId,
          'userId': user.id,
          'watchedAt': DateTime.now().toIso8601String(),
        });
      }

      // Update provider with both lists
      authProvider.updateUserList(
        movieWatchlist: currentWatchlist,
        watchedMovies: currentWatched,
      );
      authProvider.markActivityChanged();

      // Update local state
      setState(() {
        _allWatchlist.removeWhere((w) => w.id == item.id);
        _filterWatchlist();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.movie?.title ?? "Movie"} marked as watched'),
            backgroundColor: FlixieColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking as watched: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark as watched'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _removeFromWatchlist(WatchlistMovie item) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.dbUser;
    if (user == null) return;

    try {
      await UserService.removeFromWatchlist(user.id, item.movieId);

      // Update the local user list
      final currentWatchlist = List<dynamic>.from(user.movieWatchlist ?? []);
      currentWatchlist.removeWhere((w) {
        if (w is Map<String, dynamic>) {
          return (w['movieId'] ?? w['id']) == item.movieId;
        }
        return w == item.movieId;
      });

      // Update provider
      authProvider.updateUserList(movieWatchlist: currentWatchlist);

      setState(() {
        _allWatchlist.removeWhere((w) => w.id == item.id);
        _filterWatchlist();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${item.movie?.title ?? "Movie"} removed from watchlist'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove from watchlist'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    }
  }

  void _changeSortOrder(String? value) {
    if (value != null) {
      setState(() {
        _sortBy = value;
        _filterWatchlist();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlixieColors.background,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Watchlist',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!_loading && _allWatchlist.isNotEmpty)
              Text(
                '${_allWatchlist.length} items saved to watch',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          // Sort dropdown
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: FlixieColors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _sortBy,
              underline: const SizedBox(),
              dropdownColor: FlixieColors.tabBarBackgroundFocused,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              items: const [
                DropdownMenuItem(
                    value: 'recent', child: Text('Recently Added')),
                DropdownMenuItem(value: 'titleAsc', child: Text('Title A-Z')),
                DropdownMenuItem(value: 'titleDesc', child: Text('Title Z-A')),
              ],
              onChanged: _changeSortOrder,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search watchlist...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: FlixieColors.tabBarBackgroundFocused,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FlixieColors.primary))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_filteredWatchlist.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isNotEmpty
                  ? Icons.search_off
                  : Icons.movie_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No movies found'
                  : 'Your watchlist is empty',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if (_searchController.text.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Add movies to start building your watchlist',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.50,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredWatchlist.length,
      itemBuilder: (context, index) {
        return WatchlistMovieCard(
          watchlistItem: _filteredWatchlist[index],
          onTap: () {
            final movieId = _filteredWatchlist[index].movieId;
            context.push('/movies/$movieId');
          },
          onMarkAsWatched: () => _markAsWatched(_filteredWatchlist[index]),
          onRemove: () => _removeFromWatchlist(_filteredWatchlist[index]),
        );
      },
    );
  }
}

class WatchlistMovieCard extends StatelessWidget {
  final WatchlistMovie watchlistItem;
  final VoidCallback onTap;
  final VoidCallback onMarkAsWatched;
  final VoidCallback onRemove;

  const WatchlistMovieCard({
    super.key,
    required this.watchlistItem,
    required this.onTap,
    required this.onMarkAsWatched,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final movie = watchlistItem.movie;
    if (movie == null) return const SizedBox();

    final year = movie.releaseDate?.split('-').first ?? 'N/A';
    final rating = movie.voteAverage?.toStringAsFixed(1) ?? 'N/A';
    final posterUrl = movie.posterPath != null
        ? 'https://image.tmdb.org/t/p/w500${movie.posterPath}'
        : null;

    // Parse date for "Added on" display
    String addedDate = 'Unknown';
    if (watchlistItem.createdAt != null) {
      final date = DateTime.tryParse(watchlistItem.createdAt!);
      if (date != null) {
        addedDate =
            '${date.month}/${date.day}/${date.year.toString().substring(2)}';
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster with play button and menu
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  child: posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: posterUrl,
                          width: double.infinity,
                          height: 230,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 230,
                            color: Colors.grey[900],
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: FlixieColors.primary),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 230,
                            color: Colors.grey[900],
                            child: const Icon(Icons.movie, color: Colors.grey),
                          ),
                        )
                      : Container(
                          height: 230,
                          color: Colors.grey[900],
                          child: const Icon(Icons.movie,
                              size: 48, color: Colors.grey),
                        ),
                ),
                // Three-dot menu (top right)
                Positioned(
                  top: 4,
                  right: 4,
                  child: PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.more_vert,
                          color: Colors.white, size: 18),
                    ),
                    color: FlixieColors.tabBarBackgroundFocused,
                    onSelected: (value) {
                      if (value == 'watched') {
                        onMarkAsWatched();
                      } else if (value == 'remove') {
                        onRemove();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'watched',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: FlixieColors.success, size: 20),
                            SizedBox(width: 8),
                            Text('Mark as Watched',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.remove_circle_outline,
                                color: FlixieColors.danger, size: 20),
                            SizedBox(width: 8),
                            Text('Remove',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Play button (bottom right)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: FlixieColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.play_arrow,
                          color: Colors.white, size: 18),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: onTap,
                    ),
                  ),
                ),
              ],
            ),
            // Movie info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Year and Rating
                  Row(
                    children: [
                      Text(
                        year,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.star, color: Colors.amber, size: 11),
                      const SizedBox(width: 2),
                      Text(
                        rating,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Added date
                  Text(
                    'ADDED ON $addedDate',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: FlixieColors.primary.withOpacity(0.2),
                      border: Border.all(color: FlixieColors.primary, width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TO WATCH',
                      style: TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
