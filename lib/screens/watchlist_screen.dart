import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import '../models/watched_movie.dart';
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
  List<dynamic> _showWatchlist = [];
  bool _loading = true;
  String _sortBy =
      'recent'; // recent, titleAsc, titleDesc, ratingDesc, yearAsc, yearDesc
  int _selectedTab = 0; // 0 = Movies, 1 = Shows, 2 = Upcoming

  // Active filters
  String? _filterGenre; // null = all genres
  double? _filterMinRating; // null = no min
  int? _filterYear; // null = all years
  int? _filterMaxRuntime; // null = any length, value in minutes

  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    _loadWatchlist();
    _searchController.addListener(_filterWatchlist);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newProvider = context.read<AuthProvider>();
    if (_authProvider != newProvider) {
      _authProvider?.removeListener(_onUserChanged);
      _authProvider = newProvider;
      _authProvider!.addListener(_onUserChanged);
    }
  }

  void _onUserChanged() {
    if (mounted) _loadWatchlist();
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onUserChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadWatchlist() {
    final authProvider = context.read<AuthProvider>();
    final userWatchlist = authProvider.dbUser?.movieWatchlist;
    _showWatchlist = List<dynamic>.from(authProvider.dbUser?.showWatchlist ?? []);

    if (userWatchlist == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // The list is already typed — just filter out removed entries
      final watchlist =
          (userWatchlist).where((item) => item.removed != true).toList();

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
      final currentWatchlist =
          List<WatchlistMovie>.from(user.movieWatchlist ?? []);
      currentWatchlist.removeWhere((w) => w.movieId == item.movieId);

      final currentWatched = List<WatchedMovie>.from(user.watchedMovies ?? []);
      // Add the watched movie (prefer the API response, fallback to minimal object)
      currentWatched.add(watchedMovie ??
          WatchedMovie(
            id: '',
            userId: user.id,
            movieId: item.movieId,
            watchedAt: DateTime.now().toIso8601String(),
          ));

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
      final currentWatchlist =
          List<WatchlistMovie>.from(user.movieWatchlist ?? []);
      currentWatchlist.removeWhere((w) => w.movieId == item.movieId);

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
          final currentWatched =
              List<WatchedMovie>.from(user.watchedMovies ?? []);
          currentWatched.add(watchedResult ??
              WatchedMovie(
                id: '',
                userId: user.id,
                movieId: item.movieId,
                watchedAt: DateTime.now().toIso8601String(),
              ));
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            tooltip: 'Search',
            onPressed: () => context.push('/search'),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                tooltip: 'Sort & Filter',
                onPressed: _openFilterSheet,
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 10,
                  top: 10,
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
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FlixieColors.primary))
          : Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _WatchlistTabs(
                    selectedIndex: _selectedTab,
                    onChanged: (i) => setState(() => _selectedTab = i),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search watchlist...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon:
                          const Icon(Icons.search_rounded, color: Colors.grey),
                      filled: true,
                      fillColor: FlixieColors.tabBarBackgroundFocused,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildContent()),
              ],
            ),
    );
  }

  List<WatchlistMovie> _visibleWatchlist() {
    if (_selectedTab == 2) {
      final today = DateTime.now();
      return _filteredWatchlist.where((item) {
        final date = DateTime.tryParse(item.movie?.releaseDate ?? '');
        return date != null && date.isAfter(today);
      }).toList();
    }
    if (_selectedTab == 1) return const <WatchlistMovie>[];
    return _filteredWatchlist;
  }

  Widget _buildContent() {
    if (_selectedTab == 1) {
      return _buildShowsContent();
    }

    final items = _visibleWatchlist();
    if (items.isEmpty) {
      final emptyLabel = switch (_selectedTab) {
        1 => 'No shows in your watchlist yet',
        2 => 'No upcoming titles in your watchlist',
        _ => _searchController.text.isNotEmpty
            ? 'No movies found'
            : 'Your watchlist is empty',
      };
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedTab == 1
                  ? Icons.live_tv_outlined
                  : (_searchController.text.isNotEmpty
                      ? Icons.search_off
                      : Icons.movie_outlined),
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              emptyLabel,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if (_searchController.text.isEmpty && _selectedTab == 0) ...[
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return WatchlistMovieRow(
          watchlistItem: item,
          onTap: () => context.push('/movies/${item.movieId}'),
          onMarkAsWatched: () => _markAsWatched(item),
          onRemove: () => _removeFromWatchlist(item),
        );
      },
    );
  }

  Widget _buildShowsContent() {
    final query = _searchController.text.toLowerCase();
    final shows = _showWatchlist.where((item) {
      final title = _showTitle(item).toLowerCase();
      return title.contains(query);
    }).toList();

    if (shows.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.live_tv_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No shows in your watchlist yet',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: shows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final show = shows[index];
        final title = _showTitle(show);
        final year = _showYear(show);
        final posterUrl = _showPosterUrl(show);
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Show detail navigation is coming soon.'),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FlixieColors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: posterUrl,
                          width: 60,
                          height: 86,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 60,
                            height: 86,
                            color: Colors.grey[900],
                            child:
                                const Icon(Icons.live_tv, color: Colors.grey),
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 86,
                          color: Colors.grey[900],
                          child: const Icon(Icons.live_tv, color: Colors.grey),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        year,
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: FlixieColors.medium),
              ],
            ),
          ),
        );
      },
    );
  }

  String _showTitle(dynamic item) {
    if (item is Map<String, dynamic>) {
      final nested = item['show'] as Map<String, dynamic>?;
      return (nested?['title'] as String?) ??
          (item['title'] as String?) ??
          'Untitled Show';
    }
    return 'Untitled Show';
  }

  String _showYear(dynamic item) {
    if (item is Map<String, dynamic>) {
      final nested = item['show'] as Map<String, dynamic>?;
      final date = (nested?['releaseDate'] as String?) ??
          (nested?['firstAirDate'] as String?) ??
          (item['releaseDate'] as String?) ??
          '';
      final year = date.split('-').first;
      if (year.isNotEmpty) return year;
    }
    return 'N/A';
  }

  String? _showPosterUrl(dynamic item) {
    if (item is Map<String, dynamic>) {
      final nested = item['show'] as Map<String, dynamic>?;
      final poster =
          (nested?['posterPath'] as String?) ?? (item['posterPath'] as String?);
      if (poster == null || poster.isEmpty) return null;
      return 'https://image.tmdb.org/t/p/w500$poster';
    }
    return null;
  }
}

class _WatchlistTabs extends StatelessWidget {
  const _WatchlistTabs({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const labels = ['Movies', 'Shows', 'Upcoming'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? FlixieColors.primary.withValues(alpha: 0.22)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? FlixieColors.primary : FlixieColors.light,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class WatchlistMovieRow extends StatelessWidget {
  final WatchlistMovie watchlistItem;
  final VoidCallback onTap;
  final VoidCallback onMarkAsWatched;
  final VoidCallback onRemove;

  const WatchlistMovieRow({
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: posterUrl != null
                  ? CachedNetworkImage(
                      imageUrl: posterUrl,
                      width: 60,
                      height: 86,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 60,
                        height: 86,
                        color: Colors.grey[900],
                        child: const Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 60,
                        height: 86,
                        color: Colors.grey[900],
                        child: const Icon(Icons.movie, color: Colors.grey),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 86,
                      color: Colors.grey[900],
                      child:
                          const Icon(Icons.movie, size: 28, color: Colors.grey),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.light,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    year,
                    style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.play_circle_outline,
                          color: FlixieColors.primary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        rating == 'N/A' ? 'No rating yet' : 'TMDB $rating',
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded,
                  color: FlixieColors.medium),
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
                      Text('Remove', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
