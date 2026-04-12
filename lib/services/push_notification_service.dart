import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../utils/app_logger.dart';
import 'user_service.dart';

/// Top-level handler for messages received while the app is in the background
/// or terminated. Must be a top-level function (not a class method) so that
/// FCM can invoke it in a separate isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  logger.d('[FCM] Background message received: ${message.notification?.title}');
}

/// Manages Firebase Cloud Messaging for push notifications.
///
/// Call [initialize] after the user is authenticated to register the device
/// token with the backend and wire up foreground / background handlers.
/// Call [removeToken] when the user signs out.
class PushNotificationService {
  PushNotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  /// The userId of the currently logged-in user. Used to suppress
  /// notifications intended for a different user (e.g. the sender).
  static String? _currentUserId;

  /// High-importance notification channel used for Android.
  static const _androidChannel = AndroidNotificationChannel(
    'flixie_notifications',
    'Flixie Notifications',
    description: 'Friend and watch-request notifications from Flixie.',
    importance: Importance.high,
  );

  /// Delay before navigating when the app is launched from a terminated state
  /// via a notification tap. The widget tree needs time to fully mount before
  /// GoRouter can process a navigation call.
  static const _launchNavigationDelay = Duration(milliseconds: 500);

  /// Initialises FCM for [userId].
  ///
  /// * Requests notification permissions (required on iOS / Android 13+).
  /// * Registers the FCM token with the backend.
  /// * Wires up foreground and background notification handlers.
  /// * When a notification is tapped the app navigates to `/notifications`.
  ///
  /// Safe to call multiple times; subsequent calls are no-ops for the
  /// permission / channel setup that has already been performed.
  static Future<void> initialize({
    required String userId,
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _currentUserId = userId;
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    logger.i('[FCM] Permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      logger.w('[FCM] Notification permission denied – skipping FCM setup');
      return;
    }

    // Initialise flutter_local_notifications so we can display a heads-up
    // banner when a message arrives while the app is in the foreground.
    await _initLocalNotifications(navigatorKey);

    // iOS: allow FCM to show alert/badge/sound when the app is in the foreground.
    // Without this iOS silently suppresses foreground FCM messages.
    if (Platform.isIOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Get the FCM token and register it with the backend.
    await _registerToken(userId);

    // Re-register whenever the token is rotated by Firebase.
    _messaging.onTokenRefresh.listen((token) {
      logger.d('[FCM] Token refreshed – updating backend');
      _saveToken(userId, token);
    });

    // Foreground messages: FCM does NOT show a system notification by default,
    // so we display one manually via flutter_local_notifications.
    // Only show if we still have a logged-in user (guards against post-logout delivery).
    FirebaseMessaging.onMessage.listen((message) {
      logger.d('[FCM] Foreground message: ${message.notification?.title}');
      if (_currentUserId == null) {
        logger.d('[FCM] Suppressing foreground message — no user logged in');
        return;
      }
      // If the backend puts the recipient userId in data, skip if it
      // doesn't match (prevents sender seeing their own notification).
      final recipientId = message.data['recipientId'] as String?;
      if (recipientId != null && recipientId != _currentUserId) {
        logger.d('[FCM] Suppressing foreground message — not for current user');
        return;
      }
      _showLocalNotification(message);
    });

    // Notification tap while app is in the background (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      logger.d(
          '[FCM] Notification tapped (background): ${message.notification?.title}');
      _navigateFromMessage(message, navigatorKey);
    });

