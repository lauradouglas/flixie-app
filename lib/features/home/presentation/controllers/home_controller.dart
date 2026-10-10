import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/startup_trace.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/home/data/home_data_service.dart';
import 'package:flixie_app/features/home/data/recommendation_service.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/continue_watching_show.dart';
import 'package:flixie_app/models/friend_media_interaction.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watch_request.dart';
import '../models/home_section.dart';
import 'home_watch_plans_controller.dart';

/// Home data ownership. Widgets subscribe to individual sections, not this owner.
class HomeController {
  HomeController({
    required AuthProvider auth,
    required this.watchPlans,
    HomeDataService service = const HomeDataService(),
    this.onTrendingReady,
  })  : _auth = auth,
        _service = service {
    _userId = auth.dbUser?.id;
    watchPlans.selectUser(_userId);
    _lastActivityVersion = auth.activityVersion;
    final snapshot = _sessionSnapshot;
    if (snapshot != null && snapshot.userId == _userId) {
      trending.update(data: snapshot.trending, loading: false);
      recommendations.update(data: snapshot.recommendations);
      continueWatching.update(data: snapshot.continueWatching);
      watchlist.update(data: HomeWatchlistState(ids: snapshot.watchlist));
      for (final entry in snapshot.friends.entries) {
        _loadedFriendIds.add(entry.key);
        friendActivity(entry.key).update(data: entry.value, loading: false);
      }
      watchPlans.restore(
          snapshot.plans, snapshot.responseCount, snapshot.hasUsedPlans);
      _lastActivityVersion = snapshot.activityVersion;
      _snapshotIncomplete = snapshot.incomplete;
      secondaryError.value = snapshot.secondaryError;
      _restored = true;
    }
  }

  final AuthProvider _auth;
  final HomeDataService _service;
  final HomeWatchPlansController watchPlans;
  final void Function(List<MovieShort>, User?)? onTrendingReady;
  final trending = HomeSection<List<MovieShort>>(const [], loading: true);
  final recommendations = HomeSection<List<MovieShort>>(const []);
  final continueWatching = HomeSection<List<ContinueWatchingShow>>(const []);
  final watchlist = HomeSection<HomeWatchlistState>(HomeWatchlistState());
  final secondaryError = ValueNotifier<String?>(null);
  final _friends = <int, HomeSection<List<FriendMediaInteraction>>>{};
  final _loadedFriendIds = <int>{};
  final _friendLoads = <int, Future<void>>{};
  int _heroIndex = 0;
  static const heroLimit = 12;
  static _HomeSnapshot? _sessionSnapshot;
  bool _disposed = false, _started = false, _restored = false;
  bool _snapshotIncomplete = false;
  bool _watchlistLoadStarted = false;
  String? _userId;
  int _generation = 0, _recommendationsGeneration = 0, _accountVersion = 0;
  int _lastActivityVersion = -1;
  String? get userId => _userId;
  ({String? userId, int version}) get session =>
      (userId: _userId, version: _accountVersion);
  bool ownsSession(({String? userId, int version}) token) =>
      !_disposed && session == token && _auth.dbUser?.id == token.userId;

  @visibleForTesting
  static void clearSessionSnapshotForTesting() => _sessionSnapshot = null;

  HomeSection<List<FriendMediaInteraction>> friendActivity(int movieId) =>
      _friends.putIfAbsent(movieId, () => HomeSection(const [], loading: true));
  bool friendActivityLoaded(int movieId) => _loadedFriendIds.contains(movieId);

  Map<int, List<FriendMediaInteraction>> get friendInteractions => {
        for (final id in _loadedFriendIds) id: _friends[id]!.value.data,
      };
  void start() {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    _auth.addListener(_onAuthChanged);
    if (_auth.dbUser?.id != _userId) {
      _onAuthChanged();
    } else if (_restored && _lastActivityVersion != _auth.activityVersion) {
      _onAuthChanged();
    } else if (_restored && _snapshotIncomplete) {
      unawaited(load(showFullLoading: false));
    } else if (_restored) {
      unawaited(watchPlans.load(_auth.dbUser, force: false));
      unawaited(showHeroPage(0));
    } else {
      unawaited(load());
    }
  }

