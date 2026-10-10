import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/watchlist/domain/release_status.dart';
import 'package:flixie_app/features/watchlist/domain/tonight_filters.dart';
import 'package:flixie_app/models/friend_recommendation.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/watchlist_movie.dart';

import '../../data/watchlist_data_service.dart';
import '../../models/watchlist_filters.dart';
import '../../models/watchlist_show_entry.dart';
import '../watchlist_selection.dart';

/// Owns Watchlist data, filtering and bounded visible-card enrichment.
/// The screen owns navigation, sheets and Flutter text/scroll controllers.
class WatchlistController extends ChangeNotifier {
  WatchlistController({
    required AuthProvider auth,
    WatchlistDataService? service,
    required void Function(VoidCallback) scheduleAfterFrame,
  })  : _auth = auth,
        _service = service ?? const WatchlistDataService(),
        _scheduleAfterFrame = scheduleAfterFrame;

  AuthProvider _auth;
  final WatchlistDataService _service;
  final void Function(VoidCallback) _scheduleAfterFrame;
  WatchlistFilters _filters = WatchlistFilters();
  WatchlistFilters get filters => WatchlistFilters.copy(_filters);
  String _searchQuery = '';
  String get searchQuery => _searchQuery;
  bool _disposed = false;
  int _changeDepth = 0;
  WatchlistSelection? _selectionCache;

  void _change(VoidCallback action) {
    if (_disposed) return;
    _selectionCache = null;
    _changeDepth++;
    try {
      action();
    } finally {
      _changeDepth--;
      if (_changeDepth == 0) notifyListeners();
    }
  }

  void updateFilters(void Function(WatchlistFilters) update) {
    final updated = WatchlistFilters.copy(_filters);
    update(updated);
    _filters = WatchlistFilters.copy(updated);
    filterWatchlist();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    filterWatchlist();
  }

  @override
  void dispose() {
    _disposed = true;
    _experienceGeneration++;
    _showDetailsRequest++;
    resetEnrichment();
    super.dispose();
  }

  void bindAuth(AuthProvider auth) {
    _auth = auth;
    loadWatchlist();
  }

  void retryExperience() {
    _experienceRequestKey = null;
    filterWatchlist();
  }

  void setProviders(
      List<WatchProvider> catalog, Set<int> ids, bool enabled, bool rentals) {
    _searchProviders = List.of(catalog);
    updateFilters((filters) {
      filters.providerIds = {...ids};
      filters.servicesOnly = enabled;
      filters.includeRentals = rentals;
      if (filters.tab == 1) filters.tab = 0;
    });
  }

  void addMovie(WatchlistMovie item) {
    _allWatchlist.removeWhere((entry) => entry.movieId == item.movieId);
    _allWatchlist.add(item);
    filterWatchlist();
    retryEnrichment(item);
  }

  void removeMovies(Set<int> ids) {
    _allWatchlist.removeWhere((item) => ids.contains(item.movieId));
    filterWatchlist();
  }

  void removeShow(int id) {
    _allShowWatchlist =
        _allShowWatchlist.where((item) => item.showId != id).toList();
    filterWatchlist();
  }