    // Notification tap from terminated state.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      logger.d(
          '[FCM] App launched via notification: ${initialMessage.notification?.title}');
      // Give the widget tree time to fully mount before navigating.
      Future<void>.delayed(_launchNavigationDelay, () {
        _navigateFromMessage(initialMessage, navigatorKey);
      });
    }
  }

  /// Removes the stored FCM token from the backend and deregisters the device
  /// from FCM so no further messages are delivered after sign-out.
  static Future<void> removeToken(String userId) async {
    _currentUserId = null;
    try {
      await UserService.removeFcmToken(userId);
      logger.i('[FCM] Token removed from backend');
    } catch (e) {
      logger.w('[FCM] Failed to remove FCM token from backend: $e');
    }
    try {
      await _messaging.deleteToken();
      logger.i('[FCM] FCM token deleted from Firebase — device unsubscribed');
    } catch (e) {
      logger.w('[FCM] Failed to delete FCM token from Firebase: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static Future<void> _initLocalNotifications(
      GlobalKey<NavigatorState> navigatorKey) async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final path = response.payload;
        final context = navigatorKey.currentContext;
        if (context == null) return;
        if (path != null && path.isNotEmpty) {
          GoRouter.of(context).go(path);
        } else {
          _navigateToNotifications(navigatorKey);
        }
      },
    );

    // Create (or update) the Android notification channel.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  static Future<void> _registerToken(String userId) async {
    try {
      // On iOS: get the APNs token first (it must exist before we can get
      // or delete an FCM token). Only then delete the old FCM token.
      if (Platform.isIOS) {
        String? apnsToken;
        for (var i = 0; i < 5; i++) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) break;
          await Future<void>.delayed(const Duration(seconds: 2));
        }
        if (apnsToken == null) {
          logger.w(
              '[FCM] APNs token unavailable after retries – skipping FCM registration');
          return;
        }
        logger.d('[FCM] APNs token obtained');
      }

      // Delete the existing FCM token so Firebase issues a brand-new one,
      // breaking any stale association with a previous user on this device.
      await _messaging.deleteToken();
      // Brief pause after delete to let Firebase settle, especially on iOS.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(userId, token);
      } else {
        logger.w('[FCM] FCM token returned null');
      }
    } catch (e) {
      logger.w('[FCM] Failed to obtain/register FCM token: $e');
    }
  }

  static Future<void> _saveToken(String userId, String token) async {
    try {
      await UserService.saveFcmToken(userId, token);
      logger.i('[FCM] Token saved to backend');
    } catch (e) {
      logger.w('[FCM] Failed to save FCM token to backend: $e');
    }
  }

  static void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          icon: '@mipmap/launcher_icon',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // Attach the raw data so the local notification tap can also deep-link.
      payload: _buildDeepLinkPath(message.data),
    );
  }

  /// Determines the destination route for a notification based on its data
  /// payload, and navigates there.
  ///
  /// Supported data keys (sent by the backend):
  ///   type        — notification type string (matches FlixieNotification consts)
  ///   groupId     — UUID of the group (for group/watch-request notifications)
  ///   movieId     — TMDB movie id (for movie watch-request notifications)
  ///   friendId    — userId of the sender (for friend-request notifications)
  static void _navigateFromMessage(
    RemoteMessage message,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    final path = _buildDeepLinkPath(message.data);
    logger.d('[FCM] Deep-link → $path');
    final context = navigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).go(path);
  }

  /// Converts a notification data map into a GoRouter path.
  static String _buildDeepLinkPath(Map<String, dynamic> data) {
    final type = (data['type'] as String? ?? '').toUpperCase();
    final groupId = data['groupId'] as String?;
    final friendId = data['friendId'] as String?;

    // Group watch-request → open the group on the Requests tab.
    // The GroupDetailScreen reads an optional `tab` query param for this.
    if ((type == 'MOVIE_WATCH_REQUEST' ||
            type == 'SHOW_WATCH_REQUEST' ||
            type == 'GROUP_REQUEST') &&
        groupId != null &&
        groupId.isNotEmpty) {
      return '/groups/$groupId?tab=requests';
    }

    // Group invite → open the group detail.
    if (type == 'GROUP_INVITE' && groupId != null && groupId.isNotEmpty) {
      return '/groups/$groupId';
    }

    // Friend request → open friend profile if we have their id.
    if (type == 'FRIEND_REQUEST' && friendId != null && friendId.isNotEmpty) {
      return '/friends/$friendId';
    }

    // Default fallback.
    return '/notifications';
  }

  static void _navigateToNotifications(GlobalKey<NavigatorState> navigatorKey) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).go('/notifications');
  }
}
