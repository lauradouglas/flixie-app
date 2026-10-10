import 'dart:convert';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/core/utils/notification_visibility.dart';
import 'auth_prefetch_coordinator.dart';
import 'auth_prefetch_snapshot.dart';

/// Account-scoped screen data. AuthProvider owns session transitions and calls
/// [clear] before changing accounts and on disposal. This owner adds no requests
/// beyond the existing coordinator's on-demand provider loads.
class AuthAccountCache {
  AuthAccountCache(this._prefetchCoordinator);
  final AuthPrefetchCoordinator _prefetchCoordinator;
  int _generation = 0;
  int _friendDataVersion = 0;
  int get friendDataVersion => _friendDataVersion;
  int _unreadNotificationCount = 0;
  int get unreadNotificationCount => _unreadNotificationCount;
  List<ActivityListItem>? _cachedFriendsActivity;
  List<ActivityListItem>? get cachedFriendsActivity => _cachedFriendsActivity;
  List<ActivityListItem>? _cachedActivity;
  FriendsData? _cachedFriends;
  List<Group>? _cachedGroups;
  List<MovieRating>? _cachedRatings;
  List<Review>? _cachedReviews;
  List<MovieShort>? _cachedTrending;
  List<MovieShort>? _cachedNowPlaying;
  List<MovieList>? _cachedMovieLists;
  List<FlixieNotification>? _cachedNotifications;
  final Set<String> _dismissedNotificationIds = <String>{};
  List<WatchRequest>? _cachedWatchRequests;
  final Map<int, List<WatchProvider>> _cachedWatchProvidersByMovieId = {};
  Set<int>? _cachedUserWatchProviderIds;
  String? _cachedWatchProviderRegion;
  Future<void>? _watchProviderCacheFuture;

  List<ActivityListItem>? get cachedActivity => _cachedActivity;
  FriendsData? get cachedFriends => _cachedFriends;
  List<Group>? get cachedGroups => _cachedGroups;
  List<MovieRating>? get cachedRatings => _cachedRatings;
  List<Review>? get cachedReviews => _cachedReviews;
  List<MovieShort>? get cachedTrending => _cachedTrending;
  List<MovieShort>? get cachedNowPlaying => _cachedNowPlaying;
  List<MovieList>? get cachedMovieLists => _cachedMovieLists;
  List<FlixieNotification>? get cachedNotifications => _cachedNotifications;
  List<WatchRequest>? get cachedWatchRequests => _cachedWatchRequests;
  Map<int, List<WatchProvider>> get cachedWatchProvidersByMovieId =>
      Map.unmodifiable(_cachedWatchProvidersByMovieId);
  Set<int>? get cachedUserWatchProviderIds =>
      _cachedUserWatchProviderIds == null
          ? null
          : Set.unmodifiable(_cachedUserWatchProviderIds!);

  void clear() {
    _generation++;
    _cachedActivity = null;
    _cachedFriendsActivity = null;
    _cachedFriends = null;
    _cachedGroups = null;
    _cachedRatings = null;
    _cachedReviews = null;
    _cachedTrending = null;
    _cachedNowPlaying = null;
    _cachedMovieLists = null;
    _cachedNotifications = null;
    _dismissedNotificationIds.clear();
    _cachedWatchRequests = null;
    _cachedWatchProvidersByMovieId.clear();
    _cachedUserWatchProviderIds = null;
    _cachedWatchProviderRegion = null;
    _watchProviderCacheFuture = null;
    _unreadNotificationCount = 0;
  }

  void updateCachedUserWatchProviderIds(Iterable<int> ids) {
    _cachedUserWatchProviderIds = ids.toSet();
  }

  void setUnreadNotificationCount(int count) {
    _unreadNotificationCount = count < 0 ? 0 : count;
  }

  /// Update the reviews cache, e.g. after writing a new review.
  void updateCachedReviews(List<Review> reviews) {
    _cachedReviews = reviews;
  }

