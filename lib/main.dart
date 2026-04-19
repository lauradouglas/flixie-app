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
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase only if not already initialized
    if (Firebase.apps.isEmpty) {
      print('Initializing Firebase');
      //print('Env Settings: ${String.fromEnvironment('FIREBASE_WEB_API_KEY')}');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
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
    ChangeNotifierProvider(
      create: (_) => AuthProvider(AuthService()),
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
    return MaterialApp.router(
      title: 'Flixie',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
