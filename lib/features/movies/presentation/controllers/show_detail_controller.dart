import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/models/show_list.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/watch_provider.dart';
import '../../data/show_detail_service.dart';

enum ShowDetailAction { watchlist, favorite }

/// TV data loading, section retry and viewer-scoped progress/action state.
class ShowDetailController extends ChangeNotifier {
  ShowDetailController(
      {required this.auth, this.service = const ShowDetailService()}) {
    _viewer = auth.dbUser?.id;
    auth.addListener(_onAuthChanged);
  }
  final AuthProvider auth;
  final ShowDetailService service;
  String? _rawId, _viewer;
  int _generation = 0, _listsGeneration = 0;
  bool _disposed = false;
  int get generation => _generation;
  bool get isDisposed => _disposed;
  int? get showId => int.tryParse(_rawId ?? '');
  final _retries = <String, Future<void> Function()>{};
  final _sectionVersions = <String, int>{};
  TvShow? show;
  List<WatchProvider> watchProviders = [];
  List<TvShowCredit> cast = [];
  List<TvShowCredit> crew = [];
  List<Review> reviews = [];
  bool reviewsLoading = true;
  bool reviewsFailed = false;
  TvShowFriendSummary? friendSummary;
  List<ShowList> myListsContainingShow = [];
  Set<int> userProviderIds = {};
  Set<String> userProviderMatchKeys = {};
  bool isLoading = true;
  String? error;
  bool inWatchlist = false;
  bool isFavorite = false;
  int? userRating;
  String? userRecommendation;
  bool isRatingLoading = false;
  bool listsContainingShowLoading = false;
  ShowDetailAction? updatingAction;
  int? selectedSeasonNumber;
  final Set<int> updatingEpisodeIds = {};
  final Set<int> updatingSeasonNumbers = {};
  bool detailsLoading = true;
  final detailErrors = <String>{},
      pendingDetails = <String>{},
      loadedDetails = <String>{};
  void change(VoidCallback update) {
    if (_disposed) return;
    update();
    notifyListeners();
  }

  bool owns(int generation, String? viewer) =>
      !_disposed && _generation == generation && auth.dbUser?.id == viewer;
  void _onAuthChanged() {
    if (_disposed || _viewer == auth.dbUser?.id) return;
    _viewer = auth.dbUser?.id;
    _reset();
    if (_rawId != null) unawaited(load(_rawId!));
  }

  void _reset() {
    _generation++;
    _listsGeneration++;
    show = null;
    isLoading = true;
    error = null;
    cast = [];
    crew = [];
    reviews = [];
    watchProviders = [];
    friendSummary = null;
    myListsContainingShow = [];
    listsContainingShowLoading = false;
    userProviderIds = {};
    userProviderMatchKeys = {};
    inWatchlist = false;
    isFavorite = false;
    userRating = null;
    userRecommendation = null;
    isRatingLoading = false;
    updatingAction = null;
    selectedSeasonNumber = null;
    updatingEpisodeIds.clear();
    updatingSeasonNumbers.clear();
    loadedDetails.clear();
    pendingDetails.clear();
    detailErrors.clear();
    _retries.clear();
    _sectionVersions.clear();
    notifyListeners();
  }

  Future<void> retrySection(String name) async {
    if (!_disposed) await _retries[name]?.call();
  }

