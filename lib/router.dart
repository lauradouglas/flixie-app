import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'theme/app_theme.dart';
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
import 'screens/movie_list_detail_screen.dart';
import 'screens/movie_lists_screen.dart';
import 'screens/social_screen.dart';
import 'screens/group_detail_screen.dart';
import 'screens/group_members_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

/// Global navigator key shared between [buildRouter] and
/// [PushNotificationService] so the service can navigate without a BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Builds the GoRouter, refreshing only when auth status changes (not user data).
GoRouter buildRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: authProvider.authStatusListenable,
    initialLocation: '/',
    redirect: (context, state) {
      final status = authProvider.status;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isSplash = state.matchedLocation == '/splash';
      final isOnboarding = state.matchedLocation == '/onboarding';

      // Show splash only while Firebase resolves initial auth state
      if (status == AuthStatus.unknown) {
        return isSplash ? null : '/splash';
      }

      if (status == AuthStatus.unauthenticated && !isAuthRoute) {
        return '/auth/login';
      }

      if (status == AuthStatus.authenticated) {
        // Authenticated users should always land in the app, not auth or
        // sign-up flow screens restored from a previous session.
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
            path: '/movie-lists',
            builder: (context, state) => const MovieListsScreen(),
          ),
          GoRoute(
            path: '/movie-lists/:id',
            builder: (context, state) => MovieListDetailScreen(
              listId: state.pathParameters['id'] ?? '',
              listName: state.uri.queryParameters['name'] ?? 'List',
              ownerUserId: state.uri.queryParameters['owner'],
            ),
          ),
          GoRoute(
            path: '/stats',
            builder: (context, state) => const StatsScreen(),
          ),
          GoRoute(
            path: '/wrapped',
            redirect: (context, state) => '/stats',
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

      // Onboarding route is kept for explicit navigation only.
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

/// Bottom-navigation shell shown when the user is authenticated.
class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({super.key, required this.child});

  final Widget child;

  static int _indexFromLocation(String location) {
    if (location.startsWith('/watchlist')) return 1;
    if (location.startsWith('/social') || location.startsWith('/groups')) {
      return 2;
    }
    if (location.startsWith('/profile')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  static const List<String> _routes = [
    '/',
    '/watchlist',
    '/social',
    '/profile',
    '/settings',
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
          colors: [
            FlixieColors.surface,
            FlixieColors.background,
            FlixieColors.navy,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: child,
        bottomNavigationBar: _FlixieNavBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => context.go(_routes[index]),
        ),
      ),
    );
  }
}

/// Premium animated bottom navigation bar.
class _FlixieNavBar extends StatelessWidget {
  const _FlixieNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinations = [
    _NavDest(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    _NavDest(
        icon: Icons.bookmark_border_outlined,
        activeIcon: Icons.bookmark,
        label: 'Watchlist'),
    _NavDest(
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        label: 'Social'),
    _NavDest(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profile'),
    _NavDest(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: FlixieColors.tabBarBackground.withValues(alpha: 0.92),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_destinations.length, (i) {
                  final dest = _destinations[i];
                  final isSelected = i == selectedIndex;
                  return _NavItem(
                    dest: dest,
                    isSelected: isSelected,
                    onTap: () => onDestinationSelected(i),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDest {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavDest(
      {required this.icon, required this.activeIcon, required this.label});
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.dest,
    required this.isSelected,
    required this.onTap,
  });

  final _NavDest dest;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                decoration: isSelected
                    ? BoxDecoration(
                        color: FlixieColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: FlixieColors.primary.withValues(alpha: 0.45),
                            blurRadius: 14,
                            spreadRadius: 0,
                          ),
                        ],
                      )
                    : null,
                child: Icon(
                  isSelected ? dest.activeIcon : dest.icon,
                  size: 22,
                  color: isSelected ? Colors.white : FlixieColors.medium,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color:
                      isSelected ? FlixieColors.primary : FlixieColors.medium,
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.normal,
                ),
                child: Text(dest.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
