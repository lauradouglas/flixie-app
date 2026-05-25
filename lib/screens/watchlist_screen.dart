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
  int _selectedTab = 0; // 0 = All, 1 = Movies, 2 = Upcoming, 3 = Watched

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

  Map<int, int> _friendOverlapCounts(String currentUserId) {
    final movieFriendUsers = <int, Set<String>>{};
    for (final item in _allWatchlist) {
      final userId = item.userId;
      if (userId.isEmpty || userId == 'me' || userId == currentUserId) continue;
      movieFriendUsers.putIfAbsent(item.movieId, () => <String>{}).add(userId);
    }
    return {
      for (final entry in movieFriendUsers.entries) entry.key: entry.value.length
    };
  }

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

  String _sortByLabel() {
    switch (_sortBy) {
      case 'recent':
        return 'Date Added';
      case 'titleAsc':
        return 'Title A–Z';
      case 'titleDesc':
        return 'Title Z–A';
      case 'ratingDesc':
        return 'Rating';
      case 'yearDesc':
        return 'Year (Newest)';
      case 'yearAsc':
        return 'Year (Oldest)';
      default:
        return 'Date Added';
    }
  }

  Widget _buildStatsRow() {
    final total = _allWatchlist.length;
    final highlyRated =
        _allWatchlist.where((i) => (i.movie?.voteAverage ?? 0) >= 7.5).length;
    final today = DateTime.now();
    final upcoming = _allWatchlist.where((i) {
      final d = DateTime.tryParse(i.movie?.releaseDate ?? '');
      return d != null && d.isAfter(today);
    }).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2348),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        children: [
          _statItem(
              Icons.bookmark_border_rounded, total.toString(), 'Total',
              FlixieColors.primary),
          _statDivider(),
          _statItem(Icons.star_border_rounded, highlyRated.toString(),
              'Highly Rated', FlixieColors.tertiary),
          _statDivider(),
          _statItem(Icons.calendar_today_outlined, upcoming.toString(),
              'Upcoming', FlixieColors.secondary),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: FlixieColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 22)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: FlixieColors.light, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 44,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _buildSortFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          const Text('Sort by ',
              style: TextStyle(color: FlixieColors.medium, fontSize: 13)),
          GestureDetector(
            onTap: _openFilterSheet,
            child: Row(
              children: [
                Text(
                  _sortByLabel(),
                  style: const TextStyle(
                      color: FlixieColors.light,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: FlixieColors.light, size: 18),
              ],
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _openFilterSheet,
            icon: const Icon(Icons.tune_rounded, size: 19),
            label: const Text('Filter'),
            style: TextButton.styleFrom(
              foregroundColor: _hasActiveFilters
                  ? FlixieColors.primary
                  : FlixieColors.light,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.bookmark_border_rounded,
                color: FlixieColors.primary, size: 26),
            SizedBox(width: 8),
            Text(
              'Watchlist',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined, color: Colors.white),
            tooltip: 'Invite friend',
            onPressed: () {},
          ),
          Stack(
            children: [
              IconButton(
                icon:
                    const Icon(Icons.more_vert_rounded, color: Colors.white),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: _WatchlistTabs(
                    selectedIndex: _selectedTab,
                    onChanged: (i) => setState(() => _selectedTab = i),
                  ),
                ),
                if (_allWatchlist.isNotEmpty) _buildStatsRow(),
                if (_allWatchlist.isNotEmpty) _buildSortFilterRow(),
                Expanded(child: _buildContent()),
              ],
            ),
    );
  }

  List<WatchlistMovie> _visibleWatchlist() {
    if (_selectedTab == 3) {
      // Watched: watchlist items also in watchedMovies
      final user = context.read<AuthProvider>().dbUser;
      final watchedIds =
          user?.watchedMovies?.map((w) => w.movieId).toSet() ?? <int>{};
      return _filteredWatchlist
          .where((item) => watchedIds.contains(item.movieId))
          .toList();
    }
    if (_selectedTab == 2) {
      final today = DateTime.now();
      return _filteredWatchlist.where((item) {
        final date = DateTime.tryParse(item.movie?.releaseDate ?? '');
        return date != null && date.isAfter(today);
      }).toList();
    }
    // All (0) and Movies (1) show the same list (movie watchlist only; shows are in a separate list)
    return _filteredWatchlist;
  }

  Widget _buildContent() {
    final items = _visibleWatchlist();
    final user = context.read<AuthProvider>().dbUser;
    final overlapCounts = _friendOverlapCounts(user?.id ?? '');

    if (items.isEmpty) {
      final emptyLabel = switch (_selectedTab) {
        2 => 'No upcoming titles in your watchlist',
        3 => 'No watched movies in your watchlist',
        _ => 'Your watchlist is empty',
      };
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedTab == 3
                  ? Icons.check_circle_outline
                  : Icons.movie_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              emptyLabel,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if (_selectedTab == 0) ...[
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
        final isWatched = user?.isMovieWatched(item.movieId) ?? false;
        return WatchlistMovieRow(
          watchlistItem: item,
          isWatched: isWatched,
          friendOverlapCount: overlapCounts[item.movieId] ?? 0,
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

  static const labels = ['All', 'Movies', 'Upcoming', 'Watched'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (index) {
        final selected = selectedIndex == index;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 10),
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? FlixieColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: FlixieColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? FlixieColors.white : FlixieColors.light,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class WatchlistMovieRow extends StatelessWidget {
  final WatchlistMovie watchlistItem;
  final bool isWatched;
  final int friendOverlapCount;
  final VoidCallback onTap;
  final VoidCallback onMarkAsWatched;
  final VoidCallback onRemove;

  const WatchlistMovieRow({
    super.key,
    required this.watchlistItem,
    required this.isWatched,
    this.friendOverlapCount = 0,
    required this.onTap,
    required this.onMarkAsWatched,
    required this.onRemove,
  });

  static const List<Color> _friendDotColors = [
    FlixieColors.primary,
    FlixieColors.secondary,
    FlixieColors.tertiary,
  ];

  static String _runtimeLabel(int? minutes) {
    if (minutes == null || minutes == 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  static String _addedByLabel(String userId) {
    return userId == 'me' || userId.isEmpty ? 'you' : 'friend';
  }

  @override
  Widget build(BuildContext context) {
    final movie = watchlistItem.movie;
    if (movie == null) return const SizedBox.shrink();

    final year = movie.releaseDate?.split('-').first;
    final runtime = _runtimeLabel(movie.runtime);
    final avg = movie.voteAverage;
    final rating = (avg == null || avg == 0.0) ? null : avg.toStringAsFixed(1);
    final posterUrl = movie.posterPath != null
        ? 'https://image.tmdb.org/t/p/w185${movie.posterPath}'
        : null;
    final addedDate = _formatDate(watchlistItem.createdAt);

    final metaParts = [
      if (year != null && year.isNotEmpty) year,
      if (runtime.isNotEmpty) runtime,
    ];
    final metaStr = metaParts.join(' • ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A2348),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 76,
                height: 110,
                child: posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: Colors.grey[900]),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[900],
                          child: const Icon(Icons.movie, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey[900],
                        child: const Icon(Icons.movie, color: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_horiz_rounded,
                            color: FlixieColors.medium, size: 20),
                        color: FlixieColors.tabBarBackgroundFocused,
                        onSelected: (value) {
                          if (value == 'watched') onMarkAsWatched();
                          if (value == 'remove') onRemove();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'watched',
                            child: Row(children: [
                              Icon(Icons.check_circle_outline,
                                  color: FlixieColors.success, size: 20),
                              SizedBox(width: 8),
                              Text('Mark as Watched',
                                  style: TextStyle(color: Colors.white)),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Row(children: [
                              Icon(Icons.remove_circle_outline,
                                  color: FlixieColors.danger, size: 20),
                              SizedBox(width: 8),
                              Text('Remove',
                                  style: TextStyle(color: Colors.white)),
                            ]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (metaStr.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      metaStr,
                      style: const TextStyle(
                          color: FlixieColors.medium, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (rating != null) ...[
                        const Icon(Icons.star_rounded,
                            color: FlixieColors.primary, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '$rating/10',
                          style: const TextStyle(
                            color: FlixieColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (friendOverlapCount > 0) ...[
                        const SizedBox(width: 10),
                        _FriendOverlapDots(count: friendOverlapCount),
                      ],
                      const Spacer(),
                      Icon(
                        isWatched
                            ? Icons.check_circle_outline_rounded
                            : Icons.bookmark_border_rounded,
                        size: 24,
                        color: isWatched
                            ? const Color(0xFF00D07A)
                            : FlixieColors.light,
                      ),
                    ],
                  ),
                  if (addedDate.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Added by ${_addedByLabel(watchlistItem.userId)} • $addedDate',
                      style: const TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendOverlapDots extends StatelessWidget {
  const _FriendOverlapDots({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final visible = count > 3 ? 3 : count;
    final width = visible <= 0 ? 0.0 : 12.0 + (visible - 1) * 9.0;
    return Row(
      children: [
        SizedBox(
          width: width,
          height: 12,
          child: Stack(
            children: List.generate(
              visible,
              (index) => Positioned(
                left: index * 9,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: WatchlistMovieRow._friendDotColors[
                        index % WatchlistMovieRow._friendDotColors.length],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: FlixieColors.tabBarBackgroundFocused,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (count > visible) ...[
          const SizedBox(width: 4),
          Text(
            '+${count - visible}',
            style: const TextStyle(
              color: FlixieColors.medium,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