  void _onAuthChanged() {
    if (_disposed) {
      return;
    }
    final id = _auth.dbUser?.id;
    if (id != _userId) {
      _selectAccount(id);
      if (id != null) {
        unawaited(load());
      }
      return;
    }
    final activity = _auth.activityVersion;
    if (id == null || activity == _lastActivityVersion) {
      return;
    }
    _lastActivityVersion = activity;
    RecommendationService.invalidateCache(userId: id);
    unawaited(load(
        showFullLoading: false,
        refreshRecommendations: true,
        refreshProfile: !_auth.activityIncludesRefreshedProfile));
  }

  void _selectAccount(String? id) {
    _generation++;
    _recommendationsGeneration++;
    _accountVersion++;
    _userId = id;
    _watchlistLoadStarted = false;
    _lastActivityVersion = _auth.activityVersion;
    _sessionSnapshot = null;
    _loadedFriendIds.clear();
    _friendLoads.clear();
    trending.update(data: const [], loading: id != null, clearError: true);
    recommendations.update(data: const [], loading: false, clearError: true);
    continueWatching.update(data: const [], loading: false, clearError: true);
    watchlist.update(
        data: HomeWatchlistState(), loading: false, clearError: true);
    for (final section in _friends.values) {
      section.update(data: const [], loading: true, clearError: true);
    }
    secondaryError.value = null;
    watchPlans.selectUser(id);
  }

  bool _current(int generation, String? id) =>
      !_disposed &&
      generation == _generation &&
      _userId == id &&
      _auth.dbUser?.id == id;

  Future<void> load(
      {bool refreshRecommendations = false,
      bool showFullLoading = true,
      bool refreshProfile = true}) async {
    if (_disposed) {
      return;
    }
    final id = _auth.dbUser?.id;
    if (id != _userId) {
      _selectAccount(id);
    }
    final generation = ++_generation;
    _loadedFriendIds.clear();
    _friendLoads.clear();
    if (showFullLoading) {
      trending.update(loading: true, clearError: true);
    }
    if (refreshRecommendations && refreshProfile) {
      await _auth.refreshUserData();
      if (!_current(generation, id)) {
        return;
      }
    }
    final user = _auth.dbUser;
    _lastActivityVersion = _auth.activityVersion;
    unawaited(watchPlans.load(user,
        force: refreshRecommendations || !showFullLoading));
    unawaited(
        _loadSecondary(user, generation, refresh: refreshRecommendations));
    try {
      final movies = await _service.trending(refresh: refreshRecommendations);
      if (!_current(generation, id)) {
        return;
      }
      trending.update(
          data: List.unmodifiable(movies), loading: false, clearError: true);
      onTrendingReady?.call(movies, user);
      if (user != null) {
        unawaited(showHeroPage(_heroIndex));
      }
    } catch (error) {
      logger.w('[Home] trending failed: $error');
      if (!_current(generation, id)) {
        return;
      }
      trending.update(
          loading: false,
          error: trending.value.data.isEmpty
              ? 'Couldn\'t load content. Check your connection.'
              : null);
      if (trending.value.data.isNotEmpty) {
        secondaryError.value = 'Couldn’t refresh Home.';
      }
    }
  }

