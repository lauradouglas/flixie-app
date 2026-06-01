import 'dart:async';

import '../../models/activity_list_item.dart';
import '../../models/friendship.dart';
import '../../models/movie_rating.dart';
import '../../models/movie_short.dart';
import '../../models/review.dart';
import '../../services/movie_service.dart';
import '../../services/notification_service.dart';
import '../../services/trending_service.dart';
import '../../utils/app_logger.dart';
import '../../presentation/shared/friend_actions_controller.dart';
import '../../presentation/shared/profile_lookup_controller.dart';
import 'auth_prefetch_snapshot.dart';

class AuthPrefetchCoordinator {
  AuthPrefetchCoordinator({
    required MovieService movieService,
    FriendActionsController? friendActionsController,
    ProfileLookupController? profileLookupController,
  })  : _movieService = movieService,
        _friendActionsController = friendActionsController ?? FriendActionsController.instance,
        _profileLookupController = profileLookupController ?? ProfileLookupController.instance;

  final MovieService _movieService;
  final FriendActionsController _friendActionsController;
  final ProfileLookupController _profileLookupController;

  Future<AuthPrefetchSnapshot> prefetch(String userId, {String region = 'US'}) async {
    List<ActivityListItem>? activity;
    List<ActivityListItem>? friendsActivity;
    FriendsData? friends;
    List<MovieRating>? ratings;
    List<Review>? reviews;
    List<MovieShort>? trending;
    List<MovieShort>? nowPlaying;
    int? unreadNotificationCount;

    await Future.wait([
      _profileLookupController.getUserActivity(userId).then((v) => activity = v, onError: (_) {}),
      _friendActionsController.getFriends(userId).then((v) => friends = v, onError: (_) {}),
      _friendActionsController.getFriendsActivityLists(userId)
          .then((v) => friendsActivity = v, onError: (_) {}),
      _profileLookupController.getUserMovieRatings(userId).then((v) => ratings = v, onError: (_) {}),
      _profileLookupController.getUserMovieReviews(userId).then((v) => reviews = v, onError: (_) {}),
      TrendingService.getTrendingMovies().then((v) => trending = v, onError: (_) {}),
      _movieService.getNowPlayingMovies(region: region).then((v) => nowPlaying = v, onError: (_) {}),
      NotificationService.getNotifications(userId)
          .then((v) => unreadNotificationCount = v.where((n) => !n.isRead).length, onError: (_) {}),
    ]).timeout(const Duration(seconds: 10), onTimeout: () => []);

    logger.i('[AuthPrefetchCoordinator] Prefetch complete for $userId');
    return AuthPrefetchSnapshot(
      activity: activity,
      friends: friends,
      friendsActivity: friendsActivity,
      ratings: ratings,
      reviews: reviews,
      trending: trending,
      nowPlaying: nowPlaying,
      unreadNotificationCount: unreadNotificationCount,
    );
  }

  Future<int?> fetchUnreadCount(String userId) async {
    try {
      final notifications = await NotificationService.getNotifications(userId);
      return notifications.where((n) => !n.isRead).length;
    } catch (e) {
      logger.w('[AuthPrefetchCoordinator] notification count refresh error: $e');
      return null;
    }
  }

}
