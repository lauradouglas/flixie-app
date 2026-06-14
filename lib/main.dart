import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'router.dart';
import 'services/auth_service.dart';
import 'services/movie_cache_service.dart';
import 'services/movie_service.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/app_logger.dart';

bool _hasFirebaseDartDefines(FirebaseOptions options) {
  return options.apiKey.isNotEmpty &&
      options.appId.isNotEmpty &&
      options.messagingSenderId.isNotEmpty &&
      options.projectId.isNotEmpty;
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

  // Register FCM background message handler (must be called before runApp).
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Clear stale movie cache from previous days
  MovieCacheService().clearStaleCache();

  // Lock to portrait + landscape orientations, allow both
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Use a dark system overlay so the status bar blends with the dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: FlixieColors.tabBarBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<MovieService>(create: (_) => MovieService()),
        ChangeNotifierProvider(
          create: (context) => AuthProvider(
            AuthService(),
            context.read<MovieService>(),
          ),
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

class _FlixieAppState extends State<FlixieApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Create router once - it will refresh via authStatusListenable, not by rebuilding this widget
    final authProvider = context.read<AuthProvider>();
    _router = buildRouter(authProvider);
    // Give the navigator key to AuthProvider so push notifications can navigate.
    authProvider.setNavigatorKey(rootNavigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context
        .select<AuthProvider, bool>((auth) => auth.dbUser?.darkMode ?? true);
    return MaterialApp.router(
      title: 'Flixie',
      debugShowCheckedModeBanner: false,
      color: FlixieColors.background,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          final focus = FocusManager.instance.primaryFocus;
          if (focus != null && !focus.hasPrimaryFocus) {
            focus.unfocus();
          }
        },
        child: ColoredBox(
          color: isDark ? FlixieColors.background : const Color(0xFFF5F7FA),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
