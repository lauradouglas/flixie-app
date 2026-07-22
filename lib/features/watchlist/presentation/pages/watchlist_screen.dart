import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/features/movies/presentation/widgets/add_to_list_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/watchlist/presentation/widgets/filter_sheet.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/features/watchlist/presentation/controllers/watchlist_actions_controller.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_follow_up_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';

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
  int _selectedTab = 0; // 0 = All, 1 = Watch now, 2 = Upcoming, 3 = Watched

  // Active filters
  String? _filterGenre; // null = all genres
  double? _filterMinRating; // null = no min
  int? _filterYear; // null = all years
  int? _filterMaxRuntime; // null = any length, value in minutes

  final Map<int, List<WatchProvider>> _movieWatchProviders = {};
  final Map<int, bool> _canWatchNowByMovieId = {};
  Set<int> _userWatchProviderIds = {};
  bool _loadingWatchProviderAvailability = false;
  int _watchProviderAvailabilityRequest = 0;

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
        if (watchlist.isEmpty) {
          _movieWatchProviders.clear();
          _canWatchNowByMovieId.clear();
        } else {
          final currentMovieIds = watchlist.map((item) => item.movieId).toSet();
          _movieWatchProviders
              .removeWhere((movieId, _) => !currentMovieIds.contains(movieId));
          _canWatchNowByMovieId
              .removeWhere((movieId, _) => !currentMovieIds.contains(movieId));
        }
        _filterWatchlist();
        _loading = false;
      });

      _loadWatchProviderAvailability(watchlist);
    } catch (e) {
      debugPrint('Error loading watchlist: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadWatchProviderAvailability(
      List<WatchlistMovie> watchlist) async {
    final requestId = ++_watchProviderAvailabilityRequest;
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.dbUser;
    if (user == null || watchlist.isEmpty) {
      if (mounted) {
        setState(() {
          _userWatchProviderIds = {};
          _movieWatchProviders.clear();
          _canWatchNowByMovieId.clear();
          _loadingWatchProviderAvailability = false;
        });
      }
      return;
    }

    try {
      final movieIds = watchlist.map((w) => w.movieId).toSet();
      final cachedProviders = authProvider.cachedWatchProvidersByMovieId;
      final hasMissingProviders = movieIds.any(
        (movieId) => !cachedProviders.containsKey(movieId),
      );
      final needsUserProviders =
          authProvider.cachedUserWatchProviderIds == null;
      setState(() {
        _movieWatchProviders
          ..clear()
          ..addEntries(movieIds
              .where(cachedProviders.containsKey)
              .map((id) => MapEntry(id, cachedProviders[id]!)));
        _userWatchProviderIds =
            authProvider.cachedUserWatchProviderIds ?? const {};
        _loadingWatchProviderAvailability =
            hasMissingProviders || needsUserProviders;
      });

      if (hasMissingProviders || needsUserProviders) {
        await authProvider.ensureWatchProviderCache(movieIds: movieIds);
      }

      if (!mounted || requestId != _watchProviderAvailabilityRequest) return;

      final providers = authProvider.cachedWatchProvidersByMovieId;
      final userProviderIds =
          authProvider.cachedUserWatchProviderIds ?? const <int>{};
      setState(() {
        _userWatchProviderIds = userProviderIds;
        _movieWatchProviders
          ..clear()
          ..addEntries(movieIds
              .where(providers.containsKey)
              .map((id) => MapEntry(id, providers[id]!)));
        _canWatchNowByMovieId
          ..clear()
          ..addEntries(_movieWatchProviders.entries.map((entry) => MapEntry(
                entry.key,
                entry.value.any((provider) =>
                    provider.isStreaming &&
                    userProviderIds.contains(provider.id)),
              )));
        _loadingWatchProviderAvailability = false;
      });

      _filterWatchlist();
    } catch (e) {
      debugPrint('Error loading watch provider availability: $e');
      if (!mounted || requestId != _watchProviderAvailabilityRequest) return;
      setState(() => _loadingWatchProviderAvailability = false);
    }
  }

  bool _isAvailableOnUserProviders(int movieId) {
    final cached = _canWatchNowByMovieId[movieId];
    if (cached != null) return cached;

    final providers = _movieWatchProviders[movieId] ?? const <WatchProvider>[];
    return providers.any((provider) =>
        provider.isStreaming && _userWatchProviderIds.contains(provider.id));
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

  Future<void> _openAddMovieSheet() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.dbUser;
    if (user == null) return;

    final existingMovieIds = _allWatchlist.map((item) => item.movieId).toSet();
    final selected = await showModalBottomSheet<MovieShort>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WatchlistMovieSearchSheet(
        existingMovieIds: existingMovieIds,
      ),
    );
    if (!mounted || selected == null) return;

    if (existingMovieIds.contains(selected.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${selected.name} is already in your watchlist')),
      );
      return;
    }

    try {
      final addedResponse =
          await UserService.addToWatchlist(user.id, selected.id);
      final added = _entryWithMovieFallback(addedResponse, selected);
      final currentWatchlist =
          List<WatchlistMovie>.from(user.movieWatchlist ?? []);
      currentWatchlist.removeWhere((item) => item.movieId == selected.id);
      currentWatchlist.add(added);

      authProvider.updateUserList(movieWatchlist: currentWatchlist);
      authProvider.markActivityChanged();
      _allWatchlist
        ..removeWhere((item) => item.movieId == selected.id)
        ..add(added);
      _filterWatchlist();
      _loadWatchProviderAvailability(_allWatchlist);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected.name} added to watchlist'),
            backgroundColor: FlixieColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding movie to watchlist: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add movie to watchlist'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    }
  }

  Future<void> _showWatchedFollowUps(
    WatchlistMovie item,
    String userId,
  ) async {
    final movie = item.movie;
    final choice = await showModalBottomSheet<WatchFollowUpChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WatchFollowUpSheet(
        movieTitle: movie?.title ?? 'This movie',
        posterPath: movie?.posterPath,
      ),
    );
    if (!mounted || choice == null) return;

    if (choice.addWatchEntry) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => RewatchLogSheet(
          onSubmit: ({
            required String watchedAt,
            required double? rating,
            required bool? recommended,
            required String? notes,
          }) async {
            await WatchlistActionsController.instance.logMovieWatch(
              userId,
              LogMovieWatchRequest(
                movieId: item.movieId,
                watchedAt: watchedAt,
                rating: rating,
                recommended: recommended,
                notes: notes,
              ),
            );
            if (mounted) {
              context.read<AuthProvider>().markActivityChanged();
            }
          },
        ),
      );
    }

    if (mounted && choice.writeReview) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => WriteReviewSheet(
          movieId: item.movieId,
          userId: userId,
          onSubmitted: (Review review) {
            final auth = context.read<AuthProvider>();
            auth.invalidateCachedReviews();
            auth.markActivityChanged();
          },
        ),
      );
    }
  }

  WatchlistMovie _entryWithMovieFallback(
    WatchlistMovie entry,
    MovieShort movie,
  ) {
    if (entry.movie != null) return entry;
    return WatchlistMovie(
      id: entry.id,
      userId: entry.userId,
      movieId: entry.movieId,
      removed: entry.removed,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      movie: WatchlistMovieDetails(
        id: movie.id,
        title: movie.name,
        posterPath: movie.poster,
        releaseDate: movie.releaseDate,
        voteAverage: movie.voteAverage,
      ),
    );
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
        await _showWatchedFollowUps(item, user.id);
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

  Future<void> _clearWatchedFromWatchlist() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.dbUser;
    if (user == null) return;
    final watchedIds =
        user.watchedMovies?.map((item) => item.movieId).toSet() ?? <int>{};
    final watchedItems = _allWatchlist
        .where((item) => watchedIds.contains(item.movieId))
        .toList();
    if (watchedItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Clear watched movies?'),
            content: Text(
              'Remove ${watchedItems.length} watched ${watchedItems.length == 1 ? 'movie' : 'movies'} from your watchlist? Your watch history will not be affected.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlixieColors.danger,
                ),
                child: const Text('Clear watched'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await Future.wait(watchedItems.map(
        (item) => UserService.removeFromWatchlist(user.id, item.movieId),
      ));
      final idsToRemove = watchedItems.map((item) => item.movieId).toSet();
      final updatedWatchlist = (user.movieWatchlist ?? [])
          .where((item) => !idsToRemove.contains(item.movieId))
          .toList();
      authProvider.updateUserList(movieWatchlist: updatedWatchlist);
      if (!mounted) return;
      setState(() {
        _allWatchlist.removeWhere((item) => idsToRemove.contains(item.movieId));
        _filterWatchlist();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${watchedItems.length} watched ${watchedItems.length == 1 ? 'movie' : 'movies'} removed from your watchlist',
          ),
          backgroundColor: FlixieColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to clear watched movies'),
          backgroundColor: FlixieColors.danger,
        ),
      );
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
            onPressed: _selectedTab == 3
                ? _clearWatchedFromWatchlist
                : _openFilterSheet,
            icon: Icon(
              _selectedTab == 3
                  ? Icons.playlist_remove_rounded
                  : Icons.tune_rounded,
              size: 19,
            ),
            label: Text(_selectedTab == 3 ? 'Clear watched' : 'Filter'),
            style: TextButton.styleFrom(
              foregroundColor: _selectedTab == 3
                  ? FlixieColors.danger
                  : FlixieColors.primary,
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: FlixieColors.textPrimary, fontSize: 15),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search watchlist',
          hintStyle: const TextStyle(color: FlixieColors.medium),
          prefixIcon: const Icon(Icons.search_rounded,
              color: FlixieColors.medium, size: 21),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded,
                      color: FlixieColors.medium, size: 20),
                  onPressed: () => _searchController.clear(),
                ),
          filled: true,
          fillColor: FlixieColors.surfaceElevated,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: FlixieColors.primary),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlixiePageScaffold(
      appBar: FlixieTitleAppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'Watch history',
            onPressed: () => context.push('/watch-history'),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            tooltip: 'Add movie',
            onPressed: _openAddMovieSheet,
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
          : _buildContent(),
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
      final upcoming = _filteredWatchlist.where((item) {
        final date = DateTime.tryParse(item.movie?.releaseDate ?? '');
        return date != null && date.isAfter(today);
      }).toList();
      upcoming.sort((a, b) {
        final dateA = DateTime.tryParse(a.movie?.releaseDate ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(b.movie?.releaseDate ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dateA.compareTo(dateB);
      });
      return upcoming;
    }
    if (_selectedTab == 1) {
      return _filteredWatchlist
          .where((item) => _isAvailableOnUserProviders(item.movieId))
          .toList();
    }
    return _filteredWatchlist;
  }

  Widget _buildContent() {
    final items = _visibleWatchlist();
    final user = context.read<AuthProvider>().dbUser;
    final hasMovies = _allWatchlist.isNotEmpty;

    final header = <Widget>[
      _buildSearchBar(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 0, 10),
        child: _WatchlistTabs(
          selectedIndex: _selectedTab,
          onChanged: (i) => setState(() => _selectedTab = i),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => context.push('/watch-history'),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('View watch history'),
            style: TextButton.styleFrom(
              foregroundColor: FlixieColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ),
      ),
      if (hasMovies) _buildStatsRow(),
      if (hasMovies) _buildSortFilterRow(),
    ];

    if (items.isEmpty) {
      final emptyLabel = switch (_selectedTab) {
        1 => _loadingWatchProviderAvailability
            ? 'Checking your providers...'
            : 'Nothing you can watch right now',
        2 => 'No upcoming titles in your watchlist',
        3 => 'No watched movies in your watchlist',
        _ => _searchController.text.isNotEmpty
            ? 'No watchlist matches'
            : 'Your watchlist is empty',
      };
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ...header,
          SizedBox(
            height: 320,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedTab == 3
                        ? Icons.check_circle_outline
                        : _selectedTab == 1
                            ? Icons.play_circle_outline_rounded
                            : Icons.movie_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyLabel,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  if (_selectedTab == 0 &&
                      _searchController.text.isEmpty &&
                      !hasMovies) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Add movies to start building your watchlist',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: header.length + items.length,
      separatorBuilder: (context, index) => index < header.length
          ? const SizedBox.shrink()
          : const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index < header.length) return header[index];

        final item = items[index - header.length];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildWatchlistRow(item, user),
        );
      },
    );
  }

  Widget _buildWatchlistRow(WatchlistMovie item, dynamic user) {
    final isWatched = user?.isMovieWatched(item.movieId) ?? false;
    final isLoadingProviders = _loadingWatchProviderAvailability &&
        !_movieWatchProviders.containsKey(item.movieId);
    final providers =
        _movieWatchProviders[item.movieId] ?? const <WatchProvider>[];
    final canWatchNow = _isAvailableOnUserProviders(item.movieId);
    return WatchlistMovieRow(
      watchlistItem: item,
      isWatched: isWatched,
      availableProviders: providers,
      userWatchProviderIds: _userWatchProviderIds,
      canWatchNow: canWatchNow,
      isLoadingProviders: isLoadingProviders,
      onTap: () => context.push('/movies/${item.movieId}'),
      onMarkAsWatched: () => _markAsWatched(item),
      onAddToFavourites: () => _addToFavorites(item),
      onAddToList: () => _showAddToListSheet(item),
      onRequestToWatch: () => _showWatchRequestSheet(item),
      onRemove: () => _removeFromWatchlist(item),
    );
  }
}

