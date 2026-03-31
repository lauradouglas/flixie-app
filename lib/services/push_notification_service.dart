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

    // Get the FCM token and register it with the backend.
    await _registerToken(userId);

    // Re-register whenever the token is rotated by Firebase.
    _messaging.onTokenRefresh.listen((token) {
      logger.d('[FCM] Token refreshed – updating backend');
      _saveToken(userId, token);
    });

    // Foreground messages: FCM does NOT show a system notification by default,
    // so we display one manually via flutter_local_notifications.
    FirebaseMessaging.onMessage.listen((message) {
      logger.d('[FCM] Foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Notification tap while app is in the background (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      logger.d(
          '[FCM] Notification tapped (background): ${message.notification?.title}');
      _navigateToNotifications(navigatorKey);
    });

    // Notification tap from terminated state.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      logger.d(
          '[FCM] App launched via notification: ${initialMessage.notification?.title}');
      // Give the widget tree time to fully mount before navigating.
      Future<void>.delayed(_launchNavigationDelay, () {
        _navigateToNotifications(navigatorKey);
      });
    }
  }

  /// Removes the stored FCM token from the backend when the user signs out.
  static Future<void> removeToken(String userId) async {
    try {
      await UserService.removeFcmToken(userId);
      logger.i('[FCM] Token removed from backend');
    } catch (e) {
      logger.w('[FCM] Failed to remove FCM token from backend: $e');
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
      onDidReceiveNotificationResponse: (_) {
        _navigateToNotifications(navigatorKey);
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
      // On iOS the APNs token must be available before requesting the FCM token.
      if (Platform.isIOS) {
        await _messaging.getAPNSToken();
      }

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
    );
  }

  static void _navigateToNotifications(GlobalKey<NavigatorState> navigatorKey) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).go('/notifications');
  }
}