  Future<void> _loadSecondary(User? user, int generation,
      {required bool refresh}) async {
    if (user == null) {
      return;
    }
    secondaryError.value = null;
    final recommendationsGeneration = ++_recommendationsGeneration;
    Future<void> section<T>(HomeSection<T> state, Future<T> request, T empty,
        {bool Function()? stillCurrent}) async {
      state.update(loading: true, clearError: true);
      bool current() =>
          _current(generation, user.id) && (stillCurrent?.call() ?? true);
      try {
        final value = await request;
        if (current()) {
          state.update(data: value, loading: false, clearError: true);
        }
      } catch (error) {
        if (!current()) {
          return;
        }
        final denied =
            error is ApiException && [401, 403].contains(error.statusCode);
        state.update(
            data: denied ? empty : null,
            loading: false,
            error: 'Some Home sections couldn’t refresh.');
        secondaryError.value = 'Some Home sections couldn’t refresh.';
      }
    }

    // Bootstrap already loaded this account’s membership. Refreshes and activity
    // invalidations still use the endpoint, including an omitted collection.
    final bootstrapWatchlist = !_watchlistLoadStarted &&
            !refresh &&
            _auth.activityIncludesRefreshedProfile &&
            watchlist.value.data.pending.isEmpty
        ? user.movieWatchlist
        : null;
    _watchlistLoadStarted = true;

    await Future.wait([
      section(
          recommendations,
          _service
              .recommendations(user.id, refresh: refresh)
              .then((items) => List<MovieShort>.unmodifiable(items.take(20))),
          const <MovieShort>[],
          stillCurrent: () =>
              recommendationsGeneration == _recommendationsGeneration),
      section(
          watchlist,
          (bootstrapWatchlist == null
                  ? _service.watchlist(user.id)
                  : Future.value(bootstrapWatchlist))
              .then((items) {
            final current = watchlist.value.data;
            final ids = items
                .where((item) => item.removed != true)
                .map((item) => item.movieId)
                .toSet();
            // A response must not undo an optimistic edit still in flight.
            for (final id in current.pending) {
              current.ids.contains(id) ? ids.add(id) : ids.remove(id);
            }
            return HomeWatchlistState(ids: ids, pending: current.pending);
          }),
          HomeWatchlistState()),
      section(
          continueWatching,
          _service
              .continueWatching(user.id)
              .then((items) => List<ContinueWatchingShow>.unmodifiable(items)),
          const <ContinueWatchingShow>[]),
    ]);
    if (_current(generation, user.id)) {
      StartupTrace.mark('home-secondary-complete');
    }
  }

  /// Fetch the visible card and one ahead; revisits share this load's results.
  Future<void> showHeroPage(int index) async {
    if (_disposed || _userId == null) return;
    final movies = trending.value.data.take(heroLimit).toList(growable: false);
    if (movies.isEmpty) return;
    _heroIndex = index.clamp(0, movies.length - 1);
    await Future.wait(movies
        .skip(_heroIndex)
        .take(2)
        .map((movie) => _loadFriend(movie, _userId!, _generation)));
  }

  Future<void> retryFriendActivity(MovieShort movie) async {
    if (_disposed || _userId == null) return;
    _loadedFriendIds.remove(movie.id);
    await _loadFriend(movie, _userId!, _generation);
  }

  Future<void> _loadFriend(MovieShort movie, String id, int generation) {
    if (!_current(generation, id) || _loadedFriendIds.contains(movie.id)) {
      return Future.value();
    }
    final pending = _friendLoads[movie.id];
    if (pending != null) return pending;
    final request = _fetchFriend(movie, id, generation);
    _friendLoads[movie.id] = request;
    return request.whenComplete(() {
      if (identical(_friendLoads[movie.id], request)) {
        _friendLoads.remove(movie.id);
      }
    });
  }

  Future<void> _fetchFriend(MovieShort movie, String id, int generation) async {
    final state = friendActivity(movie.id);
    state.update(loading: true, clearError: true);
    for (var attempt = 0; attempt < 2; attempt++) {
      if (!_current(generation, id)) return;
      try {
        final items = await _service
            .friends(id, movie.id)
            .timeout(const Duration(seconds: 15));
        if (!_current(generation, id)) return;
        _loadedFriendIds.add(movie.id);
        state.update(
            data: List.unmodifiable(items), loading: false, clearError: true);
        return;
      } catch (error) {
        if (!_current(generation, id)) return;
        final denied =
            error is ApiException && [401, 403].contains(error.statusCode);
        if (denied || attempt == 1) {
          state.update(
              data: denied ? const [] : null,
              loading: false,
              error: 'Friend activity unavailable');
          return;
        }
      }
    }
  }

