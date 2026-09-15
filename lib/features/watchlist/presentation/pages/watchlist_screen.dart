import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/features/settings/presentation/pages/settings_screen.dart'
    show showSettingsEditDetailsSheet;
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/app/theme/flixie_typography.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/core/utils/favourite_limits.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_limit_sheet.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/features/movies/presentation/widgets/add_to_list_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/watchlist/presentation/widgets/filter_sheet.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/features/watchlist/presentation/controllers/watchlist_actions_controller.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/friend_recommendation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/features/settings/presentation/widgets/watch_providers_sheet.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();

  List<WatchlistMovie> _allWatchlist = [];
  List<WatchlistMovie> _filteredWatchlist = [];
  List<_WatchlistShowEntry> _allShowWatchlist = [];
  List<_WatchlistShowEntry> _filteredShowWatchlist = [];
  int _mediaFilter = 0; // 0 = all, 1 = movies, 2 = shows
  bool _loading = true;
  String? _loadError;
  String _sortBy =
      'recent'; // recent, titleAsc, titleDesc, ratingDesc, yearAsc, yearDesc
  int _selectedTab = 0; // 0 = All, 1 = Watch now, 2 = Upcoming, 3 = Watched

  // Active filters
  String? _filterGenre; // null = all genres
  double? _filterMinRating; // null = no min
  int? _filterYear; // null = all years
  int? _filterMaxRuntime; // null = any length, value in minutes

  final Map<int, List<WatchProvider>> _movieWatchProviders = {};
  final Map<int, List<WatchProvider>> _showWatchProviders = {};
  final Map<int, bool> _canWatchNowByMovieId = {};
  Set<int> _userWatchProviderIds = {};
  Set<String> _userWatchProviderMatchKeys = {};
  bool _loadingWatchProviderAvailability = false;
  bool _loadingShowWatchProviderAvailability = false;
  int _watchProviderAvailabilityRequest = 0;
  final Map<int, List<FriendRecommendationItem>> _recommendationsByMovieId = {};
  int _recommendationsRequest = 0;
  int _showProvidersRequest = 0;
  int _showDetailsRequest = 0;
  final Map<int, TvShow> _showDetails = {};
  bool _loadingFriends = false;
  bool _friendsOnly = false;
  final Map<int, List<FriendRecommendationItem>> _friendsByShowId = {};

  AuthProvider? _authProvider;
  String? _watchlistSnapshot;
  String? _recommendationSnapshot;
  String? _subscriptionSnapshot;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TabRefreshController.watchlist.addListener(_refreshWatchlist);
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
    if (!mounted || _refreshing) return;
    final auth = context.read<AuthProvider>();
    final ids = auth.cachedUserWatchProviderIds;
    final subscriptionSnapshot =
        jsonEncode(ids == null ? null : (ids.toList()..sort()));
    if (subscriptionSnapshot != _subscriptionSnapshot) {
      _subscriptionSnapshot = subscriptionSnapshot;
      if (ids != null) {
        // A membership change must immediately stop matching a removed service,
        // including any previous name fallback. Availability itself is unchanged.
        _userWatchProviderIds = {...ids};
        _userWatchProviderMatchKeys = {};
        _canWatchNowByMovieId.clear();
        _filterWatchlist();
      }
    }
    if (_listSnapshot(auth) != _watchlistSnapshot) {
      _loadWatchlist();
    } else if (_friendSnapshot(auth) != _recommendationSnapshot) {
      _loadFriendRecommendations(_allWatchlist);
    }
  }

  String _listSnapshot(AuthProvider auth) => jsonEncode([
        auth.dbUser?.id,
        auth.dbUser?.movieWatchlist?.map((item) => item.toJson()).toList(),
        auth.dbUser?.showWatchlist,
        auth.dbUser?.watchedMovies?.map((item) => item.toJson()).toList(),
        auth.dbUser?.watchedShows,
        auth.dbUser?.watchProviderRegion,
      ]);

  String _friendSnapshot(AuthProvider auth) =>
      '${auth.dbUser?.id}:${auth.activityVersion}:${auth.friendDataVersion}';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshWatchlist();
  }

  Future<void> _refreshWatchlist() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await context.read<AuthProvider>().refreshUserData();
      if (mounted) _loadWatchlist();
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Couldn’t refresh your watchlist');
      }
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TabRefreshController.watchlist.removeListener(_refreshWatchlist);
    _authProvider?.removeListener(_onUserChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadWatchlist() {
    final detailsRequest = ++_showDetailsRequest;
    final authProvider = context.read<AuthProvider>();
    _loadError = null;
    _watchlistSnapshot = _listSnapshot(authProvider);
    final userWatchlist = authProvider.dbUser?.movieWatchlist;
    final userShowWatchlist = authProvider.dbUser?.showWatchlist;

    if (userWatchlist == null && userShowWatchlist == null) {
      ++_recommendationsRequest;
      setState(() {
        _allWatchlist = [];
        _allShowWatchlist = [];
        _recommendationsByMovieId.clear();
        _friendsByShowId.clear();
        _movieWatchProviders.clear();
        _showWatchProviders.clear();
        ++_showProvidersRequest;
        ++_watchProviderAvailabilityRequest;
        _filterWatchlist();
        _loading = false;
      });
      return;
    }

    try {
      // The list is already typed - just filter out removed entries
      final watchlist = (userWatchlist ?? const <WatchlistMovie>[])
          .where((item) => item.removed != true)
          .toList();
      final showWatchlist = (userShowWatchlist ?? const [])
          .whereType<Map>()
          .map((item) => _WatchlistShowEntry.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((item) => !item.removed && item.showId > 0)
          .map((item) =>
              item.needsDetails && _showDetails.containsKey(item.showId)
                  ? item.withShow(_showDetails[item.showId]!)
                  : item)
          .toList(growable: false);

      setState(() {
        _allWatchlist = watchlist;
        _allShowWatchlist = showWatchlist;
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
      _loadShowWatchProviderAvailability(showWatchlist);
      _loadMissingShowDetails(showWatchlist, detailsRequest);
      _loadFriendRecommendations(watchlist);
    } catch (e) {
      debugPrint('Error loading watchlist: $e');
      setState(() {
        _loading = false;
        _loadError = 'Couldn’t load your watchlist';
      });
    }
  }

  Future<void> _loadFriendRecommendations(
      List<WatchlistMovie> watchlist) async {
    final request = ++_recommendationsRequest;
    final snapshot = _friendSnapshot(context.read<AuthProvider>());
    if (snapshot != _recommendationSnapshot) {
      // Do not display a previous viewer's or former friend's recommendation.
      _recommendationsByMovieId.clear();
      _friendsByShowId.clear();
    }
    _recommendationSnapshot = snapshot;
    // Drop removed films immediately, including while another batch is in flight.
    final ids = watchlist.map((item) => item.movieId).toSet();
    setState(() =>
        _recommendationsByMovieId.removeWhere((id, _) => !ids.contains(id)));
    final showIds = _allShowWatchlist.map((item) => item.showId).toSet();
    setState(() {
      _loadingFriends = true;
      _friendsByShowId.removeWhere((id, _) => !showIds.contains(id));
    });
    bool current() => mounted && request == _recommendationsRequest;
    Future<Map<int, FriendRecommendationResponse>> safe(
        Future<Map<int, FriendRecommendationResponse>> future) async {
      try {
        return await future;
      } catch (_) {
        return {};
      }
    }

    final responses = await Future.wait([
      safe(MovieService().getFriendRecommendations(ids, isCurrent: current)),
      safe(ShowService.getFriendRecommendations(showIds, isCurrent: current)),
    ]);
    if (!current()) return;
    setState(() {
      _loadingFriends = false;
      _recommendationsByMovieId
        ..clear()
        ..addEntries(
            responses[0].entries.map((e) => MapEntry(e.key, e.value.friends)));
      _friendsByShowId
        ..clear()
        ..addEntries(
            responses[1].entries.map((e) => MapEntry(e.key, e.value.friends)));
    });
    _filterWatchlist();
  }

  Future<void> _loadWatchProviderAvailability(
      List<WatchlistMovie> watchlist) async {
    final requestId = ++_watchProviderAvailabilityRequest;
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.dbUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _userWatchProviderIds = {};
          _userWatchProviderMatchKeys = {};
          _movieWatchProviders.clear();
          _canWatchNowByMovieId.clear();
          _loadingWatchProviderAvailability = false;
        });
      }
      return;
    }

    try {
      final movieIds = watchlist.map((w) => w.movieId).toSet();
      final availability =
          authProvider.ensureWatchProviderCache(movieIds: movieIds);
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

      await availability;

      // The availability feed can occasionally use a newer provider record
      // than the saved-provider catalogue. Keep names as a fallback for that
      // case (for example, an updated HBO Max record/logo).
      final savedProviders = await UserService.getUserWatchProviders(user.id);

      if (!mounted || requestId != _watchProviderAvailabilityRequest) return;

      final providers = authProvider.cachedWatchProvidersByMovieId;
      final userProviderIds =
          authProvider.cachedUserWatchProviderIds ?? const <int>{};
      setState(() {
        _userWatchProviderIds = {
          ...userProviderIds,
        };
        _userWatchProviderMatchKeys = savedProviders
            .where((provider) => _userWatchProviderIds.contains(provider.id))
            .map((provider) => provider.matchKey)
            .toSet();
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
                    provider.isIncludedOffer && _isUserProvider(provider)),
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

  Future<void> _loadMissingShowDetails(
      List<_WatchlistShowEntry> entries, int request) async {
    final ids = entries
        .where((entry) =>
            entry.needsDetails && !_showDetails.containsKey(entry.showId))
        .map((entry) => entry.showId)
        .toSet()
        .toList();
    for (var start = 0; start < ids.length; start += 25) {
      if (!mounted || request != _showDetailsRequest) return;
      final chunk = ids.skip(start).take(25).toList();
      var shows = <TvShow>[];
      try {
        shows = await ShowService.getShowsByIds(chunk);
      } catch (error) {
        apiLogger.w('Show detail batch unavailable: $error');
      }
      // Recover omitted entries and older servers without the batch endpoint.
      final received = shows.map((show) => show.id).toSet();
      final missing = chunk.where((id) => !received.contains(id)).toList();
      for (var offset = 0; offset < missing.length; offset += 5) {
        if (!mounted || request != _showDetailsRequest) return;
        final recovered =
            await Future.wait(missing.skip(offset).take(5).map((id) async {
          try {
            return await ShowService.getShowById(id);
          } catch (error) {
            apiLogger.w('Could not load watchlist show $id: $error');
            return null;
          }
        }));
        shows.addAll(recovered.whereType<TvShow>());
      }
      if (!mounted || request != _showDetailsRequest) return;
      setState(() {
        for (final show in shows) {
          if (chunk.contains(show.id) && show.name != 'Unknown Show') {
            _showDetails[show.id] = show;
          }
        }
        _allShowWatchlist = _allShowWatchlist
            .map((entry) =>
                entry.needsDetails && _showDetails.containsKey(entry.showId)
                    ? entry.withShow(_showDetails[entry.showId]!)
                    : entry)
            .toList();
        _filterWatchlist();
      });
    }
  }

  Future<void> _loadShowWatchProviderAvailability(
    List<_WatchlistShowEntry> watchlist,
  ) async {
    final request = ++_showProvidersRequest;
    if (watchlist.isEmpty) {
      if (mounted && request == _showProvidersRequest) {
        setState(() {
          _showWatchProviders.clear();
          _loadingShowWatchProviderAvailability = false;
        });
      }
      return;
    }
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.dbUser;
    if (user == null) return;
    setState(() {
      _showWatchProviders.clear();
      _loadingShowWatchProviderAvailability = true;
    });
    try {
      await authProvider.ensureWatchProviderCache(movieIds: const []);
      final region = user.watchProviderRegion;
      final entries = <MapEntry<int, List<WatchProvider>>>[];
      // Bound network work; never launch an unbounded request per saved show.
      for (var start = 0; start < watchlist.length; start += 6) {
        if (!mounted || request != _showProvidersRequest) return;
        final chunk =
            await Future.wait(watchlist.skip(start).take(6).map((item) async {
          try {
            return MapEntry(item.showId,
                await ShowService.getShowWatchProviders(item.showId, region));
          } catch (_) {
            return null;
          }
        }));
        entries.addAll(chunk.whereType<MapEntry<int, List<WatchProvider>>>());
      }
      final savedProviders = await UserService.getUserWatchProviders(user.id);
      if (!mounted || request != _showProvidersRequest) return;
      setState(() {
        _userWatchProviderIds = {
          ...?authProvider.cachedUserWatchProviderIds,
        };
        _userWatchProviderMatchKeys = savedProviders
            .where((provider) => _userWatchProviderIds.contains(provider.id))
            .map((provider) => provider.matchKey)
            .toSet();
        _showWatchProviders
          ..clear()
          ..addEntries(entries);
        _loadingShowWatchProviderAvailability = false;
      });
      _filterWatchlist();
    } catch (_) {
      if (mounted && request == _showProvidersRequest) {
        setState(() => _loadingShowWatchProviderAvailability = false);
      }
    }
  }

  bool _isAvailableOnUserProviders(int movieId) {
    final cached = _canWatchNowByMovieId[movieId];
    if (cached != null) return cached;

    final providers = _movieWatchProviders[movieId] ?? const <WatchProvider>[];
    return providers.any(
        (provider) => provider.isIncludedOffer && _isUserProvider(provider));
  }

  void _filterWatchlist() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredWatchlist = _allWatchlist.where((item) {
        final m = item.movie;
        if (m == null) return false;
        if (_friendsOnly &&
            !(_recommendationsByMovieId[item.movieId]?.any((f) => f.watched) ??
                false)) {
          return false;
        }
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
      _filteredShowWatchlist = _allShowWatchlist.where((item) {
        if (!item.title.toLowerCase().contains(query)) return false;
        if (_friendsOnly &&
            !(_friendsByShowId[item.showId]?.any((f) => f.watched) ?? false)) {
          return false;
        }
        if (_filterGenre != null && !item.genres.contains(_filterGenre)) {
          return false;
        }
        if (_filterYear != null &&
            int.tryParse(item.firstAirDate?.split('-').first ?? '') !=
                _filterYear) {
          return false;
        }
        if (_filterMinRating != null &&
            (item.voteAverage == null ||
                item.voteAverage! < _filterMinRating!)) {
          return false;
        }
        if (_filterMaxRuntime != null &&
            (item.runtime == null || item.runtime! > _filterMaxRuntime!)) {
          return false;
        }
        return true;
      }).toList()
        ..sort(_compareWatchlistItems);

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
    for (final show in _allShowWatchlist) {
      genres.addAll(show.genres);
    }
    return genres.toList()..sort();
  }

  List<int> _allYears() {
    final years = <int>{};
    for (final item in _allWatchlist) {
      final y = int.tryParse(item.movie?.releaseDate?.split('-').first ?? '');
      if (y != null) years.add(y);
    }
    for (final show in _allShowWatchlist) {
      final year = int.tryParse(show.firstAirDate?.split('-').first ?? '');
      if (year != null) years.add(year);
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
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    if (user == null) return;

    final existingMovieIds = _allWatchlist.map((item) => item.movieId).toSet();
    final selected = await showModalBottomSheet<MovieShort>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WatchlistMovieSearchSheet(
        existingMovieIds: existingMovieIds,
      ),
    );
    if (!mounted || selected == null) return;

    if (existingMovieIds.contains(selected.id)) {
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.info,
            content: Text('${selected.name} is already in your watchlist')),
      );
      return;
    }

    try {
      final addedResponse =
          await UserService.addToWatchlist(user.id, selected.id);
      await analytics.watchlistAdded(
        contentType: 'movie',
        contentId: selected.id,
        source: 'watchlist',
      );
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
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.success,
            content: Text('${selected.name} added to watchlist'),
            backgroundColor: FlixieColors.surfaceElevated,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding movie to watchlist: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
          type: FlixieToastType.error,
          content: const Text('Failed to add movie to watchlist'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    }
  }

  Future<bool> _confirmWatchEntry(
    WatchlistMovie item,
    String userId,
  ) async {
    var didSubmit = false;
    final analytics = context.read<AnalyticsController>();
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RewatchLogSheet(
        onSubmit: ({
          required String? watchedAt,
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
          if (rating != null) {
            await analytics.ratingSaved(source: 'watchlist');
          }
          didSubmit = true;
          if (mounted) {
            context.read<AuthProvider>().markActivityChanged();
          }
        },
      ),
    );
    return didSubmit;
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
      useRootNavigator: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
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
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    if (user == null) return;
    final committed = await _confirmWatchEntry(item, user.id);
    if (!committed || !mounted) return;

    try {
      // The submitted watch entry marks the movie as watched. Only now remove
      // it from the watchlist and update local state.
      await UserService.removeFromWatchlist(user.id, item.movieId);
      await analytics.watchlistItemRemoved(source: 'watchlist');
      await analytics.movieRemovedFromWatchlist();
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
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.success,
            content: Text('${item.movie?.title ?? "Movie"} marked as watched'),
            backgroundColor: FlixieColors.surfaceElevated,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking as watched: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Failed to mark as watched'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _removeFromWatchlist(WatchlistMovie item) async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    if (user == null) return;

    // Check if already in watched list before removing
    final alreadyWatched = user.isMovieWatched(item.movieId);

    try {
      await UserService.removeFromWatchlist(user.id, item.movieId);
      await analytics.watchlistItemRemoved(source: 'watchlist');
      await analytics.movieRemovedFromWatchlist();

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
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.success,
            content:
                Text('${item.movie?.title ?? "Movie"} removed from watchlist'),
          ),
        );
      }

      // If not already in watched list, offer to add it
      if (!alreadyWatched && mounted) {
        final markWatched = await showFlixiePromptSheet<bool>(
          context: context,
          builder: (ctx) => FlixiePromptSheetContent(
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
          final committed = await _confirmWatchEntry(item, user.id);
          if (!committed || !mounted) return;
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
            ScaffoldMessenger.of(context).showFlixieToast(
              FlixieToast(
                type: FlixieToastType.success,
                content: Text(
                    '${item.movie?.title ?? "Movie"} added to watched list'),
                backgroundColor: FlixieColors.surfaceElevated,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Failed to remove from watchlist'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _clearWatchedFromWatchlist() async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    if (user == null) return;
    final watchedIds =
        user.watchedMovies?.map((item) => item.movieId).toSet() ?? <int>{};
    final watchedItems = _allWatchlist
        .where((item) => watchedIds.contains(item.movieId))
        .toList();
    if (watchedItems.isEmpty) return;

    final confirmed = await showFlixiePromptSheet<bool>(
          context: context,
          builder: (dialogContext) => FlixiePromptSheetContent(
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
      await analytics.watchlistItemRemoved(source: 'watchlist');
      await analytics.movieRemovedFromWatchlist();
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
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
          type: FlixieToastType.success,
          content: Text(
            '${watchedItems.length} watched ${watchedItems.length == 1 ? 'movie' : 'movies'} removed from your watchlist',
          ),
          backgroundColor: FlixieColors.surfaceElevated,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
          type: FlixieToastType.error,
          content: const Text('Failed to clear watched movies'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    }
  }

  Future<void> _addToFavorites(WatchlistMovie item) async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    if (user == null) return;

    final movieId = item.movieId;
    if (user.isMovieFavorite(movieId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.info,
            content: Text(
              '${item.movie?.title ?? "Movie"} is already in favourites',
            ),
          ),
        );
      }
      return;
    }

    final activeFavouriteCount =
        (user.favoriteMovies ?? const <FavoriteMovie>[])
            .where((favorite) => favorite.removed != true)
            .length;
    if (activeFavouriteCount >= maxFavouriteMovies) {
      if (mounted) {
        showFavouriteLimitPrompt(
          context,
          type: FavouriteLimitType.movie,
          onSpaceMade: () => _addToFavorites(item),
        );
      }
      return;
    }

    try {
      final addedFavorite = await UserService.addToFavorites(user.id, movieId);
      await analytics.movieFavourited();
      final updatedFavorites =
          List<FavoriteMovie>.from(user.favoriteMovies ?? []);
      if (!updatedFavorites.any((f) => f.movieId == movieId)) {
        updatedFavorites.add(addedFavorite);
      }

      authProvider.updateUserList(favoriteMovies: updatedFavorites);
      authProvider.markActivityChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.success,
            content:
                Text('${item.movie?.title ?? "Movie"} added to favourites'),
            backgroundColor: FlixieColors.surfaceElevated,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
      if (mounted) {
        if (isFavouriteLimitError(e)) {
          showFavouriteLimitPrompt(
            context,
            type: FavouriteLimitType.movie,
            onSpaceMade: () => _addToFavorites(item),
          );
        } else {
          ScaffoldMessenger.of(context).showFlixieToast(
            FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to add to favourites'),
              backgroundColor: FlixieColors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _showAddToListSheet(WatchlistMovie item) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
      useRootNavigator: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
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
            ScaffoldMessenger.of(context).showFlixieToast(
              FlixieToast(
                  type: FlixieToastType.success,
                  content: const Text('Watch Plan sent!')),
            );
          }
        },
        onError: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showFlixieToast(
              FlixieToast(
                  type: FlixieToastType.error,
                  content: const Text('Failed to send Watch Plan')),
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

  Widget _buildStatsRow() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                  '${_allWatchlist.length + _allShowWatchlist.length} saved titles',
                  style: const TextStyle(color: FlixieColors.light)),
              TextButton(
                  onPressed: () => context.push('/watch-history'),
                  child: const Text('Watch history')),
            ]),
      );

  Future<void> _editPreferences() async {
    Navigator.of(context, rootNavigator: true).pop();
    await showSettingsEditDetailsSheet(context);
    if (mounted) _loadWatchlist();
  }

  bool _checkingServices = false;

  Future<void> _toggleServices() async {
    if (_checkingServices) return;
    if (_selectedTab == 1) {
      setState(() => _selectedTab = 0);
      return;
    }
    final auth = context.read<AuthProvider>();
    final user = auth.dbUser;
    if (user == null) return;
    _checkingServices = true;
    try {
      // An empty local availability cache does not mean no saved subscriptions.
      var ids = auth.cachedUserWatchProviderIds;
      if (ids == null) {
        final saved = await UserService.getUserWatchProviders(user.id);
        if (!mounted || auth.dbUser?.id != user.id) return;
        ids = saved.map((provider) => provider.id).toSet();
        auth.updateCachedUserWatchProviderIds(ids);
      }
      if (!mounted) return;
      if (ids.isEmpty) {
        await showModalBottomSheet<void>(
            context: context,
            useRootNavigator: true,
            useSafeArea: true,
            isScrollControlled: true,
            builder: (context) => SizedBox(
                height: MediaQuery.sizeOf(context).height * .85,
                child: WatchProvidersSheet(userId: user.id)));
        if (!mounted || auth.dbUser?.id != user.id) return;
        ids = auth.cachedUserWatchProviderIds ?? const <int>{};
        if (ids.isEmpty) return;
      }
      setState(() {
        _userWatchProviderIds = {...ids!};
        _selectedTab = 1;
      });
      _loadWatchProviderAvailability(_allWatchlist);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t load your services. Please try again.')));
      }
    } finally {
      _checkingServices = false;
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _friendsOnly = false;
      _selectedTab = 0;
      _mediaFilter = 0;
      _filterGenre = null;
      _filterMinRating = null;
      _filterYear = null;
      _filterMaxRuntime = null;
    });
    _filterWatchlist();
  }

  Widget _buildSortFilterRow() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildCheckboxFilter(
                label: 'On my services',
                selected: _selectedTab == 1,
                onChanged: (_) => _toggleServices(),
              ),
              _buildCheckboxFilter(
                label: 'Friends watched',
                selected: _friendsOnly,
                onChanged: (value) {
                  setState(() => _friendsOnly = value);
                  _filterWatchlist();
                },
              ),
              TextButton.icon(
                  onPressed: _openFilterSheet,
                  icon: const Icon(Icons.tune),
                  label: Text(_sortByLabel())),
              PopupMenuButton<int>(
                  tooltip: 'Viewing status',
                  onSelected: (value) => setState(() => _selectedTab = value),
                  itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 0, child: Text('All viewing states')),
                        PopupMenuItem(value: 2, child: Text('Upcoming')),
                        PopupMenuItem(value: 3, child: Text('Watched'))
                      ],
                  child: const SizedBox(
                      width: 44,
                      height: 44,
                      child:
                          Icon(Icons.filter_list, color: FlixieColors.light))),
              IconButton(
                  tooltip: 'Refresh watchlist',
                  onPressed: _refreshWatchlist,
                  icon: const Icon(Icons.refresh_rounded)),
              if (_selectedTab == 3)
                TextButton(
                    onPressed: _clearWatchedFromWatchlist,
                    child: const Text('Clear watched movies')),
              if (_hasActiveFilters || _friendsOnly || _selectedTab != 0)
                TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear filters')),
            ]),
      );

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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: (MediaQuery.textScalerOf(context).scale(30) + 16)
            .clamp(56.0, double.infinity),
        title: const Text('Watchlist',
            style: TextStyle(
                fontFamily: FlixieTypography.fontFamily,
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            tooltip: 'Add movie',
            onPressed: _openAddMovieSheet,
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
    if (_mediaFilter == 2) return const [];
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

  List<_WatchlistShowEntry> _visibleShowWatchlist() {
    if (_mediaFilter == 1) return const [];
    if (_selectedTab == 3) {
      final watched =
          context.read<AuthProvider>().dbUser?.watchedShows ?? const [];
      final ids = watched
          .whereType<Map>()
          .where((w) => w['removed'] != true)
          .map((w) => _watchlistInt(w['showId']))
          .toSet();
      return _filteredShowWatchlist
          .where((item) => item.watched || ids.contains(item.showId))
          .toList();
    }
    if (_selectedTab == 1) {
      return _filteredShowWatchlist.where((item) {
        final providers = _showWatchProviders[item.showId] ?? const [];
        return providers.any(
          (provider) => provider.isIncludedOffer && _isUserProvider(provider),
        );
      }).toList();
    }
    if (_selectedTab == 2) {
      final today = DateTime.now();
      final upcoming = _filteredShowWatchlist.where((item) {
        final date = DateTime.tryParse(item.firstAirDate ?? '');
        return date != null && date.isAfter(today);
      }).toList();
      upcoming.sort((a, b) {
        final dateA = DateTime.tryParse(a.firstAirDate ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(b.firstAirDate ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dateA.compareTo(dateB);
      });
      return upcoming;
    }
    return _filteredShowWatchlist;
  }

  Widget _buildContent() {
    final movieItems = _visibleWatchlist();
    final showItems = _visibleShowWatchlist();
    final items = <Object>[...movieItems, ...showItems];
    if (_mediaFilter == 0) items.sort(_compareWatchlistItems);
    final user = context.read<AuthProvider>().dbUser;
    final hasItems = _allWatchlist.isNotEmpty || _allShowWatchlist.isNotEmpty;

    final header = <Widget>[
      if (_loadError != null)
        TextButton(
            onPressed: _refreshWatchlist, child: Text('$_loadError · Retry')),
      _buildStatsRow(),
      _buildSearchBar(),
      _buildMediaFilter(),
      _buildSortFilterRow(),
      if (_friendsOnly && _loadingFriends)
        const Padding(
            padding: EdgeInsets.all(16), child: Text('Checking friends…')),
      if (_friendsOnly &&
          !_loadingFriends &&
          (_recommendationsByMovieId.length < _allWatchlist.length ||
              _friendsByShowId.length < _allShowWatchlist.length))
        TextButton(
            onPressed: () => _loadFriendRecommendations(_allWatchlist),
            child: const Text('Some friends couldn’t load · Retry')),
      if (_selectedTab == 1 &&
          !_loadingWatchProviderAvailability &&
          !_loadingShowWatchProviderAvailability &&
          (_movieWatchProviders.length < _allWatchlist.length ||
              _showWatchProviders.length < _allShowWatchlist.length))
        TextButton(
            onPressed: () {
              _loadWatchProviderAvailability(_allWatchlist);
              _loadShowWatchProviderAvailability(_allShowWatchlist);
            },
            child: const Text('Some availability couldn’t load · Retry')),
    ];

    if (items.isEmpty) {
      final emptyLabel = switch (_selectedTab) {
        1 => _loadingWatchProviderAvailability ||
                _loadingShowWatchProviderAvailability
            ? 'Checking your providers...'
            : 'Nothing you can watch right now',
        2 => 'No upcoming titles in your watchlist',
        3 => 'No watched movies in your watchlist',
        _ => hasItems || _searchController.text.isNotEmpty
            ? 'No watchlist matches'
            : 'Your watchlist is empty',
      };
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ...header,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
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
                  if (hasItems)
                    TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear filters')),
                  if (_selectedTab == 0 &&
                      _searchController.text.isEmpty &&
                      !hasItems) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Add movies or shows to start building your watchlist',
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
          : const SizedBox(height: 4),
      itemBuilder: (context, index) {
        if (index < header.length) return header[index];

        final item = items[index - header.length];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: item is WatchlistMovie
              ? _buildWatchlistRow(item, user)
              : _buildShowWatchlistRow(item as _WatchlistShowEntry),
        );
      },
    );
  }

  int _compareWatchlistItems(Object first, Object second) {
    final firstTitle = first is WatchlistMovie
        ? first.movie?.title ?? ''
        : (first as _WatchlistShowEntry).title;
    final secondTitle = second is WatchlistMovie
        ? second.movie?.title ?? ''
        : (second as _WatchlistShowEntry).title;
    if (_sortBy == 'titleAsc') return firstTitle.compareTo(secondTitle);
    if (_sortBy == 'titleDesc') return secondTitle.compareTo(firstTitle);

    if (_sortBy == 'ratingDesc' ||
        _sortBy == 'yearAsc' ||
        _sortBy == 'yearDesc') {
      double? value(Object item) {
        if (_sortBy == 'ratingDesc') {
          return item is WatchlistMovie
              ? item.movie?.voteAverage
              : (item as _WatchlistShowEntry).voteAverage;
        }
        final date = item is WatchlistMovie
            ? item.movie?.releaseDate
            : (item as _WatchlistShowEntry).firstAirDate;
        return double.tryParse(date?.split('-').first ?? '');
      }

      final a = value(first), b = value(second);
      if (a == null && b != null) return 1;
      if (b == null && a != null) return -1;
      if (a != null && b != null && a != b) {
        return _sortBy == 'yearAsc' ? a.compareTo(b) : b.compareTo(a);
      }
    }
    final firstAddedAt = DateTime.tryParse(first is WatchlistMovie
            ? first.createdAt ?? ''
            : (first as _WatchlistShowEntry).createdAt ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final secondAddedAt = DateTime.tryParse(second is WatchlistMovie
            ? second.createdAt ?? ''
            : (second as _WatchlistShowEntry).createdAt ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return secondAddedAt.compareTo(firstAddedAt);
  }

  Widget _buildCheckboxFilter({
    required String label,
    required bool selected,
    required ValueChanged<bool> onChanged,
  }) =>
      Semantics(
        label: label,
        checked: selected,
        onTap: () => onChanged(!selected),
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onChanged(!selected),
          borderRadius: BorderRadius.circular(4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IgnorePointer(
                  child: Checkbox(
                    value: selected,
                    onChanged: (value) => onChanged(value ?? false),
                    activeColor: FlixieColors.primary,
                    checkColor: Colors.white,
                    side: const BorderSide(color: FlixieColors.light),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(label,
                        style: TextStyle(
                          fontFamily: FlixieTypography.fontFamily,
                          fontSize: 13,
                          color: selected ? Colors.white : FlixieColors.light,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildMediaFilter() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: FlixieColors.light.withValues(alpha: .2))),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(spacing: 16, children: [
              for (final (index, label) in ['All', 'Movies', 'Shows'].indexed)
                Semantics(
                  selected: _mediaFilter == index,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                        color: _mediaFilter == index
                            ? FlixieColors.primaryText
                            : Colors.transparent,
                        width: 3,
                      )),
                    ),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: _mediaFilter == index
                            ? Colors.white
                            : FlixieColors.light,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 12),
                        shape: const RoundedRectangleBorder(),
                        textStyle: TextStyle(
                          fontFamily: FlixieTypography.fontFamily,
                          fontSize: 15,
                          fontWeight: _mediaFilter == index
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      onPressed: () => setState(() => _mediaFilter = index),
                      child: Text(label),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );

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
      userWatchProviderMatchKeys: _userWatchProviderMatchKeys,
      canWatchNow: canWatchNow,
      isLoadingProviders: isLoadingProviders,
      providersFailed: !isLoadingProviders &&
          !_movieWatchProviders.containsKey(item.movieId),
      region: context.read<AuthProvider>().dbUser?.watchProviderRegion ?? 'GB',
      onEditPreferences: _editPreferences,
      onRetryProviders: () => _loadWatchProviderAvailability(_allWatchlist),
      isLoadingFriends: _loadingFriends &&
          !_recommendationsByMovieId.containsKey(item.movieId),
      friendsFailed: !_loadingFriends &&
          !_recommendationsByMovieId.containsKey(item.movieId),
      onRetryFriends: () => _loadFriendRecommendations(_allWatchlist),
      recommendations: _recommendationsByMovieId[item.movieId] ?? const [],
      onTap: () => context.push(movieDetailPath(
        item.movieId,
        source: DetailSource.watchlist,
      )),
      onMarkAsWatched: () => _markAsWatched(item),
      onAddToFavourites: () => _addToFavorites(item),
      onAddToList: () => _showAddToListSheet(item),
      onRequestToWatch: () => _showWatchRequestSheet(item),
      onRemove: () => _removeFromWatchlist(item),
    );
  }

  Widget _buildShowWatchlistRow(_WatchlistShowEntry item) {
    void details() => context
        .push(showDetailPath(item.showId, source: DetailSource.watchlist));
    return WatchlistMovieRow(
      isShow: true,
      watchlistItem: WatchlistMovie(
          id: 'show-${item.showId}',
          userId: '',
          movieId: item.showId,
          createdAt: item.createdAt,
          movie: WatchlistMovieDetails(
              id: item.showId,
              title: item.title,
              posterPath: item.posterPath,
              releaseDate: item.firstAirDate)),
      metadataOverride: [
        if (item.firstAirDate?.isNotEmpty == true)
          item.firstAirDate!.split('-').first,
        if (item.numberOfSeasons != null)
          '${item.numberOfSeasons} seasons'
        else if (item.numberOfEpisodes != null)
          '${item.numberOfEpisodes} episodes',
        if (item.status?.isNotEmpty == true) item.status!,
        if (item.watched) 'Watched'
      ].join(' · '),
      isWatched: item.watched,
      onTap: details,
      onMarkAsWatched: details,
      onRemove: () => _removeShowFromWatchlist(item),
      availableProviders: _showWatchProviders[item.showId] ?? const [],
      userWatchProviderIds: _userWatchProviderIds,
      userWatchProviderMatchKeys: _userWatchProviderMatchKeys,
      region: context.read<AuthProvider>().dbUser?.watchProviderRegion ?? 'GB',
      isLoadingProviders: _loadingShowWatchProviderAvailability &&
          !_showWatchProviders.containsKey(item.showId),
      providersFailed: !_loadingShowWatchProviderAvailability &&
          !_showWatchProviders.containsKey(item.showId),
      onEditPreferences: _editPreferences,
      onRetryProviders: () =>
          _loadShowWatchProviderAvailability(_allShowWatchlist),
      recommendations: _friendsByShowId[item.showId] ?? const [],
      isLoadingFriends:
          _loadingFriends && !_friendsByShowId.containsKey(item.showId),
      friendsFailed:
          !_loadingFriends && !_friendsByShowId.containsKey(item.showId),
      onRetryFriends: () => _loadFriendRecommendations(_allWatchlist),
    );
  }

  Future<void> _removeShowFromWatchlist(_WatchlistShowEntry item) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.dbUser;
    if (user == null) return;
    try {
      await ShowService.removeFromWatchlist(user.id, item.showId);
      final updated = List<dynamic>.from(user.showWatchlist ?? const [])
        ..removeWhere((entry) {
          if (entry is! Map) return false;
          return _watchlistInt(entry['showId']) == item.showId;
        });
      authProvider.updateUserList(showWatchlist: updated);
      if (!mounted) return;
      setState(
        () => _allShowWatchlist = _allShowWatchlist
            .where((show) => show.showId != item.showId)
            .toList(growable: false),
      );
      _filterWatchlist();
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.success,
            content: Text('${item.title} removed from watchlist')),
      );
    } catch (error) {
      logger.w('[Watchlist] Show removal failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Couldn’t remove show from watchlist'),
            action: SnackBarAction(
                label: 'Retry',
                onPressed: () {
                  if (mounted) _removeShowFromWatchlist(item);
                })),
      );
    }
  }

  bool _isUserProvider(WatchProvider provider) =>
      _userWatchProviderIds.contains(provider.id) ||
      _userWatchProviderMatchKeys.contains(provider.matchKey);
}

