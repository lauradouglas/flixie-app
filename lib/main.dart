import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'services/auth_service.dart';
import 'services/movie_cache_service.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/app_logger.dart';
import 'screens/home_screen.dart';
import 'screens/movie_detail_screen.dart';
import 'screens/person_detail_screen.dart';
import 'screens/search_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/watchlist_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/friend_profile_screen.dart';
import 'screens/my_reviews_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/watch_history_screen.dart';
import 'screens/watch_requests_screen.dart';
import 'screens/social_screen.dart';
import 'screens/group_detail_screen.dart';
import 'screens/group_members_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

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

/// Global navigator key shared between [_buildRouter] and
/// [PushNotificationService] so the service can navigate without a BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Builds the GoRouter, refreshing only when auth status changes (not user data).
GoRouter _buildRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: authProvider.authStatusListenable,
    initialLocation: '/',
    redirect: (context, state) {
      final status = authProvider.status;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isSplash = state.matchedLocation == '/splash';

      // Show splash only while Firebase resolves initial auth state
      if (status == AuthStatus.unknown) {
        return isSplash ? null : '/splash';
      }

      if (status == AuthStatus.unauthenticated && !isAuthRoute) {
        return '/auth/login';
      }

      if (status == AuthStatus.authenticated) {
        final isOnboarding = state.matchedLocation == '/onboarding';
        final dbUser = authProvider.dbUser;
        // New user — must complete onboarding first
        if (dbUser != null && !dbUser.completedSetup) {
          return isOnboarding ? null : '/onboarding';
        }
        // Setup done — bounce away from auth/splash/onboarding
        if (isAuthRoute || isSplash || isOnboarding) {
          return '/';
        }
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
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/watchlist',
            builder: (context, state) => const WatchlistScreen(),
          ),
          GoRoute(
            path: '/social',
            builder: (context, state) => const SocialScreen(),
          ),
          GoRoute(
            path: '/groups/:id',
            builder: (context, state) => GroupDetailScreen(
              groupId: state.pathParameters['id'] ?? '',
              initialTab: state.uri.queryParameters['tab'] == 'requests'
                  ? 2
                  : state.uri.queryParameters['tab'] == 'chat'
                      ? 0
                      : null,
            ),
          ),
          GoRoute(
            path: '/groups/:id/members',
            builder: (context, state) => GroupMembersScreen(
              groupId: state.pathParameters['id'] ?? '',
              groupName: state.extra as String? ?? 'Group',
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/movies/:id',
            builder: (context, state) =>
                MovieDetailScreen(movieId: state.pathParameters['id'] ?? '0'),
          ),
          GoRoute(
            path: '/people/:id',
            builder: (context, state) =>
                PersonDetailScreen(personId: state.pathParameters['id'] ?? '0'),
          ),
          GoRoute(
            path: '/my-reviews',
            builder: (context, state) => const MyReviewsScreen(),
          ),
          GoRoute(
            path: '/friends/:id',
            builder: (context, state) =>
                FriendProfileScreen(userId: state.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationScreen(),
          ),
          GoRoute(
            path: '/watch-history',
            builder: (context, state) => const WatchHistoryScreen(),
          ),
          GoRoute(
            path: '/stats',
            builder: (context, state) => const StatsScreen(),
          ),
          GoRoute(
            path: '/watch-requests',
            builder: (context, state) => const WatchRequestsScreen(),
          ),
          GoRoute(
            path: '/help-support',
            builder: (context, state) => const HelpSupportScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          // Widget deep-link targets
          GoRoute(
            path: '/trending',
            // Redirect trending to home (home already shows trending content).
            redirect: (_, __) => '/',
          ),
          GoRoute(
            path: '/groups',
            // Redirect bare /groups to social screen (groups live there).
            redirect: (_, __) => '/social',
          ),
        ],
      ),

      // Onboarding (authenticated, completedSetup == false)
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
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

/// Bottom-navigation shell shown when the user is authenticated.
class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({super.key, required this.child});

  final Widget child;

  static int _indexFromLocation(String location) {
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/watchlist')) return 2;
    if (location.startsWith('/social') || location.startsWith('/groups')) {
      return 3;
    }
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  static const List<String> _routes = [
    '/',
    '/search',
    '/watchlist',
    '/social',
    '/profile',
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _indexFromLocation(location);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF172B4D), Color(0xFF1A2550)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Social',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