  /// Explicit regeneration cannot be overwritten by an earlier section load.
  Future<bool> refreshRecommendations() async {
    if (_disposed || recommendations.value.loading || _userId == null) {
      return false;
    }
    final id = _userId!;
    final generation = _generation;
    final request = ++_recommendationsGeneration;
    bool current() =>
        _current(generation, id) && request == _recommendationsGeneration;
    recommendations.update(loading: true, clearError: true);
    try {
      final items = await _service.recommendations(id, refresh: true);
      if (!current()) {
        return false;
      }
      recommendations.update(
          data: List.unmodifiable(items.take(20)),
          loading: false,
          clearError: true);
      return true;
    } catch (error) {
      if (!current()) {
        return false;
      }
      recommendations.update(
          loading: false, error: 'Couldn’t refresh your picks.');
      rethrow;
    }
  }

  void removeRecommendation(int movieId) {
    if (_disposed) {
      return;
    }
    recommendations.update(
        data: List.unmodifiable(
            recommendations.value.data.where((movie) => movie.id != movieId)));
  }

  void restoreRecommendation(MovieShort movie, int index) {
    if (_disposed ||
        recommendations.value.data.any((item) => item.id == movie.id)) {
      return;
    }
    final items = [...recommendations.value.data];
    items.insert(index.clamp(0, items.length), movie);
    recommendations.update(data: List.unmodifiable(items));
  }

  void removeContinueWatching(int showId) {
    if (_disposed) {
      return;
    }
    continueWatching.update(
        data: List.unmodifiable(continueWatching.value.data
            .where((show) => show.showId != showId)));
  }

  void restoreContinueWatching(ContinueWatchingShow show, int index) {
    if (_disposed ||
        continueWatching.value.data.any((item) => item.showId == show.showId)) {
      return;
    }
    final items = [...continueWatching.value.data];
    items.insert(index.clamp(0, items.length), show);
    continueWatching.update(data: List.unmodifiable(items));
  }

  void setWatchlistMembership(int movieId, bool saved, {bool? pending}) {
    if (_disposed) {
      return;
    }
    final previous = watchlist.value.data;
    final ids = {...previous.ids}, updates = {...previous.pending};
    saved ? ids.add(movieId) : ids.remove(movieId);
    if (pending != null) {
      pending ? updates.add(movieId) : updates.remove(movieId);
    }
    watchlist.update(data: HomeWatchlistState(ids: ids, pending: updates));
  }

  void finishWatchlistUpdate(int movieId) {
    if (_disposed) {
      return;
    }
    final previous = watchlist.value.data;
    watchlist.update(
        data: HomeWatchlistState(
            ids: previous.ids,
            pending: {...previous.pending}..remove(movieId)));
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    if (_userId != null &&
        _auth.dbUser?.id == _userId &&
        !trending.value.loading &&
        trending.value.error == null) {
      _sessionSnapshot = _HomeSnapshot(
          _userId!,
          trending.value.data,
          recommendations.value.data,
          continueWatching.value.data,
          friendInteractions,
          watchlist.value.data.ids,
          watchPlans.plans,
          watchPlans.requestsNeedingResponse,
          watchPlans.hasUsedPlans,
          _lastActivityVersion,
          recommendations.value.loading ||
              continueWatching.value.loading ||
              watchlist.value.loading ||
              watchlist.value.data.pending.isNotEmpty,
          secondaryError.value);
    }
    _disposed = true;
    _generation++;
    _auth.removeListener(_onAuthChanged);
    trending.dispose();
    recommendations.dispose();
    continueWatching.dispose();
    watchlist.dispose();
    secondaryError.dispose();
    for (final section in _friends.values) {
      section.dispose();
    }
    watchPlans.dispose();
  }
}

class _HomeSnapshot {
  const _HomeSnapshot(
      this.userId,
      this.trending,
      this.recommendations,
      this.continueWatching,
      this.friends,
      this.watchlist,
      this.plans,
      this.responseCount,
      this.hasUsedPlans,
      this.activityVersion,
      this.incomplete,
      this.secondaryError);
  final String userId;
  final List<MovieShort> trending, recommendations;
  final List<ContinueWatchingShow> continueWatching;
  final Map<int, List<FriendMediaInteraction>> friends;
  final Set<int> watchlist;
  final List<WatchRequest> plans;
  final int responseCount;
  final bool hasUsedPlans;
  final int activityVersion;
  final bool incomplete;
  final String? secondaryError;
}