class _WatchlistShowEntry {
  const _WatchlistShowEntry({
    required this.showId,
    required this.title,
    required this.removed,
    required this.watched,
    this.posterPath,
    this.firstAirDate,
    this.status,
    this.numberOfEpisodes,
    this.numberOfSeasons,
    this.voteAverage,
    this.runtime,
    this.genres = const [],
    this.createdAt,
  });

  final int showId;
  final String title;
  final bool removed;
  final bool watched;
  final String? posterPath;
  final String? firstAirDate;
  final String? status;
  final int? numberOfEpisodes;
  final int? numberOfSeasons;
  final double? voteAverage;
  final int? runtime;
  final List<String> genres;
  final String? createdAt;

  bool get needsDetails =>
      title == 'TV show' ||
      title.trim().isEmpty ||
      posterPath == null ||
      firstAirDate == null ||
      numberOfSeasons == null;

  _WatchlistShowEntry withShow(TvShow show) => _WatchlistShowEntry.fromJson({
        'showId': showId,
        'removed': removed,
        'watched': watched,
        'createdAt': createdAt,
        'show': show.toJson(),
      });

  factory _WatchlistShowEntry.fromJson(Map<String, dynamic> json) {
    final show = json['show'] is Map
        ? Map<String, dynamic>.from(json['show'] as Map)
        : const <String, dynamic>{};
    return _WatchlistShowEntry(
      showId: _watchlistInt(json['showId']) ?? _watchlistInt(show['id']) ?? 0,
      title: (show['title'] ?? show['name'] ?? 'TV show').toString(),
      removed: json['removed'] == true,
      watched: json['watched'] == true,
      posterPath: (show['posterPath'] ?? show['poster_path'])?.toString(),
      firstAirDate: (show['firstAirDate'] ??
              show['first_air_date'] ??
              show['releaseDate'])
          ?.toString(),
      status: show['status']?.toString(),
      numberOfEpisodes: _watchlistInt(show['numberOfEpisodes']),
      numberOfSeasons:
          _watchlistInt(show['numberOfSeasons'] ?? show['number_of_seasons']),
      voteAverage: double.tryParse('${show['voteAverage'] ?? ''}'),
      runtime: _watchlistInt(show['runtime']),
      genres: (show['genres'] as List? ?? const [])
          .map((g) => g is Map ? '${g['name'] ?? ''}' : '$g')
          .where((g) => g.isNotEmpty)
          .toList(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

int? _watchlistInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
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

class WatchlistMovieRow extends StatelessWidget {
  final bool isShow, isLoadingFriends, friendsFailed, providersFailed;
  final String region;
  final String? metadataOverride;
  final VoidCallback? onRetryFriends, onRetryProviders, onEditPreferences;
  final WatchlistMovie watchlistItem;
  final bool isWatched;
  final List<WatchProvider> availableProviders;
  final Set<int> userWatchProviderIds;
  final Set<String> userWatchProviderMatchKeys;
  final bool canWatchNow;
  final bool isLoadingProviders;
  final List<FriendRecommendationItem> recommendations;
  final VoidCallback onTap;
  final VoidCallback onMarkAsWatched;
  final VoidCallback? onAddToFavourites;
  final VoidCallback? onAddToList;
  final VoidCallback? onRequestToWatch;
  final VoidCallback onRemove;

  const WatchlistMovieRow({
    super.key,
    this.isShow = false,
    this.isLoadingFriends = false,
    this.friendsFailed = false,
    this.providersFailed = false,
    this.region = 'GB',
    this.metadataOverride,
    this.onRetryFriends,
    this.onRetryProviders,
    this.onEditPreferences,
    required this.watchlistItem,
    required this.isWatched,
    this.availableProviders = const <WatchProvider>[],
    this.userWatchProviderIds = const <int>{},
    this.userWatchProviderMatchKeys = const <String>{},
    this.canWatchNow = false,
    this.isLoadingProviders = false,
    this.recommendations = const [],
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
    final metadata = metadataOverride ??
        [
          if (movie.releaseDate?.isNotEmpty == true)
            movie.releaseDate!.split('-').first,
          if (_runtimeLabel(movie.runtime).isNotEmpty)
            _runtimeLabel(movie.runtime),
          ...movie.genres.take(2),
          if (isWatched) 'Watched',
        ].join(' · ');
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(
              label: '${movie.title} poster',
              image: true,
              button: true,
              onTap: onTap,
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 68,
                      height: 102,
                      child: movie.posterPath == null
                          ? const _MoviePosterPlaceholder()
                          : CachedNetworkImage(
                              imageUrl:
                                  'https://image.tmdb.org/t/p/w342${movie.posterPath}',
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  const _MoviePosterPlaceholder(),
                              errorWidget: (_, __, ___) =>
                                  const _MoviePosterPlaceholder(),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: InkWell(
                    onTap: onTap,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(movie.title,
                                style: const TextStyle(
                                    color: FlixieColors.textPrimary,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(metadata,
                                style: const TextStyle(
                                    color: FlixieColors.light, fontSize: 13)),
                            const SizedBox(height: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: FlixieColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(isShow ? 'Show' : 'Movie',
                                  style: const TextStyle(
                                      color: FlixieColors.primaryText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                    ))),
            PopupMenuButton<String>(
              tooltip: 'More actions',
              color: FlixieColors.surfaceElevated,
              onSelected: (value) {
                switch (value) {
                  case 'details':
                    onTap();
                  case 'watched':
                    onMarkAsWatched();
                  case 'favourite':
                    onAddToFavourites?.call();
                  case 'list':
                    onAddToList?.call();
                  case 'request_watch':
                    onRequestToWatch?.call();
                  case 'remove':
                    onRemove();
                }
              },
              itemBuilder: (_) => [
                if (_formatDate(watchlistItem.createdAt).isNotEmpty)
                  PopupMenuItem<String>(
                      enabled: false,
                      child: Text(
                          'Added ${_formatDate(watchlistItem.createdAt)}')),
                const PopupMenuItem(
                    value: 'details', child: Text('Title details')),
                PopupMenuItem(
                    value: 'watched',
                    child: Text(isShow
                        ? 'Manage episodes & watched status'
                        : 'Mark as Watched')),
                if (!isShow || onAddToFavourites != null)
                  const PopupMenuItem(
                      value: 'favourite', child: Text('Add to favourites')),
                if (!isShow || onAddToList != null)
                  const PopupMenuItem(
                      value: 'list', child: Text('Add to list')),
                if (!isShow || onRequestToWatch != null)
                  const PopupMenuItem(
                      value: 'request_watch', child: Text('Invite friends')),
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
              child: Semantics(
                  label: 'Actions for ${movie.title}',
                  button: true,
                  child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.more_horiz_rounded,
                          color: FlixieColors.light))),
            ),
          ]),
          const SizedBox(height: 8),
          _FriendsViewing(
              friends: recommendations,
              title: movie.title,
              isShow: isShow,
              loading: isLoadingFriends,
              failed: friendsFailed,
              onRetry: onRetryFriends),
          _WatchProvidersInline(
              providers: availableProviders,
              userWatchProviderIds: userWatchProviderIds,
              userWatchProviderMatchKeys: userWatchProviderMatchKeys,
              isLoading: isLoadingProviders,
              failed: providersFailed,
              region: region,
              onRetry: onRetryProviders,
              onEditPreferences: onEditPreferences),
          const SizedBox(height: 12),
          const Divider(height: 1, color: FlixieColors.tabBarBorder),
        ]),
      ),
    );
  }
}

Future<void> _watchlistDetailSheet(
    BuildContext context, String title, List<Widget> children) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: FlixieColors.surface,
    builder: (context) => ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
      child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: FlixieColors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700))),
              IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close))
            ]),
            ...children,
          ]),
    ),
  );
}

