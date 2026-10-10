import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/data/notification_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';

import 'controllers/notification_inbox_controller.dart';

Future<void> respondToInboxNotification(
    BuildContext context,
    NotificationInboxController controller,
    FlixieNotification notification,
    String action) async {
  final id = notification.id;
  if (id == null || !controller.beginResponse(id)) return;
  final token = controller.generation;
  final auth = context.read<AuthProvider>();
  final userId = auth.dbUser?.id;
  bool isCurrent() =>
      context.mounted && controller.owns(token) && auth.dbUser?.id == userId;
  final analytics = context.read<AnalyticsController>();
  try {
    final requestId = notification.linkedRequestId;
    if (requestId == null) throw StateError('Missing invitation request');

    if (notification.type == FlixieNotification.friendRequest) {
      if (action == FlixieNotification.actionAccepted) {
        await FriendActionsController.instance.acceptRequest(requestId);
      } else {
        await FriendActionsController.instance.declineRequest(requestId);
      }
    }

    // For watch requests, also update the underlying request record.
    if (notification.type == FlixieNotification.movieWatchRequest ||
        notification.type == FlixieNotification.showWatchRequest) {
      {
        final status = action == FlixieNotification.actionAccepted
            ? 'ACCEPTED'
            : 'DECLINED';
        await RequestService.updateRequest(requestId, status);
      }
    }

    // For group invites and group requests, also update the underlying request record.
    if (notification.type == FlixieNotification.groupInvite ||
        notification.type == FlixieNotification.groupRequest) {
      {
        final status = action == FlixieNotification.actionAccepted
            ? 'ACCEPTED'
            : 'DECLINED';
        await RequestService.updateRequest(requestId, status);
      }
    }

    if (!isCurrent()) return;
    // The request endpoint has already saved the response and closed its
    // notification. A secondary inbox update must not undo that success.
    try {
      await NotificationService.updateNotification(
        id,
        action: action,
        read: true,
      );
    } catch (error) {
      logger
          .w('[NotificationScreen] response saved; inbox sync failed: $error');
    }
    if (!isCurrent()) return;
    try {
      if (action == FlixieNotification.actionAccepted) {
        if (notification.type == FlixieNotification.friendRequest) {
          await analytics.friendConnected();
        } else if (notification.type == FlixieNotification.movieWatchRequest ||
            notification.type == FlixieNotification.showWatchRequest) {
          final request = notification.linkedWatchRequest;
          await analytics.watchPlanAccepted(
            watchPlanId: requestId,
            contentId: request?.analyticsContentId,
            contentType: request?.analyticsContentType ??
                (notification.type == FlixieNotification.showWatchRequest
                    ? 'show'
                    : 'movie'),
            planType: 'friend',
            participantCount: 2,
            source: 'notification',
          );
        }
      }
    } catch (error) {
      logger.w('[NotificationScreen] response analytics failed: $error');
    }

    if (isCurrent()) {
      controller.responseSaved(id, token);
      try {
        if (userId != null &&
            notification.type == FlixieNotification.friendRequest) {
          final friends =
              await FriendActionsController.instance.getFriends(userId);
          if (isCurrent()) auth.updateCachedFriends(friends);
        } else if (userId != null &&
            notification.type == FlixieNotification.groupInvite) {
          // Group membership has just changed on the server. Refresh this
          // cache before returning to Social so its existing IndexedStack
          // cannot render the stale pre-invite group list.
          try {
            final groups = await GroupService.getUserGroups(userId);
            if (isCurrent()) auth.updateCachedGroups(groups);
          } catch (error) {
            // The request itself has succeeded. Preserve that success and
            // fall back to the usual background refresh if the cache fetch
            // happens to fail.
            logger.w('[NotificationScreen] group cache refresh failed: $error');
            if (isCurrent()) await auth.refreshUserData();
          }
          if (isCurrent()) TabRefreshController.requestSocialRefresh();
        } else {
          await auth.refreshUserData();
        }
      } catch (error) {
        logger.w(
            '[NotificationScreen] response saved; cache refresh failed: $error');
      }
      if (isCurrent()) TabRefreshController.requestSocialRefresh();
      if (!context.mounted || !isCurrent()) return;
      // Show success toast
      final isWatchPlan =
          notification.type == FlixieNotification.movieWatchRequest ||
              notification.type == FlixieNotification.showWatchRequest ||
              notification.type == FlixieNotification.groupRequest;
      final subject = isWatchPlan ? 'Watch Plan' : 'Request';
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
          type: FlixieToastType.success,
          content: Text(
            action == FlixieNotification.actionAccepted
                ? '$subject accepted successfully.'
                : '$subject declined successfully.',
          ),
          backgroundColor: context.colors.surfaceElevated,
        ),
      );
    }
  } catch (e) {
    logger.e('[NotificationScreen] respond error: $e');
    if (context.mounted && isCurrent()) {
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
          type: FlixieToastType.error,
          content: Text(
            action == FlixieNotification.actionAccepted
                ? 'Failed to accept. Please try again.'
                : 'Failed to decline. Please try again.',
          ),
          backgroundColor: context.colors.danger,
        ),
      );
    }
  } finally {
    controller.endResponse(id, token);
  }
}
