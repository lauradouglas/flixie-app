import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/continue_watching_show.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/movie_wrapped.dart';
import 'package:flixie_app/models/person.dart';
import '../../data/profile_data_service.dart';
import '../../models/profile_section.dart';
import 'review_reactions_controller.dart';

/// Own-profile loading and paging, scoped to its account and request generation.
class ProfileController extends ChangeNotifier {
  ProfileController(
      {required this.auth, this.service = const ProfileDataService()}) {
    _viewer = auth.dbUser?.id;
    _activityVersion = auth.activityVersion;
    auth.addListener(_onAuthChanged);
    ReviewReactionsController.deletedReviews.addListener(_onReviewDeleted);
  }
  final AuthProvider auth;
  final ProfileDataService service;
  String? _viewer;
  int _generation = 0, _activityVersion = -1;
  final _versions = <String, int>{};
  bool _disposed = false, _refreshing = false;
  int get generation => _generation;
  bool get isDisposed => _disposed;
  bool owns(int generation, String? viewer) =>
      !_disposed && generation == _generation && auth.dbUser?.id == viewer;
  List<ActivityListItem> activity = [];
  List<ActivityListItem> recentActivity = [];
  bool recentActivityLoading = true;
  bool _activityLoaded = false, _ratingsLoaded = false;
  bool _ratingsInvalidated = false, _statsDirty = true;
  Future<void>? _ratingsTask;
  List<MovieRating> ratings = [];
  List<ContinueWatchingShow> continueWatching = [];
  List<WatchProvider> watchProviders = [];
  List<Review> reviews = [];
  int reviewCount = 0;
  MovieWrapped? wrapped;
  Map<int, Person> directorPeople = {};
  bool activityLoading = true,
      ratingsLoading = true,
      profileExtrasLoading = true;
  bool activityFailed = false,
      profileExtrasFailed = false,
      statsLoading = false,
      statsFailed = false;
  bool activityRequestRunning = false;
  String? activityCursor;
  ProfileTab selectedTab = ProfileTab.library;
  ProfileActivityFilter activityFilter = ProfileActivityFilter.all;
  Future<void>? _statsTask;

  void change(VoidCallback update) {
    if (_disposed) return;
    update();
    notifyListeners();
  }

  void _onReviewDeleted() => change(() {
        reviews = List.unmodifiable(reviews
            .where((review) => !ReviewReactionsController.isDeleted(review)));
        reviewCount = reviews.length;
      });
  void _onAuthChanged() {
    if (_disposed) return;
    final viewer = auth.dbUser?.id;
    if (viewer != _viewer) {
      _viewer = viewer;
      _generation++;
      _versions.clear();
      _statsTask = null;
      _activityVersion = auth.activityVersion;
      change(() {
        activity = [];
        recentActivity = [];
        recentActivityLoading = viewer != null;
        _activityLoaded = _ratingsLoaded = _ratingsInvalidated = false;
        _statsDirty = true;
        _ratingsTask = null;
        ratings = [];
        continueWatching = [];
        watchProviders = [];
        reviews = [];
        reviewCount = 0;
        wrapped = null;
        directorPeople = {};
        activityCursor = null;
        activityFilter = ProfileActivityFilter.all;
        activityLoading =
            ratingsLoading = profileExtrasLoading = viewer != null;
        activityFailed = profileExtrasFailed =
            statsFailed = statsLoading = activityRequestRunning = false;
      });
      if (viewer != null) unawaited(loadAll());
    } else if (auth.activityVersion != _activityVersion) {
      _activityVersion = auth.activityVersion;
      if (!_refreshing && viewer != null) {
        final usedRatings = _ratingsLoaded || _ratingsTask != null;
        _invalidateOptional();
        unawaited(loadRecentActivity());
        if (selectedTab == ProfileTab.activity) unawaited(loadActivity());
        if (selectedTab == ProfileTab.stats) {
          unawaited(loadStats(forceRefresh: true));
        } else if (usedRatings) {
          unawaited(loadRatings(forceRefresh: true));
        }
      }
    }
  }