  List<WatchlistShowEntry> get allShowWatchlist =>
      UnmodifiableListView(_allShowWatchlist);
  List<WatchlistMovie> get allWatchlist => UnmodifiableListView(_allWatchlist);
  Set<String> get completedEnrichment =>
      UnmodifiableSetView(_completedEnrichment);
  String? get experienceError => _experienceError;
  Map<String, ExperienceFit> get experienceFits =>
      UnmodifiableMapView(_experienceFits);
  bool get experienceLoading => _experienceLoading;
  String? get experienceMessage => _experienceMessage;
  String? get experienceRequestKey => _experienceRequestKey;
  Map<int, List<FriendRecommendationItem>> get friendsByShowId =>
      UnmodifiableMapView(_friendsByShowId);
  bool get hasUncheckedExclusions => _hasUncheckedExclusions;
  String? get loadError => _loadError;
  bool get loading => _loading;
  bool get loadingFriends => _loadingFriends;
  bool get loadingShowWatchProviderAvailability =>
      _loadingShowWatchProviderAvailability;
  bool get loadingWatchProviderAvailability =>
      _loadingWatchProviderAvailability;
  Map<int, List<WatchProvider>> get movieWatchProviders =>
      UnmodifiableMapView(_movieWatchProviders);
  Map<int, List<FriendRecommendationItem>> get recommendationsByMovieId =>
      UnmodifiableMapView(_recommendationsByMovieId);
  List<WatchProvider> get savedProviders =>
      UnmodifiableListView(_savedProviders);
  List<WatchProvider> get searchProviders =>
      UnmodifiableListView(_searchProviders);
  Map<int, List<WatchProvider>> get showWatchProviders =>
      UnmodifiableMapView(_showWatchProviders);
  Set<int> get userWatchProviderIds =>
      UnmodifiableSetView(_userWatchProviderIds);
  Set<String> get userWatchProviderMatchKeys =>
      UnmodifiableSetView(_userWatchProviderMatchKeys);

  List<WatchlistMovie> _allWatchlist = [];
  List<WatchlistShowEntry> _allShowWatchlist = [];
  bool _loading = true;
  String? _loadError;

  String? _experienceMessage;
  bool _hasUncheckedExclusions = false;
  bool _experienceLoading = false;
  String? _experienceError, _experienceRequestKey;
  int _experienceGeneration = 0;
  final Map<String, ExperienceFit> _experienceFits = {};
  bool get usesExperience =>
      _filters.findingToday ||
      _filters.mood != WatchlistMood.any ||
      _filters.avoid.isNotEmpty ||
      _filters.request.isNotEmpty;
  String experienceKey(Object item) => item is WatchlistMovie
      ? 'movie:${item.movieId}'
      : 'show:${(item as WatchlistShowEntry).showId}';
  bool _fitsExperience(String key) =>
      !usesExperience || (_experienceFits[key]?.eligible ?? false);

  Future<void> _loadExperience(String requestKey) async {
    if (_disposed || !usesExperience || requestKey != _experienceRequestKey) {
      return;
    }
    final generation = ++_experienceGeneration;
    _change(() {
      _experienceLoading = true;
      _experienceError = null;
      _experienceFits.clear();
    });
    final titles = <Map<String, dynamic>>[
      for (final item in _allWatchlist)
        {'id': item.movieId, 'mediaType': 'movie'},
      for (final item in _allShowWatchlist)
        {'id': item.showId, 'mediaType': 'show'},
    ];
    final preferences = {
      'mood': _filters.mood.id,
      'avoid': _filters.avoid.toList(),
      'request': _filters.request,
      'includePossible': true,
      'includeUnknownContent': false
    };
    final fits = <String, ExperienceFit>{};
    String? message;
    var unchecked = false;
    try {
      for (var i = 0; i < titles.length; i += 25) {
        final data = await _service.getExperienceFits(body: {
          ...preferences,
          'titles': titles.sublist(i, min(i + 25, titles.length))
        });
        if (_disposed ||
            generation != _experienceGeneration ||
            requestKey != _experienceRequestKey) {
          return;
        }
        message = data['message'] as String?;
        for (final row in data['results'] as List) {
          unchecked |= (row['unknownAvoids'] as List? ?? []).isNotEmpty;
          fits['${row['mediaType']}:${row['id']}'] =
              ExperienceFit.fromJson(Map<String, dynamic>.from(row));
        }
      }
      if (_disposed || generation != _experienceGeneration) return;
      _change(() {
        _experienceMessage = message;
        _hasUncheckedExclusions = unchecked;
        _experienceFits.addAll(fits);
        _experienceLoading = false;
      });
    } catch (_) {
      if (_disposed || generation != _experienceGeneration) return;
      _change(() {
        _experienceLoading = false;
        _experienceError =
            'Couldn’t find your picks right now. Your choices are saved.';
      });
    }
    filterWatchlist();
  }