  Future<void> load(String rawId) async {
    if (_disposed) return;
    if (_rawId != rawId || _viewer != auth.dbUser?.id) _reset();
    _rawId = rawId;
    _viewer = auth.dbUser?.id;
    final generation = ++_generation, id = showId;
    if (id == null || id <= 0) {
      change(() {
        error = 'Invalid show ID.';
        isLoading = false;
      });
      return;
    }
    final user = auth.dbUser;
    bool current() => owns(generation, user?.id);
    change(() {
      error = null;
      isRatingLoading = false;
      updatingAction = null;
      updatingEpisodeIds.clear();
      updatingSeasonNumbers.clear();
      detailsLoading = true;
      detailErrors.clear();
      pendingDetails.clear();
      _retries.clear();
      reviewsLoading = true;
      inWatchlist = containsShowId(user?.showWatchlist, id);
      isFavorite = containsShowId(user?.favoriteShows, id);
    });
    Future<void> section<T>(
        String name, Future<T> Function() fetch, void Function(T) apply) async {
      if (!current()) return;
      final version = (_sectionVersions[name] ?? 0) + 1;
      _sectionVersions[name] = version;
      _retries[name] = () => section(name, fetch, apply);
      bool valid() => current() && _sectionVersions[name] == version;
      change(() {
        pendingDetails.add(name);
        detailErrors.remove(name);
        if (name == 'episodes') detailsLoading = true;
        if (name == 'reviews') {
          reviewsLoading = true;
          reviewsFailed = false;
        }
      });
      try {
        final value = await fetch();
        if (valid()) {
          change(() {
            apply(value);
            loadedDetails.add(name);
          });
        }
      } catch (error) {
        if (valid()) {
          change(() {
            detailErrors.add(name);
            if (error is ApiException &&
                [401, 403].contains(error.statusCode)) {
              if (name == 'friend activity') friendSummary = null;
              if (name == 'your rating') {
                userRating = null;
                userRecommendation = null;
              }
              if (name == 'your services') {
                userProviderIds = {};
                userProviderMatchKeys = {};
              }
            }
          });
        }
      } finally {
        if (valid()) {
          change(() {
            pendingDetails.remove(name);
            if (name == 'episodes') detailsLoading = false;
            if (name == 'reviews') {
              reviewsLoading = false;
              reviewsFailed = detailErrors.contains(name);
            }
          });
        }
      }
    }

    Future<void>? reviewsTask;
    void warmReviews() {
      if (!current()) return;
      reviewsTask ??= section('reviews', () => service.reviews(id, user?.id),
          (value) => reviews = List.unmodifiable(value));
    }

    final summary = service.summary(id);
    final details = section('episodes', () => service.details(id, user?.id),
        (TvShow value) {
      show = value;
      error = null;
      isLoading = false;
      selectedSeasonNumber = resolveSelectedSeasonNumber(value);
      warmReviews();
    });
    final optional = <Future<void>>[
      details,
      section(
          'streaming services',
          () => service.providers(id, user?.watchProviderRegion ?? 'GB'),
          (value) => watchProviders = List.unmodifiable(value)),
      section('cast', () => service.credits(id), (value) {
        cast = List.unmodifiable(value.cast);
        crew = List.unmodifiable(value.crew);
      }),
      if (user != null) ...[
        section('your services', () => service.userProviders(user.id), (value) {
          userProviderIds = value.map((p) => p.id).toSet();
          userProviderMatchKeys = value.map((p) => p.matchKey).toSet();
        }),
        section('your rating', () => service.rating(id, user.id), (value) {
          userRating = (value?['rating'] as num?)?.toInt();
          userRecommendation = value?['recommendation'] as String?;
        }),
        section('friend activity', () => service.friends(id),
            (value) => friendSummary = value),
      ],
    ];
    try {
      final value = await summary;
      if (current() && !loadedDetails.contains('episodes')) {
        change(() {
          show = value;
          isLoading = false;
        });
        warmReviews();
      }
    } catch (_) {
      await details;
      if (current() && show == null) {
        change(() {
          error = 'Couldn’t load this show. Please retry.';
          isLoading = false;
        });
      }
    }
    if (current() && user != null) {
      unawaited(loadListsContainingShow(user.id, id));
    }
    await Future.wait(optional);
    if (reviewsTask != null) await reviewsTask;
  }

  Future<void> loadListsContainingShow(String viewer, int id) async {
    if (_disposed || auth.dbUser?.id != viewer || showId != id) return;
    final generation = _generation, version = ++_listsGeneration;
    bool current() =>
        owns(generation, viewer) && version == _listsGeneration && showId == id;
    change(() => listsContainingShowLoading = true);
    try {
      final value = await service.containingLists(viewer, id);
      if (current()) {
        change(() => myListsContainingShow = List.unmodifiable(value));
      }
    } catch (error) {
      if (current() &&
          error is ApiException &&
          [401, 403].contains(error.statusCode)) {
        change(() => myListsContainingShow = []);
      }
    } finally {
      if (current()) change(() => listsContainingShowLoading = false);
    }
  }

  Future<void> reloadReviews() => retrySection('reviews');
  void addReview(Review review) =>
      change(() => reviews = List.unmodifiable([review, ...reviews]));
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  bool containsShowId(List<dynamic>? items, int showId) {
    if (items == null) return false;
    return items.any((item) {
      if (item is int) return item == showId;
      if (item is String) return int.tryParse(item) == showId;
      if (item is Map<String, dynamic>) {
        return item['showId'] == showId || item['id'] == showId;
      }
      return false;
    });
  }

  List<dynamic> updatedShowIdList(
    List<dynamic>? items,
    int showId,
    bool shouldContain,
  ) {
    final updated = (items ?? const <dynamic>[])
        .where((item) => !dynamicShowIdMatches(item, showId))
        .toList();
    if (shouldContain) {
      updated.add({
        'showId': showId,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        if (show?.id == showId) 'show': show!.toJson(),
      });
    }
    return updated;
  }

  bool dynamicShowIdMatches(dynamic item, int showId) {
    if (item is int) return item == showId;
    if (item is String) return int.tryParse(item) == showId;
    if (item is Map<String, dynamic>) {
      return item['showId'] == showId || item['id'] == showId;
    }
    return false;
  }

  int resolveSelectedSeasonNumber(TvShow show) {
    if (show.seasons.isEmpty) return 1;
    final current = selectedSeasonNumber;
    if (current != null &&
        show.seasons.any((season) => season.seasonNumber == current)) {
      return current;
    }

    final inProgress = show.seasons.where((season) {
      final total = season.resolvedEpisodeCount;
      return total > 0 &&
          season.watchedEpisodeCount > 0 &&
          season.watchedEpisodeCount < total;
    }).firstOrNull;
    if (inProgress != null) return inProgress.seasonNumber;

    final nextUnwatched = show.seasons.where((season) {
      final total = season.resolvedEpisodeCount;
      return total == 0 || season.watchedEpisodeCount < total;
    }).firstOrNull;
    if (nextUnwatched != null) return nextUnwatched.seasonNumber;

    return show.seasons.last.seasonNumber;
  }
}