  void updateCachedNotifications(List<FlixieNotification> notifications,
      {String? userId, int? unreadCount}) {
    final previousLoadedUnread =
        _cachedNotifications?.where((n) => !n.isRead).length ?? 0;
    final visible = userId == null
        ? List<FlixieNotification>.of(notifications)
        : visibleNotificationsForUser(notifications, userId);
    final active = visible
        .where((item) =>
            item.id == null || !_dismissedNotificationIds.contains(item.id))
        .toList(growable: false);
    _cachedNotifications = List.unmodifiable(active);
    setUnreadNotificationCount(unreadCount ??
        (_unreadNotificationCount -
            previousLoadedUnread +
            active.where((item) => !item.isRead).length));
  }

  /// Prevents an in-flight prefetch from restoring a card the user has just
  /// dismissed. The server remains the durable source of truth; this only
  /// protects the current app session from stale responses.
  void removeCachedNotification(String notificationId, {String? userId}) {
    _dismissedNotificationIds.add(notificationId);
    updateCachedNotifications(_cachedNotifications ?? const [], userId: userId);
  }

  /// Dismisses every notification card belonging to a direct Watch Plan.
  /// Watch Plans deliberately have a small lifecycle feed, not independent
  /// alerts, so an older status must not surface after the latest is closed.
  void removeCachedWatchPlanNotifications(String requestId, {String? userId}) {
    for (final notification
        in _cachedNotifications ?? const <FlixieNotification>[]) {
      final isWatchPlan =
          notification.type == FlixieNotification.movieWatchRequest ||
              notification.type == FlixieNotification.showWatchRequest;
      if (isWatchPlan && notification.linkedRequestId == requestId) {
        final id = notification.id;
        if (id != null) _dismissedNotificationIds.add(id);
      }
    }
    updateCachedNotifications(_cachedNotifications ?? const [], userId: userId);
  }

  void updateCachedWatchRequests(List<WatchRequest> requests) {
    _cachedWatchRequests = List.unmodifiable(requests);
  }

  /// Clears the reviews cache so the next reviews screen visit fetches fresh data.
  void invalidateCachedReviews() {
    _cachedReviews = null;
  }

  /// Update the friends cache, e.g. after accepting/declining a request.
  void updateCachedFriends(FriendsData friends) {
    _friendDataVersion++;
    _cachedFriends = friends;
  }

  /// Keeps the Social tab's stale-while-refresh snapshot current.
  void updateCachedSocialData({
    required FriendsData friends,
    required List<ActivityListItem> activity,
    required List<Group> groups,
  }) {
    _cachedFriends = friends;
    _friendDataVersion++;
    _cachedFriendsActivity = activity;
    _cachedGroups = groups;
  }

  void updateCachedGroups(List<Group> groups) {
    _cachedGroups = groups;
  }

  void updateCachedMovieLists(List<MovieList> lists) {
    _cachedMovieLists = List.unmodifiable(lists);
  }

  void invalidateCachedMovieLists() {
    _cachedMovieLists = null;
  }

  void invalidateCachedFriends() {
    _friendDataVersion++;
    _cachedFriends = null;
  }

  /// Call after adding an item to any list so activity-watching screens can refresh.
  void invalidateActivity() {
    _cachedActivity = null;
    _cachedFriendsActivity = null;
    _cachedRatings = null;
  }

  String _friendIdentitySnapshot(FriendsData? data) =>
      jsonEncode(data?.friendships
          .map((friendship) => [
                friendship.id,
                friendship.friendId,
                for (final user in [
                  friendship.friend,
                  friendship.recipient,
                  friendship.requester
                ])
                  [
                    user?.id,
                    user?.username,
                    user?.avatar?.toJson(),
                    user?.profileBadges
                  ],
              ])
          .toList());