  List<WatchProvider> _savedProviders = [];
  List<WatchProvider> _searchProviders = [];

  bool _matchesTonightServices(List<WatchProvider> offers) {
    if (!_filters.servicesOnly) return true;
    final ids = _filters.providerIds ?? _userWatchProviderIds;
    return matchesWatchServices(offers,
        selectedIds: ids,
        selectedNames: [..._savedProviders, ..._searchProviders]
            .where((p) => ids.contains(p.id))
            .map((p) => p.matchKey)
            .toSet(),
        includeRentals: _filters.includeRentals);
  }

  // Active filters

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
  final Map<int, List<FriendRecommendationItem>> _friendsByShowId = {};

  String? _watchlistSnapshot;
  String? _recommendationSnapshot;
  String? _subscriptionSnapshot;
  bool _refreshing = false;
  final Map<String, Object> _pendingEnrichment = {};
  final Set<String> _scheduledEnrichment = {};
  final Set<String> _completedEnrichment = {};
  final Set<String> _inFlightEnrichment = {};
  bool get hasPendingEnrichment =>
      _scheduledEnrichment.any((key) => !_completedEnrichment.contains(key));
  bool _enrichmentRunning = false;
  int _enrichmentGeneration = 0;
  String? _enrichmentView;
  String? _enrichmentOwner;

  void resetEnrichment() {
    _enrichmentGeneration++;
    _pendingEnrichment.clear();
    _scheduledEnrichment.clear();
    _completedEnrichment.clear();
    ++_recommendationsRequest;
    ++_watchProviderAvailabilityRequest;
    ++_showProvidersRequest;
  }

  void scheduleEnrichment(Iterable<Object> items) {
    final fresh = items
        .where((item) => _scheduledEnrichment.add(experienceKey(item)))
        .toList();
    if (fresh.isEmpty) return;
    final generation = _enrichmentGeneration;
    _scheduleAfterFrame(() {
      if (_disposed || generation != _enrichmentGeneration) return;
      final previouslyQueued = Map<String, Object>.of(_pendingEnrichment);
      _pendingEnrichment.clear();
      for (final item in fresh) {
        _pendingEnrichment[experienceKey(item)] = item;
      }
      _pendingEnrichment.addAll(previouslyQueued);
      _drainEnrichment();
    });
  }

  Future<void> _drainEnrichment() async {
    if (_enrichmentRunning) return;
    _enrichmentRunning = true;
    try {
      while (!_disposed && _pendingEnrichment.isNotEmpty) {
        final generation = _enrichmentGeneration;
        final batch = _pendingEnrichment.values.take(20).toList();
        for (final item in batch) {
          _pendingEnrichment.remove(experienceKey(item));
        }
        _inFlightEnrichment.addAll(batch.map(experienceKey));
        final movies = batch.whereType<WatchlistMovie>().toList();
        final shows = batch.whereType<WatchlistShowEntry>().toList();
        await Future.wait([
          if (movies.isNotEmpty) _loadWatchProviderAvailability(movies),
          if (shows.isNotEmpty) _loadShowWatchProviderAvailability(shows),
          _loadFriendRecommendations(movies, shows: shows),
        ]);
        _inFlightEnrichment.removeAll(batch.map(experienceKey));
        if (!_disposed && generation == _enrichmentGeneration) {
          _change(() => _completedEnrichment.addAll(batch.map(experienceKey)));
        }
      }
    } finally {
      _enrichmentRunning = false;
    }
  }

  void retryEnrichment(Object item) {
    final key = experienceKey(item);
    _scheduledEnrichment.remove(key);
    _completedEnrichment.remove(key);
    scheduleEnrichment([item]);
    _change(() {});
  }

