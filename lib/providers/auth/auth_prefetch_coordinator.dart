import 'dart:async';

import '../../models/activity_list_item.dart';
import '../../models/friendship.dart';
import '../../models/movie_rating.dart';
import '../../models/movie_short.dart';
import '../../models/review.dart';
import '../../services/movie_service.dart';
import '../../services/notification_service.dart';
import '../../services/trending_service.dart';
import '../../services/user_service.dart';
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
    List<MovieShort>? trending;
    List<MovieShort>? nowPlaying;

    final results = await Future.wait([
      _profileLookupController.getUserActivity(userId).then((v) => activity = v, onError: (_) {}),
      _friendActionsController.getFriends(userId),
      _friendActionsController.getFriendsActivityLists(userId)
          .then((v) => friendsActivity = v, onError: (_) {}),
      _profileLookupController.getUserMovieRatings(userId),
      _profileLookupController.getUserMovieReviews(userId),
      TrendingService.getTrendingMovies().then((v) => trending = v, onError: (_) {}),
      _movieService.getNowPlayingMovies(region: region).then((v) => nowPlaying = v, onError: (_) {}),
      NotificationService.getNotifications(userId)
          .then((v) => v.where((n) => !n.isRead).length, onError: (_) => null),
    ]).timeout(const Duration(seconds: 10), onTimeout: () => []);

    logger.i('[AuthPrefetchCoordinator] Prefetch complete for $userId');
    return AuthPrefetchSnapshot(
      activity: activity,
      friends: results.length > 1 ? results[1] as FriendsData : null,
      friendsActivity: friendsActivity,
      ratings: results.length > 3 ? results[3] as List<MovieRating> : null,
      reviews: results.length > 4 ? results[4] as List<Review> : null,
      trending: trending,
      nowPlaying: nowPlaying,
      unreadNotificationCount: results.length > 7 ? results[7] as int? : null,
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

  Future<void> refreshCurrentUser(
    String firebaseUid,
    Future<void> Function(String userId, String region) onResolved,
  ) async {
    try {
      final user = await UserService.getUserByExternalId(firebaseUid);
      final region = (user.country?['isoCode'] as String?)?.toUpperCase() ?? 'US';
      await onResolved(user.id, region);
    } catch (e) {
      logger.w('[AuthPrefetchCoordinator] refreshUserData error: $e');
    }
  }
}
