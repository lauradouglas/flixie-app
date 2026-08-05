import 'dart:io';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/core/auth/firebase_options.dart';
import 'package:flixie_app/core/auth/notification_deep_link.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';

bool _hasFirebaseDartDefines(FirebaseOptions options) {
  return options.apiKey.isNotEmpty &&
      options.appId.isNotEmpty &&
      options.messagingSenderId.isNotEmpty &&
      options.projectId.isNotEmpty;
}

/// Top-level handler for messages received while the app is in the background
/// or terminated. Must be a top-level function (not a class method) so that
/// FCM can invoke it in a separate isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (_hasFirebaseDartDefines(options)) {
        await Firebase.initializeApp(
          options: options,
        );
      } else {
        await Firebase.initializeApp();
      }
    }
  } catch (e) {
    logger.w('[FCM] Background isolate Firebase init failed: $e');
  }

  logger.d(
      '[FCM] Background message received id=${message.messageId} title=${message.notification?.title} data=${message.data}');

  // Android displays notification payloads itself in the background, but
  // data-only watch-request pushes are silent unless the app shows them.
  if (message.notification == null) {
    await PushNotificationService.showBackgroundDataNotification(message);
  }
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
  static const _nativeTapChannel = MethodChannel('flixie/push_taps');
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _onMessageSubscription;
  static StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;
  static Future<void>? _initializationFuture;
  static String? _initializedUserId;
  static Timer? _pendingNavigationTimer;
  static GoRouter? _router;
  static String? _pendingNavigationPath;
  static bool _navigationReady = false;
  static bool _nativeTapBridgeInitialized = false;
  static String? _lastNavigatedPath;
  static DateTime? _lastNavigatedAt;

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

  static const _navigationRetryDelay = Duration(milliseconds: 250);
  static const _duplicateNavigationWindow = Duration(seconds: 2);
  static const int _maxNavigationAttempts = 12;

  /// Connects push navigation directly to the app router. Any notification
  /// tapped during startup is retained and applied once routing is available.
  static void attachRouter(GoRouter router) {
    _router = router;
  }

  /// Captures an FCM notification launch before the widget tree and auth
  /// redirects start. Navigation is deliberately deferred until [initialize]
  /// confirms that the signed-in app shell is ready.
  static Future<void> captureInitialNotification() async {
    _initializeNativeTapBridge();
    _ensureRemoteTapListener();
    try {
      final message = await _messaging.getInitialMessage();
      if (message == null) return;
      _pendingNavigationPath = notificationDeepLinkPath(message.data);
      logger.i(
        '[FCM] Captured cold-start notification → $_pendingNavigationPath',
      );
      _flushPendingNavigation();
    } catch (error) {
      logger.w('[FCM] Failed to capture cold-start notification: $error');
    }
  }

  static void _initializeNativeTapBridge() {
    if (_nativeTapBridgeInitialized || !Platform.isIOS) return;
    _nativeTapBridgeInitialized = true;
    _nativeTapChannel.setMethodCallHandler((call) async {
      if (call.method == 'notificationTapped') {
        _handleNativeTapPayload(call.arguments);
      }
    });
    unawaited(_nativeTapChannel
        .invokeMethod<Object?>('getInitialPushTap')
        .then(_handleNativeTapPayload)
        .catchError((Object error) {
      logger.w('[FCM] Native initial notification lookup failed: $error');
    }));
  }

  static void _handleNativeTapPayload(Object? arguments) {
    if (arguments is! Map || arguments.isEmpty) return;
    final data = <String, dynamic>{
      for (final entry in arguments.entries)
        entry.key.toString(): entry.value?.toString(),
    };
    final path = notificationDeepLinkPath(data);
    logger.i('[FCM] Native iOS notification tap → $path data=$data');
    if (!_navigationReady || _router == null) {
      _pendingNavigationPath = path;
      return;
    }
    _navigateWithRouter(path);
  }

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
  }) {
    if (_initializedUserId == userId && _initializationFuture != null) {
      logger.d('[FCM] Push service already initialized for userId=$userId');
      return _initializationFuture!;
    }

    _initializedUserId = userId;
    final future = _initialize(userId: userId, navigatorKey: navigatorKey);
    _initializationFuture = future;
    return future;
  }

  static Future<void> _initialize({
    required String userId,
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _currentUserId = userId;
    _navigationReady = true;
    _flushPendingNavigation();
    logger.i(
        '[FCM] Initializing push service (platform=${Platform.operatingSystem}, userId=$userId)');

    // Ensure old listeners do not duplicate local notifications across re-logins.
    await _tokenRefreshSubscription?.cancel();
    await _onMessageSubscription?.cancel();
    _ensureRemoteTapListener();

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    logger.i(
      '[FCM] Permission status: auth=${settings.authorizationStatus}, '
      'alert=${settings.alert}, badge=${settings.badge}, sound=${settings.sound}, '
      'announcement=${settings.announcement}, carPlay=${settings.carPlay}, '
      'criticalAlert=${settings.criticalAlert}, lockScreen=${settings.lockScreen}, '
      'notificationCenter=${settings.notificationCenter}',
    );

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
      logger.d(
          '[FCM] iOS foreground presentation enabled (alert/badge/sound=true)');

      // Ensure Firebase Messaging auto-init is enabled so token generation starts.
      await _messaging.setAutoInitEnabled(true);
      logger.d('[FCM] iOS auto-init enabled');
    }

    // Re-register whenever the token is rotated by Firebase.
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      logger.d(
          '[FCM] Token refreshed: ${_redactToken(token)} – updating backend for userId=$userId');
      _saveToken(userId, token);
    });

    // Token registration can wait for APNs retries on iOS. Do not let that
    // delay installing tap listeners or consuming the launch notification.
    unawaited(_registerToken(userId));

    // Foreground messages: FCM does NOT show a system notification by default,
    // so we display one manually via flutter_local_notifications.
    // Only show if we still have a logged-in user (guards against post-logout delivery).
    _onMessageSubscription = FirebaseMessaging.onMessage.listen((message) {
      logger.d('[FCM] Foreground message: ${message.notification?.title}');
      logger.d('[FCM] Foreground payload: data=${message.data}');
      if (_currentUserId == null) {
        logger.d('[FCM] Suppressing foreground message - no user logged in');
        return;
      }
      // If the backend puts the recipient userId in data, skip if it
      // doesn't match (prevents sender seeing their own notification).
      final recipientId = message.data['recipientId'] as String?;
      if (recipientId != null && recipientId != _currentUserId) {
        logger.d('[FCM] Suppressing foreground message - not for current user');
        return;
      }

      // On iOS, if this is a notification message, the OS can present it
      // directly because foreground presentation options are enabled.
      if (Platform.isIOS && message.notification != null) {
        logger.d(
            '[FCM] iOS foreground notification handled by system presentation');
        return;
      }

      unawaited(_showLocalNotification(message));
    });

    // Terminated-state notification taps are captured once during main()
    // before auth redirects begin. Do not call getInitialMessage here too:
    // Firebase exposes it as a one-time launch value.
  }

  /// Removes the stored FCM token from the backend and deregisters the device
  /// from FCM so no further messages are delivered after sign-out.
  static Future<void> removeToken(String userId) async {
    _currentUserId = null;
    _navigationReady = false;
    _initializedUserId = null;
    _initializationFuture = null;
    await _tokenRefreshSubscription?.cancel();
    await _onMessageSubscription?.cancel();
    await _onMessageOpenedSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _onMessageSubscription = null;
    _onMessageOpenedSubscription = null;
    try {
      await UserService.removeFcmToken(userId);
      logger.i('[FCM] Token removed from backend');
    } catch (e) {
      logger.w('[FCM] Failed to remove FCM token from backend: $e');
    }
    try {
      await _messaging.deleteToken();
      logger.i('[FCM] FCM token deleted from Firebase - device unsubscribed');
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
        if (path != null && path.isNotEmpty) {
          _navigateToPath(path, navigatorKey);
        } else {
          _navigateToNotifications(navigatorKey);
        }
      },
    );

    // Firebase's getInitialMessage only covers notifications opened by FCM.
    // Data-only messages are displayed through flutter_local_notifications,
    // so recover that plugin's payload when its tap launched the app.
    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      logger.d('[FCM] App launched from local notification → $launchPayload');
      _navigateToPath(launchPayload, navigatorKey);
    }

    // Create (or update) the Android notification channel.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  static Future<void> _registerToken(String userId) async {
    try {
      String? apnsToken;

      // On iOS the APNs token must exist before Firebase can reliably return
      // the corresponding FCM token.
      if (Platform.isIOS) {
        for (var i = 0; i < 8; i++) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) break;
          await Future<void>.delayed(const Duration(seconds: 2));
          logger.d('[FCM] Waiting for APNs token... attempt ${i + 1}/8');
        }

        logger.i(
          apnsToken == null
              ? '[FCM] APNs token is null after retries; iOS push delivery will fail until APNs registration succeeds'
              : '[FCM] APNs token: ${_redactToken(apnsToken)}',
        );
      }

      // Keep the stable token Firebase has assigned to this installation.
      // Deleting it during normal startup can invalidate the token already
      // stored by the backend, especially when authentication initializes
      // more than once. The backend safely moves a token between users, and
      // sign-out explicitly deletes it when that is actually required.
      final token = await _messaging.getToken();
      if (token != null) {
        logger.i('[FCM] FCM token: ${_redactToken(token)}');
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
      logger.i(
          '[FCM] Token saved to backend for userId=$userId token=${_redactToken(token)}');
    } catch (e) {
      logger.w(
          '[FCM] Failed to save FCM token to backend for userId=$userId token=${_redactToken(token)} error=$e');
    }
  }

  static Future<void> showBackgroundDataNotification(
      RemoteMessage message) async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
    await _showLocalNotification(message);
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final type = (message.data['type']?.toString() ?? '').toUpperCase();
    final isWatchRequest = type == 'MOVIE_WATCH_REQUEST' ||
        type == 'SHOW_WATCH_REQUEST' ||
        type == 'GROUP_REQUEST' ||
        type == 'WATCH_REQUEST';
    final title = notification?.title ??
        message.data['title']?.toString() ??
        (isWatchRequest ? 'New watch request' : null);
    final body = notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        (isWatchRequest ? 'Someone invited you to watch something.' : null);
    if (title == null && body == null) {
      logger.d('[FCM] Data-only message has no displayable content');
      return;
    }

    await _localNotifications.show(
      message.messageId?.hashCode ?? message.hashCode,
      title ?? 'Flixie',
      body,
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
      payload: notificationDeepLinkPath(message.data),
    );
  }

  static void _ensureRemoteTapListener() {
    if (_onMessageOpenedSubscription != null) return;
    _onMessageOpenedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final path = notificationDeepLinkPath(message.data);
      logger.i('[FCM] Notification tapped → $path data=${message.data}');
      if (!_navigationReady || _router == null) {
        _pendingNavigationPath = path;
        logger
            .d('[FCM] Holding notification tap until app navigation is ready');
        return;
      }
      _navigateWithRouter(path);
    });
  }

  static String _redactToken(String? token) {
    if (token == null || token.isEmpty) return '<null>';
    if (token.length <= 12) return token;
    return '${token.substring(0, 6)}...${token.substring(token.length - 6)}';
  }

  static void _navigateToNotifications(GlobalKey<NavigatorState> navigatorKey) {
    _navigateToPath('/notifications', navigatorKey);
  }

  static void _navigateToPath(
    String path,
    GlobalKey<NavigatorState> navigatorKey, {
    int attempt = 0,
  }) {
    final now = DateTime.now();
    if (attempt == 0 &&
        _lastNavigatedPath == path &&
        _lastNavigatedAt != null &&
        now.difference(_lastNavigatedAt!) < _duplicateNavigationWindow) {
      logger.d('[FCM] Ignoring duplicate deep-link tap: $path');
      return;
    }

    if (!_navigationReady) {
      _pendingNavigationPath = path;
      logger.d('[FCM] Holding deep-link until authentication is ready: $path');
      return;
    }

    if (_router != null) {
      _navigateWithRouter(path);
      return;
    }

    _pendingNavigationPath = path;

    final context = navigatorKey.currentContext;
    if (context == null) {
      if (attempt >= _maxNavigationAttempts) {
        logger.w('[FCM] Failed to navigate to $path (context unavailable)');
        return;
      }
      _pendingNavigationTimer?.cancel();
      _pendingNavigationTimer = Timer(_navigationRetryDelay, () {
        _navigateToPath(path, navigatorKey, attempt: attempt + 1);
      });
      return;
    }

    _pendingNavigationTimer?.cancel();
    _pendingNavigationTimer = null;
    _lastNavigatedPath = path;
    _lastNavigatedAt = now;
    GoRouter.of(context).go(path);
  }

  static void _navigateWithRouter(String path) {
    try {
      _pendingNavigationTimer?.cancel();
      _pendingNavigationTimer = null;
      _lastNavigatedPath = path;
      _lastNavigatedAt = DateTime.now();
      logger.i('[FCM] Navigating with GoRouter → $path');
      _router!.go(path);
    } catch (error) {
      logger.w('[FCM] Router not ready for $path: $error');
      _pendingNavigationPath = path;
    }
  }

  static void _flushPendingNavigation() {
    final path = _pendingNavigationPath;
    if (!_navigationReady || _router == null || path == null) return;
    _pendingNavigationPath = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateWithRouter(path);
    });
  }
}
