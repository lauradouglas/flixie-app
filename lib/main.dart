import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/appearance_controller.dart';
import 'package:flixie_app/features/social/data/chat_unread_controller.dart';
import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/router/router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/auth_service.dart';
import 'package:flixie_app/core/auth/firebase_options.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/core/auth/referral_attribution_store.dart';
import 'package:flixie_app/core/analytics/analytics_backend.dart';
import 'package:flixie_app/core/analytics/analytics_consent_prompt.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/analytics/shared_preferences_analytics_consent_store.dart';
import 'package:flixie_app/core/storage/movie_cache_service.dart';
import 'package:flixie_app/core/utils/app_icon_badge_service.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';

bool _hasFirebaseDartDefines(FirebaseOptions options) {
  return options.apiKey.isNotEmpty &&
      options.appId.isNotEmpty &&
      options.messagingSenderId.isNotEmpty &&
      options.projectId.isNotEmpty;
}

Future<void> _activateFirebaseAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
      appleProvider: kReleaseMode
          ? AppleProvider.appAttestWithDeviceCheckFallback
          : AppleProvider.debug,
    );
    logger.i(
      'Firebase App Check activated with '
      '${kReleaseMode ? 'production' : 'debug'} providers',
    );
  } catch (error) {
    // App Check should protect Firebase resources without preventing the app
    // from starting if a provider is temporarily unavailable.
    logger.e('Firebase App Check activation error: $error');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase only if not already initialized
    if (Firebase.apps.isEmpty) {
      logger.i('Initializing Firebase');
      final options = DefaultFirebaseOptions.currentPlatform;
      if (_hasFirebaseDartDefines(options)) {
        await Firebase.initializeApp(
          options: options,
        );
      } else {
        logger.w(
          'Firebase dart-defines missing; using native Firebase config fallback (GoogleService-Info.plist/google-services.json)',
        );
        await Firebase.initializeApp();
      }
      logger.i('Firebase initialized successfully');
    } else {
      logger.d('Firebase already initialized, skipping');
    }
  } catch (e) {
    // Only log non-duplicate app errors
    if (!e.toString().contains('duplicate-app')) {
      logger.e('Firebase initialization error: $e');
    }
  }

  if (Firebase.apps.isNotEmpty) {
    await _activateFirebaseAppCheck();
  }

  // Register FCM background message handler (must be called before runApp).
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // Capture a notification that launched the terminated app before auth and
  // splash redirects can consume its intended destination.
  unawaited(PushNotificationService.captureInitialNotification());

  // Clear stale movie cache from previous days
  MovieCacheService().clearStaleCache();

  final analyticsController = AnalyticsController(
    backend: FirebaseAnalyticsBackend(),
    consentStore: SharedPreferencesAnalyticsConsentStore(),
  );
  await analyticsController.initialize();

  // Lock to portrait + landscape orientations, allow both
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Explicitly enable edge-to-edge on older Android versions as well.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // Safe-area widgets keep controls clear while backgrounds fill the window.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final appearance =
      AppearanceController(await SharedPreferences.getInstance());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppearanceController>.value(value: appearance),
        ChangeNotifierProvider<AnalyticsController>.value(
          value: analyticsController,
        ),
        Provider<MovieService>(create: (_) => MovieService()),
        ChangeNotifierProvider(
          create: (context) => AuthProvider(
            AuthService(),
            context.read<MovieService>(),
          ),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ChatUnreadController>(
          create: (_) => ChatUnreadController(),
          update: (_, auth, controller) =>
              (controller ?? ChatUnreadController())..syncUser(auth.dbUser?.id),
        ),
        ChangeNotifierProxyProvider<AuthProvider, WatchRequestCache>(
          create: (_) => WatchRequestCache(),
          update: (_, auth, cache) {
            final requestCache = cache ?? WatchRequestCache();
            requestCache.syncUser(auth.dbUser?.id);
            return requestCache;
          },
        ),
      ],
      child: const FlixieApp(),
    ),
  );
}

class FlixieApp extends StatefulWidget {
  const FlixieApp({super.key});

  @override
  State<FlixieApp> createState() => _FlixieAppState();
}

class _FlixieAppState extends State<FlixieApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  final ReferralAttributionStore _referralStore =
      SharedPreferencesReferralAttributionStore();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Create router once - it will refresh via authStatusListenable, not by rebuilding this widget
    final authProvider = context.read<AuthProvider>();
    _router = buildRouter(
      authProvider,
      context.read<AnalyticsController>(),
      _referralStore,
    );
    PushNotificationService.attachRouter(_router);
    // Give the navigator key to AuthProvider so push notifications can navigate.
    authProvider.setNavigatorKey(rootNavigatorKey);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final unread = context.read<AuthProvider>().unreadNotificationCount;
      AppIconBadgeService.setCount(unread);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppearanceController>().mode;
    return MaterialApp.router(
      title: 'Flixie',
      debugShowCheckedModeBanner: false,
      color: FlixieColors.background,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      routerConfig: _router,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: (Theme.of(context).brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: context.colors.tabBarBackground,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              final focus = FocusManager.instance.primaryFocus;
              focus?.unfocus();
            },
            child: AnalyticsConsentPrompt(
              child: ColoredBox(
                color: context.colors.background,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          )),
    );
  }
}
