import 'dart:async';

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
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/profile/data/notification_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/home/data/trending_service.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/notification_visibility.dart';
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/features/profile/presentation/controllers/profile_lookup_controller.dart';
import 'package:flixie_app/core/auth/auth_prefetch_snapshot.dart';

class AuthPrefetchCoordinator {
  AuthPrefetchCoordinator({
    required MovieService movieService,
    FriendActionsController? friendActionsController,
    ProfileLookupController? profileLookupController,
  })  : _movieService = movieService,
        _friendActionsController =
            friendActionsController ?? FriendActionsController.instance,
        _profileLookupController =
            profileLookupController ?? ProfileLookupController.instance;

  final MovieService _movieService;
  final FriendActionsController _friendActionsController;
  final ProfileLookupController _profileLookupController;

  Future<AuthPrefetchSnapshot> prefetch(
    String userId, {
    String region = 'GB',
    Iterable<int> watchlistMovieIds = const [],
  }) async {
    List<ActivityListItem>? activity;
    List<ActivityListItem>? friendsActivity;
    FriendsData? friends;
    List<Group>? groups;
    List<MovieRating>? ratings;
    List<Review>? reviews;
    List<MovieShort>? trending;
    List<MovieShort>? nowPlaying;
    List<MovieList>? movieLists;
    int? unreadNotificationCount;
    List<FlixieNotification>? notifications;
    Map<int, List<WatchProvider>>? watchProvidersByMovieId;
    Set<int>? userWatchProviderIds;
    List<WatchRequest>? watchRequests;

    // Give the essential Home hero request priority. Home shares this GET.
    try {
      trending = await TrendingService.getTrendingMovies();
    } catch (_) {}
    await Future.wait([
      _profileLookupController.getUserActivity(userId).then<void>((v) {
        activity = v;
      }, onError: (_, __) {}),
      _friendActionsController.getFriends(userId).then<void>((v) {
        friends = v;
      }, onError: (_, __) {}),
      FriendService.getFriendsActivityLists(userId, days: 30, limit: 200)
          .then<void>((v) {
        friendsActivity = v;
      }, onError: (_, __) {}),
      GroupService.getUserGroups(userId).then<void>((v) {
        groups = v;
      }, onError: (_, __) {}),
      RequestService.getWatchRequests(userId).then<void>((v) {
        watchRequests = v;
      }, onError: (_, __) {}),
      _profileLookupController.getUserMovieRatings(userId).then<void>((v) {
        ratings = v;
      }, onError: (_, __) {}),
      _profileLookupController.getUserMovieReviews(userId).then<void>((v) {
        reviews = v;
      }, onError: (_, __) {}),
      _movieService.getNowPlayingMovies(region: region).then<void>((v) {
        nowPlaying = v;
      }, onError: (_, __) {}),
      UserService.getMovieLists(userId).then<void>((v) {
        movieLists = v;
      }, onError: (_, __) {}),
      NotificationService.getNotifications(userId).then((value) {
        final visible = visibleNotificationsForUser(value, userId);
        notifications = visible;
        unreadNotificationCount = visible.where((item) => !item.isRead).length;
      }, onError: (_, __) {}),
      fetchWatchProviders(userId, watchlistMovieIds, region: region).then(
          (value) {
        watchProvidersByMovieId = value.providersByMovieId;
        userWatchProviderIds = value.userProviderIds;
      }, onError: (_, __) {}),
    ]).timeout(const Duration(seconds: 10), onTimeout: () => []);

    logger.i('[AuthPrefetchCoordinator] Prefetch complete for $userId');
    return AuthPrefetchSnapshot(
      activity: activity,
      friends: friends,
      friendsActivity: friendsActivity,
      groups: groups,
      ratings: ratings,
      reviews: reviews,
      trending: trending,
      nowPlaying: nowPlaying,
      movieLists: movieLists,
      unreadNotificationCount: unreadNotificationCount,
      notifications: notifications,
      watchProvidersByMovieId: watchProvidersByMovieId,
      userWatchProviderIds: userWatchProviderIds,
      watchRequests: watchRequests,
    );
  }

  Future<
      ({
        Map<int, List<WatchProvider>> providersByMovieId,
        Set<int> userProviderIds,
      })> fetchWatchProviders(
    String userId,
    Iterable<int> movieIds, {
    required String region,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    final ids = movieIds.toSet().toList(growable: false);
    final userProviders = await UserService.getUserWatchProviders(userId);
    final providersByMovieId = <int, List<WatchProvider>>{};

    for (var start = 0; start < ids.length; start += 5) {
      if (DateTime.now().isAfter(deadline)) break;
      final end = (start + 5).clamp(0, ids.length);
      final results = await Future.wait(
        ids.sublist(start, end).map((movieId) async {
          try {
            return MapEntry(
              movieId,
              await _movieService.getMovieWatchProviders(movieId, region),
            );
          } catch (_) {
            return null; // Failure is not a successfully cached empty result.
          }
        }),
      );
      providersByMovieId
          .addEntries(results.whereType<MapEntry<int, List<WatchProvider>>>());
    }

    return (
      providersByMovieId: providersByMovieId,
      userProviderIds: userProviders.map((provider) => provider.id).toSet(),
    );
  }

  Future<int?> fetchUnreadCount(String userId) async {
    try {
      final notifications = await NotificationService.getNotifications(userId);
      return visibleUnreadNotificationCount(notifications, userId);
    } catch (e) {
      logger
          .w('[AuthPrefetchCoordinator] notification count refresh error: $e');
      return null;
    }
  }
}
