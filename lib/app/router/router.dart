import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/home/presentation/pages/home_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/person_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/show_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/search_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/splash_screen.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import 'package:flixie_app/features/profile/presentation/pages/profile_screen.dart';
import 'package:flixie_app/features/profile/presentation/pages/friend_profile_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/my_reviews_screen.dart';
import 'package:flixie_app/features/profile/presentation/pages/notification_screen.dart';
import 'package:flixie_app/features/settings/presentation/pages/help_support_screen.dart';
import 'package:flixie_app/features/settings/presentation/pages/settings_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/stats_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/watch_history_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_list_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_lists_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/social_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/friends_activity_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/group_detail_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/group_members_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/login_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/forgot_password_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/onboarding_screen.dart';

/// Global navigator key shared between [buildRouter] and
/// [PushNotificationService] so the service can navigate without a BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

Page<void> _calmPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    child: child,
  );
}

/// A native-feeling page for routes pushed above the main tabs.
/// CupertinoPageRoute supplies iOS's interactive left-edge back gesture.
Page<void> _pushPage(GoRouterState state, Widget child) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return CupertinoPage<void>(key: state.pageKey, child: child);
  }
  return MaterialPage<void>(key: state.pageKey, child: child);
}

/// Builds the GoRouter, refreshing only when auth status changes (not user data).
GoRouter buildRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: authProvider.authStatusListenable,
    initialLocation: '/',
    redirect: (context, state) {
      final status = authProvider.status;
      final hasCompletedSetup = authProvider.dbUser?.completedSetup ?? false;
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
        // New users must complete onboarding before entering the app shell.
        if (!hasCompletedSetup) {
          if (isOnboarding) return null;
          return '/onboarding';
        }

        // Completed users should land in the app shell, not auth/splash/onboarding.
        if (isAuthRoute || isSplash || isOnboarding) {
          return '/';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => _calmPage(state, const SplashScreen()),
      ),

      // Main shell (authenticated)
      ShellRoute(
        builder: (context, state, child) => MainNavigationShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                _calmPage(state, const HomeScreen()),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) =>
                _calmPage(state, const SearchScreen()),
          ),
          GoRoute(
            path: '/watchlist',
            pageBuilder: (context, state) =>
                _calmPage(state, const WatchlistScreen()),
          ),
          GoRoute(
            path: '/social',
            pageBuilder: (context, state) =>
                _calmPage(state, const SocialScreen()),
          ),
          GoRoute(
            path: '/friends-activity',
            pageBuilder: (context, state) =>
                _calmPage(state, const FriendsActivityScreen()),
          ),
          GoRoute(
            path: '/groups/:id',
            pageBuilder: (context, state) => _calmPage(
              state,
              GroupDetailScreen(
                groupId: state.pathParameters['id'] ?? '',
                initialRequestId: state.uri.queryParameters['requestId'],
                initialTab: state.uri.queryParameters['tab'] == 'requests'
                    ? 2
                    : state.uri.queryParameters['tab'] == 'insights'
                        ? 3
                        : state.uri.queryParameters['tab'] == 'chat'
                            ? 0
                            : null,
              ),
            ),
          ),
          GoRoute(
            path: '/groups/:id/members',
            pageBuilder: (context, state) => _calmPage(
              state,
              GroupMembersScreen(
                groupId: state.pathParameters['id'] ?? '',
                groupName: state.extra as String? ?? 'Group',
              ),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                _calmPage(state, const ProfileScreen()),
          ),
          GoRoute(
            path: '/movies/:id',
            pageBuilder: (context, state) => _pushPage(
              state,
              MovieDetailScreen(movieId: state.pathParameters['id'] ?? '0'),
            ),
          ),
          GoRoute(
            path: '/shows/:id',
            pageBuilder: (context, state) => _pushPage(
              state,
              ShowDetailScreen(showId: state.pathParameters['id'] ?? '0'),
            ),
          ),
          GoRoute(
            path: '/people/:id',
            pageBuilder: (context, state) => _pushPage(
              state,
              PersonDetailScreen(personId: state.pathParameters['id'] ?? '0'),
            ),
          ),
          GoRoute(
            path: '/my-reviews',
            pageBuilder: (context, state) =>
                _calmPage(state, const MyReviewsScreen()),
          ),
          GoRoute(
            path: '/friends/:id',
            pageBuilder: (context, state) => _calmPage(
              state,
              FriendProfileScreen(userId: state.pathParameters['id'] ?? ''),
            ),
          ),
          GoRoute(
            path: '/notifications',
            pageBuilder: (context, state) =>
                _calmPage(state, const NotificationScreen()),
          ),
          GoRoute(
            path: '/watch-history',
            pageBuilder: (context, state) =>
                _calmPage(state, const WatchHistoryScreen()),
          ),
          GoRoute(
            path: '/movie-lists',
            pageBuilder: (context, state) =>
                _calmPage(state, const MovieListsScreen()),
          ),
          GoRoute(
            path: '/movie-lists/:id',
            pageBuilder: (context, state) => _calmPage(
              state,
              MovieListDetailScreen(
                listId: state.pathParameters['id'] ?? '',
                listName: state.uri.queryParameters['name'] ?? 'List',
                ownerUserId: state.uri.queryParameters['owner'],
              ),
            ),
          ),
          GoRoute(
            path: '/stats',
            pageBuilder: (context, state) =>
                _calmPage(state, const StatsScreen()),
          ),
          GoRoute(
            path: '/wrapped',
            redirect: (context, state) => '/stats',
          ),
          GoRoute(
            path: '/watch-requests',
            pageBuilder: (context, state) => _calmPage(
              state,
              WatchRequestsScreen(
                initialRequestId: state.uri.queryParameters['requestId'],
              ),
            ),
          ),
          GoRoute(
            path: '/watch-requests/:requestId',
            pageBuilder: (context, state) => _calmPage(
              state,
              WatchRequestDetailScreen(
                requestId: state.pathParameters['requestId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: '/help-support',
            pageBuilder: (context, state) =>
                _calmPage(state, const HelpSupportScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                _calmPage(state, const SettingsScreen()),
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
        pageBuilder: (context, state) =>
            _calmPage(state, const OnboardingScreen()),
      ),

      // Auth routes (unauthenticated)
      GoRoute(
        path: '/auth/login',
        pageBuilder: (context, state) => _calmPage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/auth/signup',
        pageBuilder: (context, state) => _calmPage(state, const SignupScreen()),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        pageBuilder: (context, state) =>
            _calmPage(state, const ForgotPasswordScreen()),
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
        icon: Icons.people_outline, activeIcon: Icons.people, label: 'Social'),
    _NavDest(
        icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
    _NavDest(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackground.withValues(alpha: 0.98),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, -2),
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
                            color: FlixieColors.primary.withValues(alpha: 0.32),
                            blurRadius: 8,
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
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
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
