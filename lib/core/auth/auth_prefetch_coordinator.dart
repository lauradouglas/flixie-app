import 'dart:async';

import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/profile/data/notification_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/notification_visibility.dart';
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';
import 'package:flixie_app/features/profile/presentation/controllers/profile_lookup_controller.dart';
import 'package:flixie_app/core/auth/auth_prefetch_snapshot.dart';

class AuthPrefetchCoordinator {
  AuthPrefetchCoordinator({
    required MovieService movieService,
    FriendActionsController? friendActionsController,
    ProfileLookupController? profileLookupController,
  }) : _movieService = movieService;

  final MovieService _movieService;

  Future<AuthPrefetchSnapshot> prefetch(
    String userId, {
    String region = 'GB',
    Iterable<int> watchlistMovieIds = const [],
  }) async {
    // Watchlist and favourites are already in the authenticated User snapshot.
    // Warm only the notification inbox here. Home owns its own sections; history,
    // reviews, ratings and streaming availability load at their point of use.
    final notifications = await NotificationService.getNotifications(userId);
    final visible = visibleNotificationsForUser(notifications, userId);
    return AuthPrefetchSnapshot(
      notifications: visible,
      unreadNotificationCount: visible.where((item) => !item.isRead).length,
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
    bool Function()? isCurrent,
    void Function(Map<int, List<WatchProvider>>, Set<int>)? onProgress,
  }) async {
    final ids = movieIds.toSet().toList(growable: false);
    final userProviders = await UserService.getUserWatchProviders(userId);
    final providersByMovieId = <int, List<WatchProvider>>{};

    final userProviderIds =
        userProviders.map((provider) => provider.id).toSet();
    if (isCurrent == null || isCurrent()) {
      onProgress?.call({}, userProviderIds);
    }
    for (var start = 0; start < ids.length; start += 5) {
      if (isCurrent != null && !isCurrent()) break;
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
      final batch = Map<int, List<WatchProvider>>.fromEntries(
          results.whereType<MapEntry<int, List<WatchProvider>>>());
      providersByMovieId.addAll(batch);
      if (isCurrent == null || isCurrent()) {
        onProgress?.call(batch, userProviderIds);
      }
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