  bool Function() _request(String section) {
    final generation = _generation, viewer = auth.dbUser?.id;
    final version = (_versions[section] ?? 0) + 1;
    _versions[section] = version;
    return () => owns(generation, viewer) && _versions[section] == version;
  }

  void _invalidateOptional() {
    for (final section in ['activity', 'ratings', 'stats']) {
      _versions[section] = (_versions[section] ?? 0) + 1;
    }
    _activityLoaded = _ratingsLoaded = false;
    _ratingsInvalidated = _statsDirty = true;
    _ratingsTask = _statsTask = null;
    activityRequestRunning = false;
  }

  Future<void> loadAll({bool forceRefresh = false}) async {
    if (_disposed || auth.dbUser == null) {
      change(() {
        recentActivityLoading =
            activityLoading = ratingsLoading = profileExtrasLoading = false;
      });
      return;
    }
    _generation++;
    _versions.clear();
    _activityLoaded = _ratingsLoaded = false;
    _statsDirty = true;
    _ratingsInvalidated = forceRefresh;
    _ratingsTask = _statsTask = null;
    activityRequestRunning = false;
    change(() => statsLoading = false);
    await Future.wait([
      loadRecentActivity(),
      loadProfileExtras(),
      if (selectedTab == ProfileTab.activity) loadActivity(),
      if (selectedTab == ProfileTab.stats)
        loadStats(forceRefresh: forceRefresh),
    ]);
  }

  Future<void> refresh() async {
    if (_disposed || _refreshing || auth.dbUser == null) return;
    final generation = _generation, viewer = auth.dbUser!.id;
    _refreshing = true;
    try {
      await auth.refreshUserData();
      if (!owns(generation, viewer)) return;
      final lists = await service.movieLists(viewer);
      if (!owns(generation, viewer)) return;
      auth.updateCachedMovieLists(lists);
      await loadAll(forceRefresh: true);
    } finally {
      _refreshing = false;
    }
  }

  void selectTab(ProfileTab tab) {
    change(() => selectedTab = tab);
    if (tab == ProfileTab.activity &&
        !_activityLoaded &&
        !activityRequestRunning) {
      unawaited(loadActivity());
    }
    if (tab == ProfileTab.stats) unawaited(loadStats());
  }

  Future<void> selectFilter(ProfileActivityFilter filter) async {
    if (_disposed || filter == activityFilter) return;
    change(() {
      activityFilter = filter;
      activity = [];
      activityCursor = null;
    });
    await loadActivity();
  }

  /// Library needs watches, not watchlists, favourites, reviews and ratings.
  Future<void> loadRecentActivity() async {
    final viewer = auth.dbUser?.id;
    if (_disposed || viewer == null) return;
    final current = _request('recent');
    change(() => recentActivityLoading = true);
    try {
      final page = await service.activity(viewer, filter: 'watches');
      if (current()) {
        change(() => recentActivity = List.unmodifiable(page.items));
      }
    } catch (_) {
      // Keep useful same-account content; pull-to-refresh retries this section.
    } finally {
      if (current()) change(() => recentActivityLoading = false);
    }
  }

  Future<void> loadActivity({bool more = false}) async {
    if (_disposed ||
        (more && (activityRequestRunning || activityCursor == null))) {
      return;
    }
    final viewer = auth.dbUser?.id;
    if (viewer == null) return;
    final current = _request('activity');
    _activityVersion = auth.activityVersion;
    change(() {
      activityRequestRunning = true;
      activityLoading = !more;
      activityFailed = false;
    });
    try {
      final page = await service.activity(viewer,
          filter: activityFilter.name, cursor: more ? activityCursor : null);
      if (!current()) return;
      change(() {
        activity =
            List.unmodifiable(more ? [...activity, ...page.items] : page.items);
        activityCursor = page.nextCursor;
        _activityLoaded = true;
      });
    } catch (_) {
      if (current()) change(() => activityFailed = true);
    } finally {
      if (current()) {
        change(() {
          activityLoading = false;
          activityRequestRunning = false;
        });
      }
    }
  }

