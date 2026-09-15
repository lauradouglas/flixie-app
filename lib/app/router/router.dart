import 'package:provider/provider.dart';
import 'package:flixie_app/features/social/data/chat_unread_controller.dart';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/referral_attribution_store.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/core/analytics/recommendation_attribution.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/home/presentation/pages/home_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/person_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/show_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/search_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/splash_screen.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import 'package:flixie_app/features/watch_plans/presentation/pages/group_watch_plan_v2_screen.dart';
import 'package:flixie_app/features/profile/presentation/pages/profile_screen.dart';
import 'package:flixie_app/features/profile/presentation/pages/friend_profile_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/my_reviews_screen.dart';
import 'package:flixie_app/features/profile/presentation/pages/notification_screen.dart';
import 'package:flixie_app/features/settings/presentation/pages/help_support_screen.dart';
import 'package:flixie_app/features/settings/presentation/pages/settings_screen.dart';
import 'package:flixie_app/features/settings/presentation/pages/about_credits_screen.dart';
import 'package:flixie_app/features/settings/presentation/pages/invite_friend_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/stats_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/user_wrapped_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/watch_history_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_list_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_lists_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/social_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/friends_activity_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/group_detail_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/group_invitation_detail_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/direct_chat_screen.dart';
import 'package:flixie_app/features/social/presentation/utils/activity_reply_payload.dart';
import 'package:flixie_app/features/social/presentation/pages/group_members_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/login_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/forgot_password_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/onboarding_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/getting_started_guide_screen.dart';

/// Global navigator key shared between [buildRouter] and
/// [PushNotificationService] so the service can navigate without a BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

Page<void> _calmPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    name: _screenNameFor(state),
    child: child,
  );
}

/// A native-feeling page for routes pushed above the main tabs.
/// CupertinoPageRoute supplies iOS's interactive left-edge back gesture.
Page<void> _pushPage(GoRouterState state, Widget child) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return CupertinoPage<void>(
      key: state.pageKey,
      name: _screenNameFor(state),
      child: child,
    );
  }
  return MaterialPage<void>(
    key: state.pageKey,
    name: _screenNameFor(state),
    child: child,
  );
}

String _screenNameFor(GoRouterState state) {
  final path = state.fullPath ?? state.matchedLocation;
  return switch (path) {
    '/' => 'Home',
    '/search' => 'Search',
    '/watchlist' => 'Watchlist',
    '/social' => 'Social',
    '/friends-activity' => 'Friends Activity',
    '/groups/:id' => 'Group Detail',
    '/group-invites/:requestId' => 'Group Invitation',
    '/groups/:id/members' => 'Group Members',
    '/profile' => 'Profile',
    '/friends/:id' => 'Friend Profile',
    '/movies/:id' => 'Movie Detail',
    '/shows/:id' => 'Show Detail',
    '/people/:id' => 'Person Detail',
    '/chat/:id' => 'Friend Chat',
    '/notifications' => 'Notifications',
    '/watch-history' => 'Watch History',
    '/movie-lists' => 'Lists',
    '/movie-lists/:id' => 'List Detail',
    '/my-reviews' => 'My Reviews',
    '/stats' => 'Stats',
    '/wrapped' || '/wrapped/:userId' => 'Wrapped',
    '/watch-requests' => 'Watch Plans',
    '/watch-requests/:requestId' => 'Watch Plan',
    '/settings' => 'Settings',
    '/help-support' => 'Help and Support',
    '/about-credits' => 'About Flixie',
    '/invite-friend' => 'Invite Friend',
    '/onboarding' => 'Onboarding',
    '/getting-started' => 'Getting Started',
    '/auth/login' => 'Login',
    '/auth/signup' => 'Sign Up',
    '/auth/forgot-password' => 'Forgot Password',
    '/splash' => 'Splash',
    _ => 'Flixie',
  };
}

class _FlixieAnalyticsObserver extends NavigatorObserver {
  _FlixieAnalyticsObserver(this.analytics);

  final AnalyticsController analytics;

