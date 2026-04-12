import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import '../models/watchlist_movie.dart';
import 'watchlist/filter_sheet.dart';

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
  String _sortBy =
      'recent'; // recent, titleAsc, titleDesc, ratingDesc, yearAsc, yearDesc

  // Active filters
  String? _filterGenre; // null = all genres
  double? _filterMinRating; // null = no min
  int? _filterYear; // null = all years
  int? _filterMaxRuntime; // null = any length, value in minutes

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
          .whereType<Map<String, dynamic>>()
          .map((item) => WatchlistMovie.fromJson(item))
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
        final m = item.movie;
        if (m == null) return false;
        // Text search
        if (!m.title.toLowerCase().contains(query)) return false;
        // Genre filter
        if (_filterGenre != null && !m.genres.contains(_filterGenre)) {
          return false;
        }
        // Min rating filter
        if (_filterMinRating != null &&
            (m.voteAverage ?? 0) < _filterMinRating!) {
          return false;
        }
        // Year filter
        if (_filterYear != null) {
          final year = int.tryParse(m.releaseDate?.split('-').first ?? '');
          if (year != _filterYear) return false;
        }
        // Max runtime filter
        if (_filterMaxRuntime != null &&
            (m.runtime == null || m.runtime! > _filterMaxRuntime!)) {
          return false;
        }
        return true;
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
        case 'yearDesc':
          _filteredWatchlist.sort((a, b) {
            final yA =
                int.tryParse(a.movie?.releaseDate?.split('-').first ?? '') ?? 0;
            final yB =
                int.tryParse(b.movie?.releaseDate?.split('-').first ?? '') ?? 0;
            return yB.compareTo(yA);
          });
          break;
        case 'yearAsc':
          _filteredWatchlist.sort((a, b) {
            final yA =
                int.tryParse(a.movie?.releaseDate?.split('-').first ?? '') ?? 0;
            final yB =
                int.tryParse(b.movie?.releaseDate?.split('-').first ?? '') ?? 0;
            return yA.compareTo(yB);
          });
          break;
      }
    });
  }

  List<String> _allGenres() {
    final genres = <String>{};
    for (final item in _allWatchlist) {
      genres.addAll(item.movie?.genres ?? []);
    }
    return genres.toList()..sort();
  }

  List<int> _allYears() {
    final years = <int>{};
    for (final item in _allWatchlist) {
      final y = int.tryParse(item.movie?.releaseDate?.split('-').first ?? '');
      if (y != null) years.add(y);
    }
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  bool get _hasActiveFilters =>
      _filterGenre != null ||
      _filterMinRating != null ||
      _filterYear != null ||
      _filterMaxRuntime != null;

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WatchlistFilterSheet(
        genres: _allGenres(),
        years: _allYears(),
        currentGenre: _filterGenre,
        currentMinRating: _filterMinRating,
        currentYear: _filterYear,
        currentMaxRuntime: _filterMaxRuntime,
        currentSort: _sortBy,
        onApply: (genre, minRating, year, maxRuntime, sort) {
          setState(() {
            _filterGenre = genre;
            _filterMinRating = minRating;
            _filterYear = year;
            _filterMaxRuntime = maxRuntime;
            _sortBy = sort;
          });
          _filterWatchlist();
        },
      ),
    );
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

    // Check if already in watched list before removing
    final alreadyWatched = user.isMovieWatched(item.movieId);

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

      // If not already in watched list, offer to add it
      if (!alreadyWatched && mounted) {
        final markWatched = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: FlixieColors.tabBarBackgroundFocused,
            title: const Text('Did you watch it?',
                style: TextStyle(color: FlixieColors.light)),
            content: Text(
                'Want to add ${item.movie?.title ?? "this movie"} to your watched list?',
                style: const TextStyle(color: FlixieColors.medium)),
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
              await UserService.addToWatched(user.id, item.movieId);
          final currentWatched = List<dynamic>.from(user.watchedMovies ?? []);
          if (watchedResult != null) {
            currentWatched.add(watchedResult.toJson());
          } else {
            currentWatched.add({
              'movieId': item.movieId,
              'watchedAt': DateTime.now().toIso8601String(),
            });
          }
          authProvider.updateUserList(watchedMovies: currentWatched);
          authProvider.markActivityChanged();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${item.movie?.title ?? "Movie"} added to watched list'),
                backgroundColor: FlixieColors.success,
              ),
            );
          }
        }
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

  String _totalRuntimeLabel() {
    final total = _allWatchlist.fold<int>(
        0, (sum, item) => sum + (item.movie?.runtime ?? 0));
    if (total == 0) return '';
    final hours = total ~/ 60;
    final minutes = total % 60;
    if (hours == 0) return '${minutes}m total';
    if (minutes == 0) return '${hours}h total';
    return '${hours}h ${minutes}m total';
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
                () {
                  final runtime = _totalRuntimeLabel();
                  final count =
                      '${_allWatchlist.length} item${_allWatchlist.length == 1 ? '' : 's'}';
                  return runtime.isEmpty ? count : '$count · $runtime';
                }(),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: Colors.white),
                tooltip: 'Sort & Filter',
                onPressed: _openFilterSheet,
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: FlixieColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
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

    final items = _filteredWatchlist;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: (items.length / 2).ceil(),
      itemBuilder: (context, rowIndex) {
        final leftIndex = rowIndex * 2;
        final rightIndex = leftIndex + 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: WatchlistMovieCard(
                    watchlistItem: items[leftIndex],
                    onTap: () =>
                        context.push('/movies/${items[leftIndex].movieId}'),
                    onMarkAsWatched: () => _markAsWatched(items[leftIndex]),
                    onRemove: () => _removeFromWatchlist(items[leftIndex]),
                  ),
                ),
                const SizedBox(width: 12),
                if (rightIndex < items.length)
                  Expanded(
                    child: WatchlistMovieCard(
                      watchlistItem: items[rightIndex],
                      onTap: () =>
                          context.push('/movies/${items[rightIndex].movieId}'),
                      onMarkAsWatched: () => _markAsWatched(items[rightIndex]),
                      onRemove: () => _removeFromWatchlist(items[rightIndex]),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
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

    final yearRaw = movie.releaseDate?.split('-').first;
    final year = (yearRaw != null && yearRaw.isNotEmpty) ? yearRaw : 'N/A';
    final avg = movie.voteAverage;
    final rating = (avg == null || avg == 0.0) ? 'N/A' : avg.toStringAsFixed(1);
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
              ],
            ),
            // Movie info — Expanded so both cards in a row reach the same height
            Expanded(
              child: Padding(
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