class _WatchlistMovieSearchSheet extends StatefulWidget {
  const _WatchlistMovieSearchSheet({required this.existingMovieIds});

  final Set<int> existingMovieIds;

  @override
  State<_WatchlistMovieSearchSheet> createState() =>
      _WatchlistMovieSearchSheetState();
}

class _WatchlistMovieSearchSheetState
    extends State<_WatchlistMovieSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<MovieShort> _results = [];
  bool _isSearching = false;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    setState(() => _query = query);
    if (query.length < 3) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    try {
      final response = await SearchService.search(query, type: 'movie');
      final movies = response.results
          .where((item) => !item.isPerson && item.movie != null)
          .map((item) => item.movie!)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _results = movies;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
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
                  color: FlixieColors.medium.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add to Watchlist',
                        style: TextStyle(
                          color: FlixieColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: FlixieColors.light),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: FlixieColors.textPrimary),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search movies',
                    hintStyle: const TextStyle(color: FlixieColors.medium),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: FlixieColors.medium),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded,
                                color: FlixieColors.medium),
                            onPressed: () {
                              _controller.clear();
                              _onSearchChanged('');
                            },
                          ),
                    filled: true,
                    fillColor: FlixieColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FlixieColors.primary),
                    ),
                  ),
                ),
              ),
              Expanded(child: _buildResults(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResults(ScrollController scrollController) {
    if (_query.length < 3) {
      return const Center(
        child: Text(
          'Search for a movie to add',
          style: TextStyle(color: FlixieColors.medium),
        ),
      );
    }

    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: FlixieColors.primary),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No movies found for "$_query"',
          style: const TextStyle(color: FlixieColors.medium),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final movie = _results[index];
        final isAdded = widget.existingMovieIds.contains(movie.id);
        return _WatchlistMovieSearchResultTile(
          movie: movie,
          isAdded: isAdded,
          onTap: isAdded ? null : () => Navigator.pop(context, movie),
        );
      },
    );
  }
}

