import 'package:flixie_app/core/utils/app_logger.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friendship.dart';
import '../../data/friend_profile_service.dart';

enum FriendshipStatus { none, pending, requested, friends }

/// Other-profile state belongs to both the viewer and the viewed person.
class FriendProfileController extends ChangeNotifier {
  FriendProfileController(
      {required this.auth,
      required this.subjectId,
      this.service = const FriendProfileService()}) {
    _viewer = auth.dbUser?.id;
    auth.addListener(_authChanged);
    _useCachedFriendship();
  }
  final AuthProvider auth;
  final FriendProfileService service;
  String subjectId;
  String? _viewer;
  int generation = 0;
  final _versions = <String, int>{};
  bool _disposed = false;
  User? user;
  bool userLoading = true,
      reviewsLoading = true,
      activityLoading = true,
      friendshipStatusLoading = true,
      actionLoading = false,
      compatibilityLoading = true;
  bool activityFailed = false, reviewsFailed = false;
  List<Review> reviews = [];
  List<ActivityListItem> activity = [];
  List<MovieRating> sharedRatings = [];
  Map<int, int> myRatingValues = {};
  String? activityCursor, friendshipId;
  FriendshipStatus friendshipStatus = FriendshipStatus.none;
  int? compatibilityScore;
  int sharedMovieCount = 0,
      sharedFavCount = 0,
      selectedTab = 0,
      reviewLimit = 10;
  bool get isSelf => auth.dbUser?.id == subjectId;
  bool owns(int version, String? viewer) =>
      !_disposed && version == generation && auth.dbUser?.id == viewer;
  void change(VoidCallback update) {
    if (_disposed) return;
    update();
    notifyListeners();
  }

  bool Function() _request(String section) {
    final gen = generation, viewer = auth.dbUser?.id;
    final version = (_versions[section] ?? 0) + 1;
    _versions[section] = version;
    return () => owns(gen, viewer) && _versions[section] == version;
  }

  void _authChanged() {
    final viewer = auth.dbUser?.id;
    if (viewer == _viewer) return;
    _viewer = viewer;
    _reset();
    unawaited(loadAll());
  }

  void setSubject(String id) {
    if (id == subjectId) return;
    subjectId = id;
    _reset();
    unawaited(loadAll());
  }

  void _reset() {
    generation++;
    _versions.clear();
    change(() {
      user = null;
      userLoading = reviewsLoading = activityLoading =
          friendshipStatusLoading = compatibilityLoading = true;
      actionLoading = activityFailed = reviewsFailed = false;
      reviews = [];
      activity = [];
      sharedRatings = [];
      myRatingValues = {};
      activityCursor = friendshipId = null;
      friendshipStatus = FriendshipStatus.none;
      compatibilityScore = null;
      sharedMovieCount = sharedFavCount = selectedTab = 0;
      reviewLimit = 10;
    });
    _useCachedFriendship();
  }

  void _useCachedFriendship() {
    final cached = auth.cachedFriends;
    if (cached != null) _applyFriendship(cached, cachedOnly: true);
  }

  void _applyFriendship(FriendsData data, {bool cachedOnly = false}) {
    for (final group in [
      (data.friendships, FriendshipStatus.friends),
      (data.pendingFriends, FriendshipStatus.pending),
      (data.requestedFriends, FriendshipStatus.requested)
    ]) {
      for (final friendship in group.$1) {
        if (friendship.friendUser?.id == subjectId) {
          friendshipStatus = group.$2;
          friendshipId = friendship.id;
          friendshipStatusLoading = false;
          return;
        }
      }
    }
    if (!cachedOnly) {
      friendshipStatus = FriendshipStatus.none;
      friendshipId = null;
      friendshipStatusLoading = false;
    }
  }

  Future<void> loadAll() async {
    if (_disposed) return;
    generation++;
    _versions.clear();
    change(() => actionLoading = false);
    final gen = generation, viewer = auth.dbUser?.id;
    await loadUser();
    if (!owns(gen, viewer)) return;
    if (user == null) {
      change(() => reviewsLoading = activityLoading =
          friendshipStatusLoading = compatibilityLoading = false);
      return;
    }
    await Future.wait([
      loadReviews(),
      loadActivity(),
      loadFriendshipStatus(),
      loadCompatibility()
    ]);
  }

