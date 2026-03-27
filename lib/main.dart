import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'services/auth_service.dart';
import 'services/movie_cache_service.dart';
import 'theme/app_theme.dart';
import 'utils/app_logger.dart';
import 'screens/home_screen.dart';
import 'screens/movie_detail_screen.dart';
import 'screens/person_detail_screen.dart';
import 'screens/search_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/watchlist_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/my_reviews_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase only if not already initialized
    if (Firebase.apps.isEmpty) {
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

/// Builds the GoRouter, refreshing only when auth status changes (not user data).
GoRouter _buildRouter(AuthProvider authProvider) {
  return GoRouter(
    refreshListenable: authProvider.authStatusListenable,
    redirect: (context, state) {
      final status = authProvider.status;
      final isPrefetching = authProvider.isPrefetching;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isSplash = state.matchedLocation == '/splash';

      // Show splash while Firebase resolves auth state or prefetch is running
      if (status == AuthStatus.unknown ||
          (status == AuthStatus.authenticated && isPrefetching)) {
        return isSplash ? null : '/splash';
      }

      if (status == AuthStatus.unauthenticated && !isAuthRoute) {
        return '/auth/login';
      }
      if (status == AuthStatus.authenticated && (isAuthRoute || isSplash)) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Main shell (authenticated)
      ShellRoute(
        builder: (context, state, child) => MainNavigationShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/watchlist',
            builder: (context, state) => const WatchlistScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/movies/:id',
            builder: (context, state) => MovieDetailScreen(
              movieId: state.pathParameters['id'] ?? '0',
            ),
          ),
          GoRoute(
            path: '/people/:id',
            builder: (context, state) => PersonDetailScreen(
              personId: state.pathParameters['id'] ?? '0',
            ),
          ),
          GoRoute(
            path: '/my-reviews',
            builder: (context, state) => const MyReviewsScreen(),
          ),
        ],
      ),

      // Auth routes (unauthenticated)
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
    ],
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
    _router = _buildRouter(authProvider);
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

/// Bottom-navigation shell shown when the user is authenticated.
class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({super.key, required this.child});

  final Widget child;

  static int _indexFromLocation(String location) {
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/watchlist')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  static const List<String> _routes = [
    '/',
    '/search',
    '/watchlist',
    '/profile'
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _indexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: FlixieColors.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => context.go(_routes[index]),
          backgroundColor: Colors.transparent,
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Discover',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_border_outlined),
              selectedIcon: Icon(Icons.bookmark),
              label: 'Watchlist',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