class _WatchlistMovieSearchResultTile extends StatelessWidget {
  const _WatchlistMovieSearchResultTile({
    required this.movie,
    required this.isAdded,
    required this.onTap,
  });

  final MovieShort movie;
  final bool isAdded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final posterUrl = movie.poster == null
        ? null
        : 'https://image.tmdb.org/t/p/w185${movie.poster}';
    final year = _movieYear(movie.releaseDate);
    final vote = movie.voteAverage;

    return Material(
      color: FlixieColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 48,
                  height: 72,
                  child: posterUrl == null
                      ? const _MoviePosterPlaceholder()
                      : CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const _MoviePosterPlaceholder(),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FlixieColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (year != null)
                          Text(
                            year,
                            style: const TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 12,
                            ),
                          ),
                        if (year != null && vote != null && vote > 0)
                          const Text(
                            '  •  ',
                            style: TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 12,
                            ),
                          ),
                        if (vote != null && vote > 0) ...[
                          const Icon(Icons.star_rounded,
                              color: FlixieColors.tertiary, size: 13),
                          const SizedBox(width: 2),
                          Text(
                            vote.toStringAsFixed(1),
                            style: const TextStyle(
                              color: FlixieColors.tertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                isAdded
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: isAdded ? FlixieColors.success : FlixieColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _movieYear(String? releaseDate) {
    if (releaseDate == null || releaseDate.isEmpty) return null;
    final parsed = DateTime.tryParse(releaseDate);
    if (parsed != null) return parsed.year.toString();
    return releaseDate.length >= 4 ? releaseDate.substring(0, 4) : null;
  }
}

class _MoviePosterPlaceholder extends StatelessWidget {
  const _MoviePosterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FlixieColors.primary.withValues(alpha: 0.18),
      child: const Icon(Icons.movie_outlined, color: FlixieColors.primary),
    );
  }
}