  void _record(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && name.isNotEmpty) analytics.screenViewed(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _record(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _record(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _record(previousRoute);
  }
}

/// Builds the GoRouter, refreshing only when auth status changes (not user data).
GoRouter buildRouter(
  AuthProvider authProvider,
  AnalyticsController analytics,
  ReferralAttributionStore referralStore,
) {
  final recordedInviteCodes = <String>{};
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [_FlixieAnalyticsObserver(analytics)],
    refreshListenable: authProvider.authStatusListenable,
    initialLocation: '/',
    redirect: (context, state) async {
      final status = authProvider.status;
      final hasCompletedSetup = authProvider.dbUser?.completedSetup ?? false;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isSplash = state.matchedLocation == '/splash';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isReferralInvite = state.matchedLocation == '/invite';
      final referralCode = isReferralInvite
          ? state.uri.queryParameters['code']?.trim().toUpperCase()
          : null;

      if (referralCode != null && referralCode.isNotEmpty) {
        try {
          await referralStore.save(referralCode);
        } catch (_) {
          // Persistence improves recovery but must never break a valid link.
        }
        if (recordedInviteCodes.add(referralCode)) {
          unawaited(analytics.referralLinkOpened());
        }
      }

      // Show splash only while Firebase resolves initial auth state
      if (status == AuthStatus.unknown) {
        return isSplash ? null : '/splash';
      }

      if (status == AuthStatus.unauthenticated && isReferralInvite) {
        return Uri(
          path: '/auth/signup',
          queryParameters: referralCode == null ? null : {'code': referralCode},
        ).toString();
      }

      if (status == AuthStatus.unauthenticated && !isAuthRoute) {
        try {
          final pendingReferral = await referralStore.read();
          if (pendingReferral != null) {
            return Uri(
              path: '/auth/signup',
              queryParameters: {'code': pendingReferral},
            ).toString();
          }
        } catch (_) {
          // Fall back to the normal login route if local storage is unavailable.
        }
        return '/auth/login';
      }

      if (status == AuthStatus.authenticated) {
        // Referral codes apply only to new account creation. Never carry one
        // into an existing authenticated account or a later sign-up.
        unawaited(referralStore.clear().catchError((_) {}));
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
      GoRoute(
        path: '/getting-started',
        pageBuilder: (context, state) => _pushPage(
          state,
          GettingStartedGuideScreen(
            openedFromSettings: state.uri.queryParameters['from'] == 'settings',
          ),
        ),
      ),

      // Main shell (authenticated)
      ShellRoute(
        observers: [_FlixieAnalyticsObserver(analytics)],
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
            path: '/group-watch-plans-v2',
            pageBuilder: (context, state) => _calmPage(
              state,
              GroupWatchPlanV2Screen(
                groupId: state.uri.queryParameters['groupId'],
                groupName: state.uri.queryParameters['groupName'],
                initialRequestId: state.uri.queryParameters['requestId'],
              ),
            ),
          ),
          GoRoute(
            path: '/social',
            pageBuilder: (context, state) => _calmPage(
                state,
                SocialScreen(
                    initialTab:
                        state.uri.queryParameters['tab'] == 'groups' ? 2 : 0)),
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
              MovieDetailScreen(
                movieId: state.pathParameters['id'] ?? '0',
                source: DetailSource.fromValue(
                  state.uri.queryParameters['source'],
                ),
                fromMovieMatch:
                    state.uri.queryParameters['source'] == 'movie_match' ||
                        state.uri.queryParameters['movieMatch'] == '1',
                recommendation: state.uri.queryParameters['recSource'] == null
                    ? null
                    : RecommendationAttribution.fromRoute(
                        contentId:
                            int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                        contentType: 'movie',
                        query: state.uri.queryParameters,
                      ),
              ),
            ),
          ),
          GoRoute(
            path: '/shows/:id',
            pageBuilder: (context, state) => _pushPage(
              state,
              ShowDetailScreen(
                showId: state.pathParameters['id'] ?? '0',
                source: DetailSource.fromValue(
                  state.uri.queryParameters['source'],
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/people/:id',
            pageBuilder: (context, state) => _pushPage(
              state,
              PersonDetailScreen(
                personId: state.pathParameters['id'] ?? '0',
                source: DetailSource.fromValue(
                  state.uri.queryParameters['source'],
                ),
                parentContentId: int.tryParse(
                  state.uri.queryParameters['parentContentId'] ?? '',
                ),
                parentContentType:
                    state.uri.queryParameters['parentContentType'],
              ),
            ),
          ),
          GoRoute(
            path: '/my-reviews',
            pageBuilder: (context, state) =>
                _calmPage(state, const MyReviewsScreen()),
          ),
          GoRoute(
            path: '/group-invites/:requestId',
            pageBuilder: (context, state) => _pushPage(
              state,
              GroupInvitationDetailScreen(
                groupId: state.uri.queryParameters['groupId'] ?? '',
                requestId: state.pathParameters['requestId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: '/friends/:id',
            pageBuilder: (context, state) => _calmPage(
              state,
              FriendProfileScreen(
                userId: state.pathParameters['id'] ?? '',
                previewMode: state.uri.queryParameters['preview'] == 'true',
              ),
            ),
          ),
          GoRoute(
            path: '/chat/:id',
            pageBuilder: (context, state) => _pushPage(
              state,
              DirectChatScreen(
                otherUserId: state.pathParameters['id'] ?? '',
                initialActivityReply: state.extra is ActivityReplyPayload
                    ? state.extra as ActivityReplyPayload
                    : null,
              ),
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
                isOwnerOverride: state.uri.queryParameters['isOwner'] == null
                    ? null
                    : state.uri.queryParameters['isOwner'] == 'true',
                canEditOverride: state.uri.queryParameters['canEdit'] == null
                    ? null
                    : state.uri.queryParameters['canEdit'] == 'true',
              ),
            ),
          ),
          GoRoute(
            path: '/about-credits',
            pageBuilder: (context, state) =>
                _calmPage(state, const AboutCreditsScreen()),
          ),
          GoRoute(
            path: '/stats',
            pageBuilder: (context, state) =>
                _calmPage(state, const StatsScreen()),
          ),
          GoRoute(
            path: '/wrapped',
            pageBuilder: (context, state) =>
                _pushPage(state, const UserWrappedScreen()),
          ),
          GoRoute(
            path: '/wrapped/:userId',
            pageBuilder: (context, state) => _pushPage(
              state,
              UserWrappedScreen(
                userId: state.pathParameters['userId'],
                initialYear: int.tryParse(
                  state.uri.queryParameters['year'] ?? '',
                ),
              ),
            ),
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
          GoRoute(
            path: '/invite-friend',
            pageBuilder: (context, state) =>
                _calmPage(state, const InviteFriendScreen()),
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

      GoRoute(
        path: '/invite',
        redirect: (_, state) {
          final code = state.uri.queryParameters['code'];
          return Uri(
            path: '/auth/signup',
            queryParameters: code == null ? null : {'code': code},
          ).toString();
        },
      ),

      // Auth routes (unauthenticated)
      GoRoute(
        path: '/auth/login',
        pageBuilder: (context, state) => _calmPage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/auth/signup',
        pageBuilder: (context, state) => _calmPage(
          state,
          SignupScreen(
            referralCode: state.uri.queryParameters['code'] ??
                state.uri.queryParameters['referralCode'],
            referralStore: referralStore,
          ),
        ),
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
    if (location.startsWith('/invite-friend')) {
      final uri = Uri.tryParse(location);
      return uri?.queryParameters['from'] == 'settings' ? 4 : 3;
    }
    if (location.startsWith('/watchlist')) return 1;
    if (location.startsWith('/search')) return 2;
    if (location.startsWith('/social') || location.startsWith('/groups')) {
      return 3;
    }
    if (location.startsWith('/profile')) return 4;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  static const List<String> _routes = [
    '/',
    '/watchlist',
    '/search',
    '/social',
    '/profile',
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
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
          onDestinationSelected: (index) {
            final isAtDestinationRoot =
                GoRouterState.of(context).uri.path == _routes[index];
            if (index == selectedIndex && isAtDestinationRoot) {
              if (index == 0) TabRefreshController.requestHomeRefresh();
              if (index == 1) TabRefreshController.watchlist.value++;
              if (index == 3) TabRefreshController.requestSocialRefresh();
              return;
            }
            context.go(_routes[index]);
          },
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
      label: 'Watchlist',
    ),
    _NavDest(
      icon: Icons.search_outlined,
      activeIcon: Icons.search_rounded,
      label: 'Search',
    ),
    _NavDest(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Social',
    ),
    _NavDest(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
    ),
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
  const _NavDest({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 5,
                ),
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
                child: Badge(
                  isLabelVisible: dest.label == 'Social' &&
                      (context.watch<ChatUnreadController?>()?.total ?? 0) > 0,
                  backgroundColor: const Color(0xFFFFAD66),
                  smallSize: 8,
                  child: Icon(
                    isSelected ? dest.activeIcon : dest.icon,
                    semanticLabel: dest.label == 'Social' &&
                            (context.watch<ChatUnreadController?>()?.total ??
                                    0) >
                                0
                        ? 'Social, unread messages'
                        : null,
                    size: 22,
                    color: isSelected ? Colors.white : FlixieColors.medium,
                  ),
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