  Future<void> loadUser() async {
    final current = _request('user');
    final id = subjectId;
    try {
      final value = await service.user(id);
      if (current()) change(() => user = value);
    } catch (_) {
      /* Keep an already-visible same-account profile on refresh failure. */
    } finally {
      if (current()) change(() => userLoading = false);
    }
  }

  Future<void> loadReviews() async {
    final current = _request('reviews');
    change(() {
      reviewsFailed = false;
      reviewsLoading = true;
    });
    try {
      final values = await service.reviews(subjectId);
      if (current()) change(() => reviews = List.unmodifiable(values));
    } catch (_) {
      if (current()) change(() => reviewsFailed = true);
    } finally {
      if (current()) change(() => reviewsLoading = false);
    }
  }

  Future<void> loadActivity({bool more = false}) async {
    if (_disposed || (more && (activityLoading || activityCursor == null))) {
      return;
    }
    final current = _request('activity');
    change(() {
      activityLoading = true;
      activityFailed = false;
    });
    try {
      final page = await service.activity(subjectId,
          cursor: more ? activityCursor : null);
      if (!current()) return;
      change(() {
        activity = List.unmodifiable([
          if (more) ...activity,
          ...page.items.where((item) => !item.removed)
        ]);
        activityCursor = page.nextCursor;
      });
    } catch (_) {
      if (current()) change(() => activityFailed = true);
    } finally {
      if (current()) change(() => activityLoading = false);
    }
  }

  Future<void> loadFriendshipStatus() async {
    final current = _request('friendship');
    final viewer = auth.dbUser?.id;
    if (viewer == null) {
      change(() => friendshipStatusLoading = false);
      return;
    }
    try {
      final data = await service.friends(viewer);
      if (current()) change(() => _applyFriendship(data));
    } catch (_) {
      if (current()) change(() => friendshipStatusLoading = false);
    }
  }

  Future<void> loadCompatibility() async {
    final current = _request("compatibility");
    final currentUser = auth.dbUser;
    final myId = currentUser?.id;
    final myFavoriteMovies = currentUser?.favoriteMovies;
    if (myId == null || myId == subjectId) {
      if (current()) change(() => compatibilityLoading = false);
      return;
    }
    try {
      final results = await Future.wait([
        service.ratings(myId),
        service.ratings(subjectId),
      ]);
      final myRatings = results[0];
      final friendRatings = results[1];
      final myMap = {for (final r in myRatings) r.movieId: r.rating};
      final friendMap = {for (final r in friendRatings) r.movieId: r.rating};
      final sharedIds = myMap.keys.where(friendMap.containsKey).toList();

      // Factor in favourite movies
      final myFavIds = _extractFavMovieIds(myFavoriteMovies);
      final friendFavIds = _extractFavMovieIds(user?.favoriteMovies);
      final sharedFavIds = myFavIds.intersection(friendFavIds);

      // Score: rating agreement + shared favourites weighted at 2× each
      int? score;
      final sharedFavCount = sharedFavIds.length;
      if (sharedIds.isNotEmpty || sharedFavCount > 0) {
        double numerator = 0;
        for (final id in sharedIds) {
          numerator += (9 - (myMap[id]! - friendMap[id]!).abs()) / 9.0;
        }
        // Each shared favourite = perfect agreement, double-weighted
        numerator += sharedFavCount * 2.0;
        final denominator = sharedIds.length + sharedFavCount * 2;
        score = (numerator / denominator * 100).round();
      }
      if (current()) {
        change(() {
          sharedRatings = List.unmodifiable(
              friendRatings.where((r) => myMap.containsKey(r.movieId)));
          myRatingValues = myMap;
          compatibilityScore = score;
          sharedMovieCount = sharedIds.length;
          this.sharedFavCount = sharedFavCount;
          compatibilityLoading = false;
        });
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] compatibility load error: $e');
      if (current()) change(() => compatibilityLoading = false);
    }
  }

  static Set<int> _extractFavMovieIds(List<dynamic>? favorites) {
    if (favorites == null) return {};
    final ids = <int>{};
    for (final item in favorites) {
      if (item is FavoriteMovie) {
        if (item.removed != true) ids.add(item.movieId);
      } else if (item is Map<String, dynamic> && item['removed'] != true) {
        final id = item['movieId'] ?? item['id'];
        if (id is int) ids.add(id);
      } else if (item is int) {
        ids.add(item);
      }
    }
    return ids;
  }

  @override
  void dispose() {
    _disposed = true;
    generation++;
    auth.removeListener(_authChanged);
    super.dispose();
  }
}
