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
  String _sortBy =
      'recent'; // recent, titleAsc, titleDesc, ratingDesc, yearAsc, yearDesc

  // Active filters
  String? _filterGenre; // null = all genres
  double? _filterMinRating; // null = no min
  int? _filterYear; // null = all years

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
        if (_filterGenre != null && !m.genres.contains(_filterGenre))
          return false;
        // Min rating filter
        if (_filterMinRating != null &&
            (m.voteAverage ?? 0) < _filterMinRating!) return false;
        // Year filter
        if (_filterYear != null) {
          final year = int.tryParse(m.releaseDate?.split('-').first ?? '');
          if (year != _filterYear) return false;
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
      _filterGenre != null || _filterMinRating != null || _filterYear != null;

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        genres: _allGenres(),
        years: _allYears(),
        currentGenre: _filterGenre,
        currentMinRating: _filterMinRating,
        currentYear: _filterYear,
        currentSort: _sortBy,
        onApply: (genre, minRating, year, sort) {
          setState(() {
            _filterGenre = genre;
            _filterMinRating = minRating;
            _filterYear = year;
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sort & Filter bottom sheet
// ---------------------------------------------------------------------------

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.genres,
    required this.years,
    required this.currentGenre,
    required this.currentMinRating,
    required this.currentYear,
    required this.currentSort,
    required this.onApply,
  });

  final List<String> genres;
  final List<int> years;
  final String? currentGenre;
  final double? currentMinRating;
  final int? currentYear;
  final String currentSort;
  final void Function(String? genre, double? minRating, int? year, String sort)
      onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _sort;
  String? _genre;
  double? _minRating;
  int? _year;

  static const _sortOptions = [
    ('recent', 'Recently Added'),
    ('titleAsc', 'Title A\u2013Z'),
    ('titleDesc', 'Title Z\u2013A'),
    ('ratingDesc', 'Highest Rated'),
    ('yearDesc', 'Newest First'),
    ('yearAsc', 'Oldest First'),
  ];

  static const _ratingOptions = [
    (null, 'Any'),
    (5.0, '5+'),
    (6.0, '6+'),
    (7.0, '7+'),
    (8.0, '8+'),
  ];

  @override
  void initState() {
    super.initState();
    _sort = widget.currentSort;
    _genre = widget.currentGenre;
    _minRating = widget.currentMinRating;
    _year = widget.currentYear;
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1B3258),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FlixieColors.medium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sort & Filter',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => setState(() {
                      _sort = 'recent';
                      _genre = null;
                      _minRating = null;
                      _year = null;
                    }),
                    child: const Text('Reset',
                        style: TextStyle(color: FlixieColors.primary)),
                  ),
                ],
              ),

              // Sort
              _sectionLabel('Sort By'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sortOptions.map((opt) {
                  final selected = _sort == opt.$1;
                  return ChoiceChip(
                    label: Text(opt.$2),
                    selected: selected,
                    onSelected: (_) => setState(() => _sort = opt.$1),
                    selectedColor: FlixieColors.primary,
                    backgroundColor: FlixieColors.tabBarBackgroundFocused,
                    labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.grey,
                        fontSize: 13),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),

              // Min Rating
              _sectionLabel('Minimum Rating'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _ratingOptions.map((opt) {
                  final selected = _minRating == opt.$1;
                  return ChoiceChip(
                    label: Text(opt.$2),
                    selected: selected,
                    onSelected: (_) => setState(() => _minRating = opt.$1),
                    selectedColor: FlixieColors.primary,
                    backgroundColor: FlixieColors.tabBarBackgroundFocused,
                    labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.grey,
                        fontSize: 13),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),

              // Genre
              if (widget.genres.isNotEmpty) ...[
                _sectionLabel('Genre'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _genre == null,
                      onSelected: (_) => setState(() => _genre = null),
                      selectedColor: FlixieColors.primary,
                      backgroundColor: FlixieColors.tabBarBackgroundFocused,
                      labelStyle: TextStyle(
                          color: _genre == null ? Colors.white : Colors.grey,
                          fontSize: 13),
                      side: BorderSide.none,
                    ),
                    ...widget.genres.map((g) {
                      final selected = _genre == g;
                      return ChoiceChip(
                        label: Text(g),
                        selected: selected,
                        onSelected: (_) => setState(() => _genre = g),
                        selectedColor: FlixieColors.primary,
                        backgroundColor: FlixieColors.tabBarBackgroundFocused,
                        labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.grey,
                            fontSize: 13),
                        side: BorderSide.none,
                      );
                    }),
                  ],
                ),
              ],

              // Release Year
              if (widget.years.isNotEmpty) ...[
                _sectionLabel('Release Year'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _year == null,
                      onSelected: (_) => setState(() => _year = null),
                      selectedColor: FlixieColors.primary,
                      backgroundColor: FlixieColors.tabBarBackgroundFocused,
                      labelStyle: TextStyle(
                          color: _year == null ? Colors.white : Colors.grey,
                          fontSize: 13),
                      side: BorderSide.none,
                    ),
                    ...widget.years.map((y) {
                      final selected = _year == y;
                      return ChoiceChip(
                        label: Text('$y'),
                        selected: selected,
                        onSelected: (_) => setState(() => _year = y),
                        selectedColor: FlixieColors.primary,
                        backgroundColor: FlixieColors.tabBarBackgroundFocused,
                        labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.grey,
                            fontSize: 13),
                        side: BorderSide.none,
                      );
                    }),
                  ],
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onApply(_genre, _minRating, _year, _sort);
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: FlixieColors.primary),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