class _WatchlistTabs extends StatelessWidget {
  const _WatchlistTabs({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const labels = ['All', 'Watch now', 'Upcoming', 'Watched in list'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = selectedIndex == index;
          return Padding(
            padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 8),
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                constraints: const BoxConstraints(minWidth: 78),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? FlixieColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.16),
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
          );
        }),
      ),
    );
  }
}

class WatchlistMovieRow extends StatelessWidget {
  final WatchlistMovie watchlistItem;
  final bool isWatched;
  final List<WatchProvider> availableProviders;
  final Set<int> userWatchProviderIds;
  final bool canWatchNow;
  final bool isLoadingProviders;
  final VoidCallback onTap;
  final VoidCallback onMarkAsWatched;
  final VoidCallback? onAddToFavourites;
  final VoidCallback? onAddToList;
  final VoidCallback? onRequestToWatch;
  final VoidCallback onRemove;

  const WatchlistMovieRow({
    super.key,
    required this.watchlistItem,
    required this.isWatched,
    this.availableProviders = const <WatchProvider>[],
    this.userWatchProviderIds = const <int>{},
    this.canWatchNow = false,
    this.isLoadingProviders = false,
    required this.onTap,
    required this.onMarkAsWatched,
    this.onAddToFavourites,
    this.onAddToList,
    this.onRequestToWatch,
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
                          Tooltip(
                            message: 'Remove from watchlist',
                            child: InkWell(
                              onTap: onRemove,
                              borderRadius: BorderRadius.circular(15),
                              child: const SizedBox(
                                width: 30,
                                height: 30,
                                child: Center(
                                  child: Icon(
                                    Icons.bookmark_rounded,
                                    color: FlixieColors.primary,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'More actions',
                            padding: EdgeInsets.zero,
                            color: FlixieColors.surfaceElevated,
                            onSelected: (value) {
                              if (value == 'watched') {
                                onMarkAsWatched();
                              } else if (value == 'remove') {
                                onRemove();
                              } else if (value == 'favourite') {
                                onAddToFavourites?.call();
                              } else if (value == 'list') {
                                onAddToList?.call();
                              } else if (value == 'request_watch') {
                                onRequestToWatch?.call();
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
                                  Expanded(
                                    child: Text('Mark as Watched',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'favourite',
                                child: Row(children: [
                                  Icon(Icons.favorite_border_rounded,
                                      color: FlixieColors.danger, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Add to favourites',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'list',
                                child: Row(children: [
                                  Icon(Icons.playlist_add_rounded,
                                      color: FlixieColors.secondary, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Add to list',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'request_watch',
                                child: Row(children: [
                                  Icon(Icons.group_add_outlined,
                                      color: FlixieColors.primary, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Invite friends',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'share',
                                child: Row(children: [
                                  Icon(Icons.share_outlined,
                                      color: FlixieColors.secondary, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Share',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Row(children: [
                                  Icon(Icons.remove_circle_outline,
                                      color: FlixieColors.danger, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Remove',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ]),
                              ),
                            ],
                            child: const SizedBox(
                              width: 30,
                              height: 30,
                              child: Center(
                                child: Icon(Icons.more_horiz_rounded,
                                    color: FlixieColors.medium, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                      const SizedBox(height: 12),
                      _WatchProvidersInline(
                        releaseDate: movie.releaseDate,
                        providers: availableProviders,
                        userWatchProviderIds: userWatchProviderIds,
                        canWatchNow: canWatchNow,
                        isLoading: isLoadingProviders,
                      ),
                      // Added date row
                      if (addedDate.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
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

class _WatchProvidersInline extends StatelessWidget {
  const _WatchProvidersInline({
    required this.releaseDate,
    required this.providers,
    required this.userWatchProviderIds,
    required this.canWatchNow,
    required this.isLoading,
  });

  final String? releaseDate;
  final List<WatchProvider> providers;
  final Set<int> userWatchProviderIds;
  final bool canWatchNow;
  final bool isLoading;

  DateTime? get _releaseDay {
    final parsed = DateTime.tryParse(releaseDate ?? '');
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isUpcoming {
    final release = _releaseDay;
    return release != null && release.isAfter(_today);
  }

  String get _releaseLabel {
    final date = _releaseDay;
    if (date == null) return '';
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
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isUpcoming) {
      return Row(
        children: [
          const Icon(Icons.event_outlined,
              size: 15, color: FlixieColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _releaseLabel.isEmpty
                  ? 'Coming to cinema'
                  : 'Coming to cinema $_releaseLabel',
              style: const TextStyle(
                color: FlixieColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    if (isLoading) {
      return const Row(
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: FlixieColors.medium,
            ),
          ),
          SizedBox(width: 5),
          Text(
            'Checking providers...',
            style: TextStyle(color: FlixieColors.medium, fontSize: 12),
          ),
        ],
      );
    }

    if (providers.isEmpty) {
      return const Row(children: [
        Icon(Icons.tv_off_outlined, size: 13, color: FlixieColors.medium),
        SizedBox(width: 5),
        Flexible(
          child: Text(
            'Streaming availability unavailable',
            style: TextStyle(color: FlixieColors.medium, fontSize: 12),
          ),
        ),
      ]);
    }

    final streamingProviders = providers.where((p) => p.isStreaming).toList();
    final rentalProviders = providers.where((p) => p.isRental).toList();
    final displayProviders =
        streamingProviders.isNotEmpty ? streamingProviders : rentalProviders;
    final showingRentals =
        streamingProviders.isEmpty && rentalProviders.isNotEmpty;
    if (displayProviders.isEmpty) {
      return const Row(children: [
        Icon(Icons.tv_off_outlined, size: 13, color: FlixieColors.medium),
        SizedBox(width: 5),
        Flexible(
          child: Text(
            'Streaming availability unavailable',
            style: TextStyle(color: FlixieColors.medium, fontSize: 12),
          ),
        ),
      ]);
    }

    final sortedProviders = [...displayProviders]..sort((a, b) {
        final aMatches = userWatchProviderIds.contains(a.id);
        final bMatches = userWatchProviderIds.contains(b.id);
        if (aMatches == bMatches) {
          return a.displayPriority.compareTo(b.displayPriority);
        }
        return aMatches ? -1 : 1;
      });
    final visibleProviders = sortedProviders.take(8).toList();
    final overflowCount = sortedProviders.length - visibleProviders.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          showingRentals
              ? 'Can rent on:'
              : canWatchNow
                  ? 'You can watch on:'
                  : 'Available on:',
          style: TextStyle(
            color: canWatchNow && !showingRentals
                ? FlixieColors.success
                : FlixieColors.medium,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...visibleProviders.map((provider) {
              final isUserProvider = userWatchProviderIds.contains(provider.id);
              return _WatchProviderLogo(
                provider: provider,
                isUserProvider: isUserProvider,
              );
            }),
            if (overflowCount > 0)
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FlixieColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  '+$overflowCount',
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WatchProviderLogo extends StatelessWidget {
  const _WatchProviderLogo({
    required this.provider,
    required this.isUserProvider,
  });

  final WatchProvider provider;
  final bool isUserProvider;

  static const _greyscale = ColorFilter.matrix([
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: CachedNetworkImage(
        imageUrl: provider.logoUrl,
        width: 30,
        height: 30,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        placeholder: (_, __) => Container(
          width: 30,
          height: 30,
          color: FlixieColors.surfaceElevated,
        ),
        errorWidget: (_, __, ___) => Container(
          width: 30,
          height: 30,
          color: FlixieColors.surfaceElevated,
          child: const Icon(Icons.tv_rounded,
              size: 15, color: FlixieColors.medium),
        ),
      ),
    );

    return Tooltip(
      message: isUserProvider
          ? provider.providerName
          : '${provider.providerName} not in your providers',
      child: Opacity(
        opacity: isUserProvider ? 1 : 0.42,
        child: Container(
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isUserProvider
                ? FlixieColors.success.withValues(alpha: 0.16)
                : FlixieColors.surfaceElevated,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isUserProvider
                  ? FlixieColors.success.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: isUserProvider
              ? logo
              : ColorFiltered(
                  colorFilter: _greyscale,
                  child: logo,
                ),
        ),
      ),
    );
  }
}