  Future<void> loadRatings({bool forceRefresh = false}) {
    if (_disposed || auth.dbUser == null || (!forceRefresh && _ratingsLoaded)) {
      return Future.value();
    }
    if (_ratingsTask != null) return _ratingsTask!;
    final task =
        _fetchRatings(forceRefresh: forceRefresh || _ratingsInvalidated);
    _ratingsTask = task;
    unawaited(task.whenComplete(() {
      if (identical(_ratingsTask, task)) _ratingsTask = null;
    }));
    return task;
  }

  Future<void> _fetchRatings({required bool forceRefresh}) async {
    final viewer = auth.dbUser?.id;
    if (_disposed || viewer == null) return;
    final current = _request('ratings');
    change(() => ratingsLoading = true);
    if (!forceRefresh && auth.cachedRatings != null) {
      change(() {
        ratings = List.unmodifiable(auth.cachedRatings!);
        ratingsLoading = false;
        _ratingsLoaded = true;
      });
      return;
    }
    try {
      final values = await service.ratings(viewer);
      if (current()) {
        change(() {
          ratings = List.unmodifiable(values);
          _ratingsLoaded = true;
          _ratingsInvalidated = false;
        });
      }
    } catch (_) {
      // Keep useful same-account ratings when a refresh fails.
    } finally {
      if (current()) change(() => ratingsLoading = false);
    }
  }

  Future<void> loadProfileExtras() async {
    final viewer = auth.dbUser?.id;
    if (_disposed || viewer == null) return;
    final current = _request('extras');
    change(() {
      profileExtrasLoading = true;
      profileExtrasFailed = false;
      if (auth.cachedReviews != null) {
        reviews = List.unmodifiable(auth.cachedReviews!);
        reviewCount = reviews.length;
      }
    });
    Future<void> section<T>(Future<T> future, void Function(T) apply) async {
      try {
        final value = await future;
        if (current()) change(() => apply(value));
      } catch (_) {
        if (current()) change(() => profileExtrasFailed = true);
      }
    }

    await Future.wait([
      section(service.continueWatching(viewer),
          (value) => continueWatching = List.unmodifiable(value)),
      section(service.watchProviders(viewer),
          (value) => watchProviders = List.unmodifiable(value)),
    ]);
    if (!current()) return;
    change(() => profileExtrasLoading = false);
  }

  Future<void> loadStats({bool forceRefresh = false}) {
    if (_disposed ||
        auth.dbUser == null ||
        (!forceRefresh && !_statsDirty && wrapped != null)) {
      return Future.value();
    }
    if (_statsTask != null) return _statsTask!;
    final task = _loadStats(forceRefresh: forceRefresh);
    _statsTask = task;
    unawaited(task.whenComplete(() {
      if (identical(_statsTask, task)) _statsTask = null;
    }));
    return task;
  }

  Future<void> _loadStats({required bool forceRefresh}) async {
    final viewer = auth.dbUser!.id, current = _request('stats');
    change(() {
      statsLoading = true;
      statsFailed = false;
    });
    try {
      final values = await Future.wait<Object>([
        service.reviews(viewer),
        service.wrapped(viewer, DateTime.now().year),
        loadRatings(forceRefresh: forceRefresh).then((_) => ratings),
      ]);
      if (!current()) return;
      final value = values[1] as MovieWrapped;
      change(() {
        reviews = List.unmodifiable(values[0] as List<Review>);
        reviewCount = reviews.length;
        wrapped = value;
        _statsDirty = false;
      });
      final people = await Future.wait(value.topDirectors
          .where((d) => d.personId != null)
          .take(4)
          .map((director) async {
        try {
          return (
            id: director.personId!,
            person: await service
                .person(director.personId!)
                .timeout(const Duration(seconds: 10))
          );
        } catch (_) {
          return null;
        }
      }));
      if (current()) {
        change(() => directorPeople = {
              for (final person
                  in people.whereType<({int id, Person person})>())
                person.id: person.person,
            });
      }
    } catch (_) {
      if (current()) change(() => statsFailed = true);
    } finally {
      if (current()) change(() => statsLoading = false);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    auth.removeListener(_onAuthChanged);
    ReviewReactionsController.deletedReviews.removeListener(_onReviewDeleted);
    super.dispose();
  }
}
