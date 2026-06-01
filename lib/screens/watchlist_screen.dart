import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import '../models/favorite_movie.dart';
import '../models/watched_movie.dart';
import '../models/watchlist_movie.dart';
import '../widgets/flixie_page.dart';
import 'movie_detail/add_to_list_sheet.dart';
import 'movie_detail/watch_request_sheet.dart';
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
    _showWatchlist =
        List<dynamic>.from(authProvider.dbUser?.showWatchlist ?? []);

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

  Future<void> _addToFavorites(WatchlistMovie item) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.dbUser;
    if (user == null) return;

    final movieId = item.movieId;
    if (user.isMovieFavorite(movieId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${item.movie?.title ?? "Movie"} is already in favourites',
            ),
          ),
        );
      }
      return;
    }

    try {
      final addedFavorite = await UserService.addToFavorites(user.id, movieId);
      final updatedFavorites =
          List<FavoriteMovie>.from(user.favoriteMovies ?? []);
      if (!updatedFavorites.any((f) => f.movieId == movieId)) {
        updatedFavorites.add(addedFavorite);
      }

      authProvider.updateUserList(favoriteMovies: updatedFavorites);
      authProvider.markActivityChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${item.movie?.title ?? "Movie"} added to favourites'),
            backgroundColor: FlixieColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add to favourites'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _showAddToListSheet(WatchlistMovie item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddToListSheet(movieId: item.movieId),
    );
  }

  void _showWatchRequestSheet(WatchlistMovie item) {
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
        movieId: item.movieId,
        movieTitle: item.movie?.title,
        requesterId: userId,
        friends: friends,
        onSuccess: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Watch request sent!')),
            );
          }
        },
        onError: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to send watch request')),
            );
          }
        },
      ),
    );
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
        color: FlixieColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FlixieColors.primary.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _statItem(Icons.bookmark_border_rounded, total.toString(), 'Total',
              FlixieColors.primary),
          _statDivider(),
          _statItem(Icons.star_border_rounded, highlyRated.toString(),
              'Highly Rated', FlixieColors.warning),
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
                  color: FlixieColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 22)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: FlixieColors.light, fontSize: 11),
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
                      color: FlixieColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: FlixieColors.primary, size: 18),
              ],
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _openFilterSheet,
            icon: const Icon(Icons.tune_rounded, size: 19),
            label: const Text('Filter'),
            style: TextButton.styleFrom(
              foregroundColor: FlixieColors.primary,
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
    return FlixiePageScaffold(
      appBar: FlixieTitleAppBar(
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
          onTap: () => context.push('/movies/${item.movieId}'),
          onMarkAsWatched: () => _markAsWatched(item),
          onAddToFavourites: () => _addToFavorites(item),
          onAddToList: () => _showAddToListSheet(item),
          onRequestToWatch: () => _showWatchRequestSheet(item),
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
            padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 8),
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? FlixieColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: FlixieColors.primary.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? FlixieColors.white : FlixieColors.medium,
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
  final VoidCallback onTap;
  final VoidCallback onMarkAsWatched;
  final VoidCallback onAddToFavourites;
  final VoidCallback onAddToList;
  final VoidCallback onRequestToWatch;
  final VoidCallback onRemove;

  const WatchlistMovieRow({
    super.key,
    required this.watchlistItem,
    required this.isWatched,
    required this.onTap,
    required this.onMarkAsWatched,
    required this.onAddToFavourites,
    required this.onAddToList,
    required this.onRequestToWatch,
    required this.onRemove,
  });

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

  @override
  Widget build(BuildContext context) {
    final movie = watchlistItem.movie;
    if (movie == null) return const SizedBox.shrink();

    final year = movie.releaseDate?.split('-').first;
    final runtime = _runtimeLabel(movie.runtime);
    final posterUrl = movie.posterPath != null
        ? 'https://image.tmdb.org/t/p/w342${movie.posterPath}'
        : null;
    final addedDate = _formatDate(watchlistItem.createdAt);

    // Build metadata string: year • runtime
    final metaParts = <String>[
      if (year != null && year.isNotEmpty) year,
      if (runtime.isNotEmpty) runtime,
    ];
    // Append genres (up to 2) to the metadata row
    if (movie.genres.isNotEmpty) {
      metaParts.add(movie.genres.take(2).join(', '));
    }
    final metaStr = metaParts.join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                FlixieColors.cardGradientTop,
                FlixieColors.cardGradientBottom,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: FlixieColors.primary.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Poster ──────────────────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 100,
                    height: 148,
                    child: posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            placeholder: (_, __) => Container(
                              color: FlixieColors.surfaceElevated,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: FlixieColors.surfaceElevated,
                              child: const Icon(Icons.movie,
                                  color: FlixieColors.medium),
                            ),
                          )
                        : Container(
                            color: FlixieColors.surfaceElevated,
                            child: const Icon(Icons.movie,
                                color: FlixieColors.medium),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                // ── Content ─────────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row + actions
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              movie.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: FlixieColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          WatchlistToggleButton(
                            isInWatchlist: true,
                            onPressed: onRemove,
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'More actions',
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_horiz_rounded,
                                color: FlixieColors.medium, size: 20),
                            color: FlixieColors.surfaceElevated,
                            onSelected: (value) {
                              if (value == 'watched') {
                                onMarkAsWatched();
                              } else if (value == 'remove') {
                                onRemove();
                              } else if (value == 'favourite') {
                                onAddToFavourites();
                              } else if (value == 'list') {
                                onAddToList();
                              } else if (value == 'request_watch') {
                                onRequestToWatch();
                              } else if (value == 'share') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Share is coming soon'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
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
                                value: 'favourite',
                                child: Row(children: [
                                  Icon(Icons.favorite_border_rounded,
                                      color: FlixieColors.danger, size: 20),
                                  SizedBox(width: 8),
                                  Text('Add to favourites',
                                      style: TextStyle(color: Colors.white)),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'list',
                                child: Row(children: [
                                  Icon(Icons.playlist_add_rounded,
                                      color: FlixieColors.secondary, size: 20),
                                  SizedBox(width: 8),
                                  Text('Add to list',
                                      style: TextStyle(color: Colors.white)),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'request_watch',
                                child: Row(children: [
                                  Icon(Icons.group_add_outlined,
                                      color: FlixieColors.primary, size: 20),
                                  SizedBox(width: 8),
                                  Text('Request to watch',
                                      style: TextStyle(color: Colors.white)),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'share',
                                child: Row(children: [
                                  Icon(Icons.share_outlined,
                                      color: FlixieColors.secondary, size: 20),
                                  SizedBox(width: 8),
                                  Text('Share',
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
                      // Metadata row (year · runtime · genres)
                      if (metaStr.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          metaStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      // Watchlist status pill
                      const SizedBox(height: 10),
                      _WatchlistStatusPill(),
                      // Added date row
                      if (addedDate.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 13, color: FlixieColors.medium),
                            const SizedBox(width: 5),
                            Text(
                              'Added $addedDate',
                              style: const TextStyle(
                                color: FlixieColors.medium,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WatchlistToggleButton extends StatelessWidget {
  const WatchlistToggleButton({
    super.key,
    required this.isInWatchlist,
    required this.onPressed,
  });

  final bool isInWatchlist;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: isInWatchlist ? 'Remove from watchlist' : 'Add to watchlist',
      visualDensity: VisualDensity.compact,
      iconSize: 22,
      splashRadius: 20,
      onPressed: onPressed,
      icon: Icon(
        isInWatchlist ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
        color: isInWatchlist ? FlixieColors.warning : FlixieColors.light,
      ),
    );
  }
}

/// Semi-transparent purple pill showing watchlist status.
class _WatchlistStatusPill extends StatelessWidget {
  const _WatchlistStatusPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FlixieColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: FlixieColors.primary.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bookmark_rounded,
              size: 13, color: FlixieColors.primary),
          const SizedBox(width: 5),
          const Text(
            'In your watchlist',
            style: TextStyle(
              color: FlixieColors.primaryTint,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