class _FriendsViewing extends StatelessWidget {
  const _FriendsViewing(
      {required this.friends,
      required this.title,
      this.isShow = false,
      this.loading = false,
      this.failed = false,
      this.onRetry});
  final List<FriendRecommendationItem> friends;
  final String title;
  final bool isShow, loading, failed;
  final VoidCallback? onRetry;

  Widget _avatar(FriendRecommendationItem friend) => SizedBox(
      width: 44,
      height: 44,
      child: Center(
          child: ProfileAvatarView(
              avatar: friend.avatar ??
                  (friend.avatarUrl?.isNotEmpty == true
                      ? ProfileAvatar(
                          id: 0,
                          key: friend.userId,
                          displayName: friend.username,
                          storagePath: '',
                          imageUrl: friend.avatarUrl)
                      : null),
              profileBadges: friend.profileBadges,
              fallbackText: friend.username.isEmpty
                  ? '?'
                  : friend.username.characters.first.toUpperCase(),
              fallbackColor: FlixieColors.primary,
              size: 32)));

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Checking friends…',
              style: TextStyle(color: FlixieColors.light)));
    }
    if (failed) {
      return TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Friends couldn’t load · Retry'));
    }
    final watched = friends.where((f) => f.watched).toList();
    final rated = friends
        .where((f) =>
            f.rating != null && f.ratingScope == (isShow ? 'show' : 'movie'))
        .toList();
    final average = rated.isEmpty
        ? null
        : rated.fold<double>(0, (sum, f) => sum + f.rating!) / rated.length;
    final summary =
        '${watched.length} ${watched.length == 1 ? 'friend' : 'friends'} watched';
    final ratingLabel = average == null
        ? 'No friends’ ratings yet'
        : 'Friends’ average ${average.toStringAsFixed(1)}/10 · ${rated.length} rated';
    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: FlixieColors.background,
        builder: (sheetContext) => ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Friends who watched',
                            style: TextStyle(
                                fontFamily: FlixieTypography.fontFamily,
                                color: FlixieColors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800))),
                    IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon:
                            const Icon(Icons.close, color: FlixieColors.light)),
                  ]),
                  Text(
                      '$title · ${watched.length} watched · ${rated.length} rated',
                      style: const TextStyle(
                          color: FlixieColors.light, fontSize: 13)),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: FlixieColors.tabBarBorder),
                  if (friends.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No friends watched yet',
                            style: TextStyle(color: FlixieColors.light))),
                  for (final friend in friends) ...[
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: LayoutBuilder(builder: (context, constraints) {
                          final scope = friend.ratingScope.isEmpty
                              ? (isShow ? 'show' : 'movie')
                              : friend.ratingScope;
                          final scopeLabel =
                              '${scope[0].toUpperCase()}${scope.substring(1)} rating';
                          final state =
                              friend.watched ? 'Watched' : 'Not marked watched';
                          final details = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    friend.displayName?.trim().isNotEmpty ==
                                            true
                                        ? friend.displayName!
                                        : friend.username,
                                    style: const TextStyle(
                                        color: FlixieColors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 3),
                                Text(
                                    '$state · ${friend.rating == null ? 'Not rated yet' : scopeLabel}',
                                    style: const TextStyle(
                                        color: FlixieColors.light,
                                        fontSize: 13)),
                              ]);
                          final rating = Text(
                              friend.rating == null
                                  ? '—'
                                  : '${friend.rating! == friend.rating!.roundToDouble() ? friend.rating!.toInt() : friend.rating}/10',
                              style: TextStyle(
                                  color: friend.rating == null
                                      ? FlixieColors.light
                                      : FlixieColors.warning,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800));
                          final stacked = constraints.maxWidth < 360 &&
                              MediaQuery.textScalerOf(context).scale(16) > 24;
                          return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _avatar(friend),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: stacked
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                                details,
                                                const SizedBox(height: 6),
                                                rating
                                              ])
                                        : details),
                                if (!stacked) ...[
                                  const SizedBox(width: 12),
                                  rating
                                ],
                              ]);
                        })),
                    const Divider(height: 1, color: FlixieColors.tabBarBorder),
                  ],
                  const SizedBox(height: 16),
                  Text(
                      average == null
                          ? 'No friends’ ratings yet'
                          : 'Friends’ average ${average.toStringAsFixed(1)}/10 · Based on ${rated.length} ${rated.length == 1 ? 'rating' : 'ratings'}',
                      style: const TextStyle(
                          color: FlixieColors.light, fontSize: 13)),
                  if (isShow) ...[
                    const SizedBox(height: 8),
                    const Text(
                        'Show-level ratings only. Season and episode ratings are separate. Watched means marked watched, not necessarily every episode completed.',
                        style:
                            TextStyle(color: FlixieColors.light, fontSize: 12)),
                  ],
                ]),
          ),
        ),
      ),
      child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LayoutBuilder(builder: (context, constraints) {
              final avatars =
                  Wrap(children: watched.take(3).map(_avatar).toList());
              final text = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(watched.isEmpty ? 'No friends watched yet' : summary,
                        style: const TextStyle(
                            color: FlixieColors.white, fontSize: 13)),
                    Text(ratingLabel,
                        style: const TextStyle(
                            color: FlixieColors.light, fontSize: 12)),
                  ]);
              if (constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20) {
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [if (watched.isNotEmpty) avatars, text]);
              }
              return Row(children: [
                if (watched.isNotEmpty) ...[avatars, const SizedBox(width: 8)],
                Expanded(child: text),
                const Icon(Icons.chevron_right, color: FlixieColors.light)
              ]);
            }),
          )),
    );
  }
}