  void onUserChanged() {
    if (_disposed || _refreshing) return;
    final auth = _auth;
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
        filterWatchlist();
      }
    }
    // Shared availability is published in bounded batches. Paint completed
    // cards immediately instead of waiting for the entire library.
    final cachedProviders = auth.cachedWatchProvidersByMovieId;
    var providersChanged = false;
    for (final item in _allWatchlist) {
      final providers = cachedProviders[item.movieId];
      if (providers != null &&
          !identical(_movieWatchProviders[item.movieId], providers)) {
        _movieWatchProviders[item.movieId] = providers;
        _canWatchNowByMovieId.remove(item.movieId);
        providersChanged = true;
      }
    }
    if (providersChanged) filterWatchlist();
    if (_listSnapshot(auth) != _watchlistSnapshot) {
      loadWatchlist();
    } else if (_friendSnapshot(auth) != _recommendationSnapshot) {
      _recommendationSnapshot = _friendSnapshot(auth);
      _recommendationsByMovieId.clear();
      _friendsByShowId.clear();
      resetEnrichment();
      filterWatchlist();
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

  Future<void> refreshWatchlist() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await _auth.refreshUserData();
      if (!_disposed) {
        _experienceRequestKey = null;
        loadWatchlist();
      }
    } catch (_) {
      if (!_disposed) {
        _change(() => _loadError = 'Couldn’t refresh your watchlist');
      }
    } finally {
      _refreshing = false;
    }
  }

  void loadWatchlist() {
    final detailsRequest = ++_showDetailsRequest;
    resetEnrichment();
    final authProvider = _auth;
    _loadError = null;
    final owner =
        '${authProvider.dbUser?.id}:${authProvider.dbUser?.watchProviderRegion}';
    if (_enrichmentOwner != owner) {
      _enrichmentOwner = owner;
      _movieWatchProviders.clear();
      _showWatchProviders.clear();
      _canWatchNowByMovieId.clear();
      _userWatchProviderIds = {};
      _userWatchProviderMatchKeys = {};
      _savedProviders = [];
    }
    if (_recommendationSnapshot != _friendSnapshot(authProvider)) {
      _recommendationSnapshot = _friendSnapshot(authProvider);
      _recommendationsByMovieId.clear();
      _friendsByShowId.clear();
    }
    _watchlistSnapshot = _listSnapshot(authProvider);
    final userWatchlist = authProvider.dbUser?.movieWatchlist;
    final userShowWatchlist = authProvider.dbUser?.showWatchlist;

    if (userWatchlist == null && userShowWatchlist == null) {
      ++_recommendationsRequest;
      _change(() {
        _allWatchlist = [];
        _allShowWatchlist = [];
        _recommendationsByMovieId.clear();
        _friendsByShowId.clear();
        _movieWatchProviders.clear();
        _showWatchProviders.clear();
        ++_showProvidersRequest;
        ++_watchProviderAvailabilityRequest;
        filterWatchlist();
        _loading = false;
      });
      return;
    }

    try {
      // The list is already typed - just filter out removed entries
      final watchlist = (userWatchlist ?? const <WatchlistMovie>[])
          .where((item) => item.removed != true)
          .toList();
      for (final entry in (userShowWatchlist ?? const []).whereType<Map>()) {
        final id = int.tryParse('${entry['showId']}');
        final summary = id == null ? null : _service.cachedShow(id);
        if (summary != null) _showDetails[id!] = summary;
      }
      final showWatchlist = (userShowWatchlist ?? const [])
          .whereType<Map>()
          .map((item) => WatchlistShowEntry.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((item) => !item.removed && item.showId > 0)
          .map((item) =>
              item.needsDetails && _showDetails.containsKey(item.showId)
                  ? item.withShow(_showDetails[item.showId]!)
                  : item)
          .toList(growable: false);

      _change(() {
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
        filterWatchlist();
        _loading = false;
      });

      _loadMissingShowDetails(showWatchlist, detailsRequest);
    } catch (e) {
      debugPrint('Error loading watchlist: $e');
      _change(() {
        _loading = false;
        _loadError = 'Couldn’t load your watchlist';
      });
    }
  }

  Future<void> _loadFriendRecommendations(List<WatchlistMovie> watchlist,
      {List<WatchlistShowEntry>? shows}) async {
    final request = ++_recommendationsRequest;
    final snapshot = _friendSnapshot(_auth);
    if (snapshot != _recommendationSnapshot) {
      // Do not display a previous viewer's or former friend's recommendation.
      _recommendationsByMovieId.clear();
      _friendsByShowId.clear();
    }
    _recommendationSnapshot = snapshot;
    // Drop removed films immediately, including while another batch is in flight.
    final ids = watchlist.map((item) => item.movieId).toSet();
    _change(() => _recommendationsByMovieId.removeWhere(
        (id, _) => !_allWatchlist.any((item) => item.movieId == id)));
    final showIds =
        (shows ?? _allShowWatchlist).map((item) => item.showId).toSet();
    _change(() {
      _loadingFriends = true;
      _friendsByShowId.removeWhere(
          (id, _) => !_allShowWatchlist.any((item) => item.showId == id));
    });
    bool current() => !_disposed && request == _recommendationsRequest;
    Future<Map<int, FriendRecommendationResponse>> safe(
        Future<Map<int, FriendRecommendationResponse>> future) async {
      try {
        return await future;
      } catch (_) {
        return {};
      }
    }

    void publish(Map<int, FriendRecommendationResponse> results,
        Map<int, List<FriendRecommendationItem>> target) {
      if (!current()) return;
      _change(() {
        target.addEntries(
            results.entries.map((e) => MapEntry(e.key, e.value.friends)));
      });
      filterWatchlist();
    }

    await Future.wait([
      safe(_service.getMovieFriends(ids,
          isCurrent: current,
          onProgress: (results) =>
              publish(results, _recommendationsByMovieId))),
      safe(_service.getShowFriends(showIds,
          isCurrent: current,
          onProgress: (results) => publish(results, _friendsByShowId))),
    ]);
    if (!current()) return;
    _change(() => _loadingFriends = false);
    filterWatchlist();
  }

  Future<void> _loadWatchProviderAvailability(
      List<WatchlistMovie> watchlist) async {
    final requestId = ++_watchProviderAvailabilityRequest;
    final authProvider = _auth;
    final user = authProvider.dbUser;
    if (user == null) {
      if (!_disposed) {
        _change(() {
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
      _change(() {
        _movieWatchProviders.addEntries(movieIds
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
      final savedProviders = await _service
          .getSavedProviders(user.id)
          .catchError((_) => _savedProviders);

      if (_disposed || requestId != _watchProviderAvailabilityRequest) return;

      final providers = authProvider.cachedWatchProvidersByMovieId;
      final userProviderIds =
          authProvider.cachedUserWatchProviderIds ?? const <int>{};
      _change(() {
        _userWatchProviderIds = {
          ...userProviderIds,
        };
        _savedProviders = savedProviders;
        _userWatchProviderMatchKeys = savedProviders
            .where((provider) => _userWatchProviderIds.contains(provider.id))
            .map((provider) => provider.matchKey)
            .toSet();
        _movieWatchProviders.addEntries(movieIds
            .where(providers.containsKey)
            .map((id) => MapEntry(id, providers[id]!)));
        _canWatchNowByMovieId
            .addEntries(_movieWatchProviders.entries.map((entry) => MapEntry(
                  entry.key,
                  entry.value.any((provider) =>
                      provider.isIncludedOffer && _isUserProvider(provider)),
                )));
        _loadingWatchProviderAvailability = false;
      });

      filterWatchlist();
    } catch (e) {
      debugPrint('Error loading watch provider availability: $e');
      if (_disposed || requestId != _watchProviderAvailabilityRequest) return;
      _change(() => _loadingWatchProviderAvailability = false);
    }
  }

  Future<void> _loadMissingShowDetails(
      List<WatchlistShowEntry> entries, int request) async {
    final ids = entries
        .where((entry) =>
            entry.needsDetails && !_showDetails.containsKey(entry.showId))
        .map((entry) => entry.showId)
        .toSet()
        .toList();
    for (var start = 0; start < ids.length; start += 25) {
      if (_disposed || request != _showDetailsRequest) return;
      final chunk = ids.skip(start).take(25).toList();
      var shows = <TvShow>[];
      try {
        shows = await _service.getShows(chunk);
      } catch (error) {
        apiLogger.w('Show detail batch unavailable: $error');
      }
      // Recover omitted entries and older servers without the batch endpoint.
      final received = shows.map((show) => show.id).toSet();
      final missing = chunk.where((id) => !received.contains(id)).toList();
      for (var offset = 0; offset < missing.length; offset += 5) {
        if (_disposed || request != _showDetailsRequest) return;
        final recovered =
            await Future.wait(missing.skip(offset).take(5).map((id) async {
          try {
            return await _service.getShow(id);
          } catch (error) {
            apiLogger.w('Could not load watchlist show $id: $error');
            return null;
          }
        }));
        shows.addAll(recovered.whereType<TvShow>());
      }
      if (_disposed || request != _showDetailsRequest) return;
      _change(() {
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
        filterWatchlist();
      });
    }
  }

  Future<void> _loadShowWatchProviderAvailability(
    List<WatchlistShowEntry> watchlist,
  ) async {
    final request = ++_showProvidersRequest;
    if (watchlist.isEmpty) {
      if (!_disposed && request == _showProvidersRequest) {
        _change(() {
          _showWatchProviders.clear();
          _loadingShowWatchProviderAvailability = false;
        });
      }
      return;
    }
    final authProvider = _auth;
    final user = authProvider.dbUser;
    if (user == null) return;
    _change(() {
      _loadingShowWatchProviderAvailability = true;
    });
    try {
      await authProvider.ensureWatchProviderCache(movieIds: const []);
      final region = user.watchProviderRegion;
      final entries = <MapEntry<int, List<WatchProvider>>>[];
      // Bound network work; never launch an unbounded request per saved show.
      for (var start = 0; start < watchlist.length; start += 6) {
        if (_disposed || request != _showProvidersRequest) return;
        final chunk =
            await Future.wait(watchlist.skip(start).take(6).map((item) async {
          try {
            return MapEntry(item.showId,
                await _service.getShowProviders(item.showId, region));
          } catch (_) {
            return null;
          }
        }));
        if (_disposed || request != _showProvidersRequest) return;
        entries.addAll(chunk.whereType<MapEntry<int, List<WatchProvider>>>());
        _change(() => _showWatchProviders
            .addEntries(chunk.whereType<MapEntry<int, List<WatchProvider>>>()));
        filterWatchlist();
      }
      final savedProviders = await _service
          .getSavedProviders(user.id)
          .catchError((_) => _savedProviders);
      if (_disposed || request != _showProvidersRequest) return;
      _change(() {
        _userWatchProviderIds = {
          ...?authProvider.cachedUserWatchProviderIds,
        };
        _savedProviders = savedProviders;
        _userWatchProviderMatchKeys = savedProviders
            .where((provider) => _userWatchProviderIds.contains(provider.id))
            .map((provider) => provider.matchKey)
            .toSet();
        _showWatchProviders.addEntries(entries);
        _loadingShowWatchProviderAvailability = false;
      });
      filterWatchlist();
    } catch (_) {
      if (!_disposed && request == _showProvidersRequest) {
        _change(() => _loadingShowWatchProviderAvailability = false);
      }
    }
  }

  bool isAvailableOnUserProviders(int movieId) {
    final cached = _canWatchNowByMovieId[movieId];
    if (cached != null) return cached;

    final providers = _movieWatchProviders[movieId] ?? const <WatchProvider>[];
    return providers.any(
        (provider) => provider.isIncludedOffer && _isUserProvider(provider));
  }

  void filterWatchlist() {
    if (!usesExperience && _experienceRequestKey != null) {
      _experienceGeneration++;
      _experienceRequestKey = null;
      _experienceLoading = false;
      _experienceError = null;
      _experienceFits.clear();
    }
    final key = jsonEncode([
      _filters.mood.id,
      _filters.avoid.toList()..sort(),
      _filters.request,
      _auth.dbUser?.id,
      _allWatchlist.map((e) => e.movieId).toList(),
      _allShowWatchlist.map((e) => e.showId).toList()
    ]);
    if (usesExperience && key != _experienceRequestKey) {
      _experienceRequestKey = key;
      _experienceFits.clear();
      Future.microtask(() => _loadExperience(key));
    }
    _change(() {});
  }

  List<String> allGenres() => _selection.allGenres();
  List<int> allYears() => _selection.allYears();

  bool get hasActiveFilters =>
      usesExperience ||
      _filters.servicesOnly ||
      _filters.release != null ||
      _filters.genre != null ||
      _filters.minRating != null ||
      _filters.year != null ||
      _filters.maxRuntime != null;

  bool _isUserProvider(WatchProvider provider) =>
      _userWatchProviderIds.contains(provider.id) ||
      _userWatchProviderMatchKeys.contains(provider.matchKey);
  void clearFilters() {
    _searchQuery = '';
    _change(() {
      _filters.friendsOnly = false;
      _filters.tab = 0;
      _filters.media = 0;
      _filters.release = null;
      _filters.genre = null;
      _filters.minRating = null;
      _filters.year = null;
      _filters.maxRuntime = null;
      _filters.mood = WatchlistMood.any;
      _filters.avoid = {};
      _filters.request = '';
      _filters.findingToday = false;
      _experienceMessage = null;
      _hasUncheckedExclusions = false;
      _experienceGeneration++;
      _experienceRequestKey = null;
      _experienceLoading = false;
      _experienceError = null;
      _experienceFits.clear();
      _filters.servicesOnly = false;
      _filters.includeRentals = false;
      _filters.providerIds = null;
      _searchProviders = [];
    });
    filterWatchlist();
  }

  bool get comingSoonOnly =>
      _filters.release == ReleaseStatus.comingSoon || _filters.tab == 2;

  String sortByLabel() {
    if (comingSoonOnly) return 'Soonest first';
    switch (_filters.sort) {
      case 'runtimeAsc':
        return 'Shortest first';
      case 'recent':
        return 'Date added';
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
        return 'Date added';
    }
  }

  WatchlistSelection get _selection => _selectionCache ??= WatchlistSelection(
        filters: _filters,
        searchQuery: searchQuery,
        movies: _allWatchlist,
        shows: _allShowWatchlist,
        user: _auth.dbUser,
        movieFriends: _recommendationsByMovieId,
        showFriends: _friendsByShowId,
        movieProviders: _movieWatchProviders,
        showProviders: _showWatchProviders,
        experienceFits: _experienceFits,
        usesExperience: usesExperience,
        fitsExperience: _fitsExperience,
        matchesServices: _matchesTonightServices,
        canWatchMovie: isAvailableOnUserProviders,
        isUserProvider: _isUserProvider,
      );

  List<Object> get visibleItems => _selection.visibleItems;

  void prepareEnrichment(List<Object> items) {
    final enrichmentView = jsonEncode([
      _filters.media,
      _filters.tab,
      _filters.friendsOnly,
      _filters.servicesOnly,
      searchQuery,
      _filters.sort,
      _filters.genre,
      _filters.minRating,
      _filters.year,
      _filters.maxRuntime,
      _filters.release?.name,
      _filters.mood.id,
      _filters.request,
    ]);
    if (_enrichmentView != enrichmentView) {
      _enrichmentView = enrichmentView;
      // Cancel queued offscreen work from the previous search/filter.
      _pendingEnrichment.clear();
      _scheduledEnrichment.removeWhere((key) =>
          !_completedEnrichment.contains(key) &&
          !_inFlightEnrichment.contains(key));
    }
    if (_filters.friendsOnly || _filters.tab == 1 || _filters.servicesOnly) {
      scheduleEnrichment([..._allWatchlist, ..._allShowWatchlist]);
    } else {
      scheduleEnrichment(items.take(20));
    }
  }
}
