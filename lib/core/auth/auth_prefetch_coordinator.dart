import 'dart:async';

import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/profile/data/notification_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/home/data/trending_service.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/notification_visibility.dart';
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
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
    String region = 'US',
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
    int? unreadNotificationCount;
    List<FlixieNotification>? notifications;
    Map<int, List<WatchProvider>>? watchProvidersByMovieId;
    Set<int>? userWatchProviderIds;

    await Future.wait([
      _profileLookupController
          .getUserActivity(userId)
          .then((v) => activity = v, onError: (_) {}),
      _friendActionsController
          .getFriends(userId)
          .then((v) => friends = v, onError: (_) {}),
      _friendActionsController
          .getFriendsActivityLists(userId)
          .then((v) => friendsActivity = v, onError: (_) {}),
      GroupService.getUserGroups(userId)
          .then((v) => groups = v, onError: (_) {}),
      _profileLookupController
          .getUserMovieRatings(userId)
          .then((v) => ratings = v, onError: (_) {}),
      _profileLookupController
          .getUserMovieReviews(userId)
          .then((v) => reviews = v, onError: (_) {}),
      TrendingService.getTrendingMovies()
          .then((v) => trending = v, onError: (_) {}),
      _movieService
          .getNowPlayingMovies(region: region)
          .then((v) => nowPlaying = v, onError: (_) {}),
      NotificationService.getNotifications(userId).then((value) {
        final visible = visibleNotificationsForUser(value, userId);
        notifications = visible;
        unreadNotificationCount = visible.where((item) => !item.isRead).length;
      }, onError: (_) {}),
      fetchWatchProviders(userId, watchlistMovieIds, region: region).then(
          (value) {
        watchProvidersByMovieId = value.providersByMovieId;
        userWatchProviderIds = value.userProviderIds;
      }, onError: (_) {}),
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
      unreadNotificationCount: unreadNotificationCount,
      notifications: notifications,
      watchProvidersByMovieId: watchProvidersByMovieId,
      userWatchProviderIds: userWatchProviderIds,
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
    final ids = movieIds.toSet().toList(growable: false);
    final userProviders = await UserService.getUserWatchProviders(userId);
    final providersByMovieId = <int, List<WatchProvider>>{};

    for (var start = 0; start < ids.length; start += 5) {
      final end = (start + 5).clamp(0, ids.length);
      final results = await Future.wait(
        ids.sublist(start, end).map((movieId) async {
          try {
            return MapEntry(
              movieId,
              await _movieService.getMovieWatchProviders(movieId, region),
            );
          } catch (_) {
            return MapEntry(movieId, <WatchProvider>[]);
          }
        }),
      );
      providersByMovieId.addEntries(results);
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