class _WatchProvidersInline extends StatelessWidget {
  const _WatchProvidersInline(
      {required this.providers,
      required this.userWatchProviderIds,
      required this.userWatchProviderMatchKeys,
      required this.isLoading,
      this.failed = false,
      this.region = 'GB',
      this.onEditPreferences,
      this.onRetry});
  final List<WatchProvider> providers;
  final Set<int> userWatchProviderIds;
  final Set<String> userWatchProviderMatchKeys;
  final bool isLoading, failed;
  final String region;
  final VoidCallback? onRetry, onEditPreferences;

  bool _included(WatchProvider p) =>
      p.isIncludedOffer &&
      (p.isFree ||
          userWatchProviderIds.contains(p.id) ||
          userWatchProviderMatchKeys.contains(p.matchKey));
  String _label(WatchProvider p) => [
        if (p.isIncludedOffer)
          p.isFree
              ? 'Included · Free${p.availabilityTypes.contains('ads') ? ' with ads' : ''}'
              : _included(p)
                  ? 'Included'
                  : 'Subscription',
        if (p.isRental) 'Rent',
        if (p.isPurchase) 'Buy',
        if (!p.hasExplicitAvailabilityType) 'Availability unconfirmed',
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Checking availability…',
              style: TextStyle(color: FlixieColors.light)));
    }
    if (failed) {
      return TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Availability couldn’t load · Retry'));
    }
    final canStream = providers.any(_included);
    final streamIcon = Icon(
      Icons.play_arrow_outlined,
      size: 18,
      color: canStream ? const Color(0xFF9FE3C5) : FlixieColors.danger,
      semanticLabel: canStream
          ? 'Streaming available to you'
          : 'No streaming option on your services',
    );
    final sorted = [...providers]..sort((a, b) {
        if (_included(a) != _included(b)) return _included(a) ? -1 : 1;
        return a.displayPriority.compareTo(b.displayPriority);
      });
    const labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
    const optionsStyle = TextStyle(color: FlixieColors.light, fontSize: 12);
    Widget logo(WatchProvider provider) => Tooltip(
          message: '${provider.providerName} · ${_label(provider)}',
          excludeFromSemantics: true,
          child: Semantics(
            image: true,
            label: '${provider.providerName} · ${_label(provider)}',
            child: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: userWatchProviderIds.contains(provider.id) ||
                          userWatchProviderMatchKeys.contains(provider.matchKey)
                      ? const Color(0xFF9FE3C5)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: provider.logoPath.isEmpty
                    ? const _ProviderLogoFallback()
                    : CachedNetworkImage(
                        imageUrl: provider.logoUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const _ProviderLogoFallback(),
                        errorWidget: (_, __, ___) =>
                            const _ProviderLogoFallback(),
                      ),
              ),
            ),
          ),
        );
    final grouped = <String, WatchProvider>{};
    for (final provider in sorted) {
      final key = '${provider.id}:${provider.providerName}';
      final previous = grouped[key];
      grouped[key] = previous == null
          ? provider
          : WatchProvider(
              id: previous.id,
              providerName: previous.providerName,
              displayPriority: previous.displayPriority,
              logoPath: previous.logoPath,
              tvShows: previous.tvShows,
              movies: previous.movies,
              isVisible: previous.isVisible,
              supportsGb: previous.supportsGb,
              supportsUs: previous.supportsUs,
              watchUrl: previous.verifiedWatchUri != null
                  ? previous.watchUrl
                  : provider.watchUrl,
              availabilityTypes: {
                ...previous.availabilityTypes,
                ...provider.availabilityTypes
              },
            );
    }
    final offers = grouped.values.toList();
    final countryName = switch (region) {
      'GB' => 'United Kingdom',
      'US' => 'United States',
      _ => region,
    };
    Future<void> openProvider(WatchProvider provider) async {
      try {
        final opened = await launchUrl(provider.verifiedWatchUri!,
            mode: LaunchMode.externalApplication);
        if (opened) return;
      } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t open watch options. Try again.')));
      }
    }

    void openOptions() => _watchlistDetailSheet(context, 'Where to watch', [
          Row(children: [
            const Icon(Icons.location_on_outlined,
                size: 18, color: FlixieColors.light),
            const SizedBox(width: 8),
            Expanded(
                child: Text(countryName,
                    style: const TextStyle(
                        color: FlixieColors.white, fontSize: 14))),
            if (onEditPreferences != null)
              TextButton(
                  onPressed: onEditPreferences, child: const Text('Change')),
          ]),
          const SizedBox(height: 12),
          if (offers.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No providers found in this country.',
                    style: TextStyle(color: FlixieColors.light))),
          for (final provider in offers) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                logo(provider),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(provider.providerName,
                          style: const TextStyle(
                              color: FlixieColors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(_label(provider),
                          style: TextStyle(
                              fontSize: 13,
                              color: _included(provider)
                                  ? const Color(0xFF9FE3C5)
                                  : FlixieColors.light)),
                      if (provider.isAddOn && provider.isIncludedOffer) ...[
                        const SizedBox(height: 4),
                        const Text('Separate add-on subscription',
                            style: TextStyle(
                                color: FlixieColors.light, fontSize: 12)),
                      ],
                    ])),
                if (provider.verifiedWatchUri != null)
                  IconButton(
                      tooltip: 'View ${provider.providerName} watch options',
                      onPressed: () => openProvider(provider),
                      icon: const Icon(Icons.open_in_new,
                          size: 20, color: FlixieColors.primaryText)),
              ]),
            ),
            const Divider(height: 1, color: FlixieColors.tabBarBorder),
          ],
          const SizedBox(height: 20),
          const Text(
              'Availability via TMDB / JustWatch. Confirm prices and plans with the service.',
              style: TextStyle(color: FlixieColors.light, fontSize: 12)),
        ]);
    return Semantics(
      button: true,
      label: 'All watch options',
      child: InkWell(
        onTap: openOptions,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LayoutBuilder(builder: (context, constraints) {
              double textWidth(String text, TextStyle style) {
                final painter = TextPainter(
                  text: TextSpan(
                      text: text,
                      style: DefaultTextStyle.of(context).style.merge(style)),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout();
                final width = painter.width.ceilToDouble();
                painter.dispose();
                return width;
              }

              String heading(int count) {
                if (sorted.isEmpty) return 'No providers found';
                final firstLabel = _label(sorted.first);
                return sorted.take(count).every((p) => _label(p) == firstLabel)
                    ? firstLabel
                    : 'Watch on';
              }

              String remaining(int count) => count < sorted.length
                  ? '+${sorted.length - count} options'
                  : 'View options';

              // Measure the actual labels at the current text scale, reserving
              // the overflow count before choosing how many logos can fit.
              var visibleCount = 0;
              for (var count = 1; count <= sorted.length; count++) {
                final width = 26 +
                    textWidth(heading(count), labelStyle) +
                    8 +
                    count * 40 +
                    (count - 1) * 7 +
                    12 +
                    textWidth(remaining(count), optionsStyle);
                if (width <= constraints.maxWidth) {
                  visibleCount = count;
                }
              }
              final stacked = visibleCount == 0;
              if (stacked && sorted.isNotEmpty) {
                visibleCount = 1;
                for (var count = 1; count <= sorted.length; count++) {
                  if (count * 40 +
                          (count - 1) * 7 +
                          12 +
                          textWidth(remaining(count), optionsStyle) <=
                      constraints.maxWidth) {
                    visibleCount = count;
                  }
                }
              }
              final label = heading(visibleCount);
              final title = Text(label,
                  style: labelStyle.copyWith(
                    color: label.startsWith('Included')
                        ? const Color(0xFF9FE3C5)
                        : FlixieColors.light,
                  ));
              final logos = sorted.take(visibleCount).map(logo).toList();
              final more = Text(remaining(visibleCount), style: optionsStyle);
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      streamIcon,
                      const SizedBox(width: 8),
                      Expanded(child: title),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 7,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [...logos, more]),
                  ],
                );
              }
              return Row(children: [
                streamIcon,
                const SizedBox(width: 8),
                title,
                const SizedBox(width: 8),
                for (var i = 0; i < logos.length; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  logos[i],
                ],
                const Spacer(),
                const SizedBox(width: 12),
                more,
              ]);
            }),
          ),
        ),
      ),
    );
  }
}

class _ProviderLogoFallback extends StatelessWidget {
  const _ProviderLogoFallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: FlixieColors.surfaceElevated,
        child: Icon(Icons.tv_rounded, size: 18, color: FlixieColors.light),
      );
}