  void applyPrefetchSnapshot(AuthPrefetchSnapshot snapshot) {
    _cachedActivity = snapshot.activity ?? _cachedActivity;
    if (snapshot.friends != null &&
        _friendIdentitySnapshot(snapshot.friends) !=
            _friendIdentitySnapshot(_cachedFriends)) {
      _friendDataVersion++;
    }
    _cachedFriends = snapshot.friends ?? _cachedFriends;
    _cachedFriendsActivity = snapshot.friendsActivity ?? _cachedFriendsActivity;
    _cachedGroups = snapshot.groups ?? _cachedGroups;
    _cachedRatings = snapshot.ratings ?? _cachedRatings;
    _cachedReviews = snapshot.reviews ?? _cachedReviews;
    _cachedTrending = snapshot.trending ?? _cachedTrending;
    _cachedNowPlaying = snapshot.nowPlaying ?? _cachedNowPlaying;
    _cachedMovieLists = snapshot.movieLists ?? _cachedMovieLists;
    if (snapshot.notifications != null) {
      final notifications = snapshot.notifications!
          .where((item) =>
              item.id == null || !_dismissedNotificationIds.contains(item.id))
          .toList(growable: false);
      _cachedNotifications = List.unmodifiable(notifications);
    }
    _cachedWatchRequests = snapshot.watchRequests ?? _cachedWatchRequests;
    setUnreadNotificationCount(
      snapshot.unreadNotificationCount ??
          _cachedNotifications?.where((item) => !item.isRead).length ??
          _unreadNotificationCount,
    );
    if (snapshot.watchProvidersByMovieId != null) {
      _cachedWatchProvidersByMovieId.addAll(snapshot.watchProvidersByMovieId!);
    }
    _cachedUserWatchProviderIds =
        snapshot.userWatchProviderIds ?? _cachedUserWatchProviderIds;
  }

  void invalidateFriendsActivity() {
    _cachedFriendsActivity = null;
  }

  void selectWatchProviderRegion(String region,
      {bool preserveUnspecified = false}) {
    if (_cachedWatchProviderRegion != region) {
      if (!preserveUnspecified || _cachedWatchProviderRegion != null) {
        _cachedWatchProvidersByMovieId.clear();
        _cachedUserWatchProviderIds = null;
      }
      _cachedWatchProviderRegion = region;
    }
  }

  void retainWatchProviderMovies(Set<int> activeIds) {
    _cachedWatchProvidersByMovieId
        .removeWhere((id, _) => !activeIds.contains(id));
  }

  /// Shares provider work within this account and rejects late progress/results
  /// after an account reset, disposal or region change.
  Future<void> ensureWatchProviders({
    required String userId,
    required String region,
    required Iterable<int> movieIds,
    required bool Function() isCurrent,
    required void Function() onChanged,
  }) async {
    if (!isCurrent()) {
      return;
    }
    final generation = _generation;
    bool current() =>
        generation == _generation &&
        isCurrent() &&
        _cachedWatchProviderRegion == region;
    selectWatchProviderRegion(region);
    final requestedIds = movieIds.toSet();
    final missing = requestedIds
        .where((id) => !_cachedWatchProvidersByMovieId.containsKey(id))
        .toSet();
    if (missing.isEmpty && _cachedUserWatchProviderIds != null) return;
    final pending = _watchProviderCacheFuture;
    if (pending != null) {
      await pending;
      if (!current()) return;
      return ensureWatchProviders(
          userId: userId,
          region: region,
          movieIds: requestedIds,
          isCurrent: isCurrent,
          onChanged: onChanged);
    }
    if (!current()) return;
    final future = _prefetchCoordinator.fetchWatchProviders(
      userId,
      missing,
      region: region,
      isCurrent: current,
      onProgress: (providers, userProviderIds) {
        if (!current()) return;
        _cachedWatchProvidersByMovieId.addAll(providers);
        _cachedUserWatchProviderIds = userProviderIds;
        onChanged();
      },
    ).then((value) {
      if (!current()) return;
      _cachedWatchProvidersByMovieId.addAll(value.providersByMovieId);
      _cachedUserWatchProviderIds = value.userProviderIds;
      onChanged();
    });
    _watchProviderCacheFuture = future;
    try {
      await future;
    } finally {
      if (identical(_watchProviderCacheFuture, future)) {
        _watchProviderCacheFuture = null;
      }
    }
  }
}
