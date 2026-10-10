import 'package:flixie_app/core/widgets/flixie_refresh.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_library_totals.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/user.dart' as models;
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/favourite_limits.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_header.dart';

import 'package:firebase_auth/firebase_auth.dart' as firebase;
import '../controllers/profile_controller.dart';
import '../profile_action_flow.dart';
import '../widgets/profile_library_tab.dart';
import '../widgets/profile_stats_tab.dart';
import '../widgets/profile_activity_tab.dart';
import '../widgets/profile_tabs.dart';
import '../widgets/profile_notification_button.dart';
import '../../models/profile_section.dart';
export '../widgets/profile_favourites_library.dart'
    show ProfileFavouritesLibrary;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _data;
  ProfileActionFlow get _flow =>
      ProfileActionFlow(context: context, data: _data);
  @override
  void initState() {
    super.initState();
    _data = ProfileController(auth: context.read<AuthProvider>())
      ..addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _data.loadAll();
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _data.removeListener(_changed);
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dbUser =
        context.select<AuthProvider, models.User?>((auth) => auth.dbUser);
    final firebaseUser = context
        .select<AuthProvider, firebase.User?>((auth) => auth.firebaseUser);

    // Prefer database user info, fallback to Firebase
    final displayName = dbUser?.firstName?.trim().isNotEmpty == true
        ? dbUser!.firstName!.trim()
        : dbUser?.username ?? firebaseUser?.displayName ?? 'Guest User';
    final username = dbUser?.username ?? firebaseUser?.displayName ?? '';
    final bio = dbUser?.bio;
    final userId = dbUser?.id;

    final favoriteMovies = (dbUser?.favoriteMovies ?? [])
        .where((favorite) => favorite.removed != true)
        .toList(growable: false);
    final favoriteShows = (dbUser?.favoriteShows ?? const <dynamic>[])
        .where(isActiveFavouriteShow)
        .toList(growable: false);
    final favoritePeople = dbUser?.favoritePeople ?? [];

    return FlixiePageScaffold(
      appBar: FlixieTitleAppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          const ProfileNotificationButton(),
        ],
      ),
      body: dbUser == null &&
              _data.activityLoading &&
              _data.ratingsLoading &&
              _data.profileExtrasLoading
          ? const ProfileScreenSkeleton()
          : FlixieRefresh(
              color: FlixieColors.primary,
              onRefresh: _data.refresh,
              child: CustomScrollView(
                key: const PageStorageKey('profile-scroll'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                      child: ProfileHeader(
                    displayName: displayName,
                    username: username,
                    bio: bio,
                    iconColor: dbUser?.iconColor,
                    avatar: dbUser?.avatar,
                    profileBadges: dbUser?.profileBadges ?? const [],
                    memberSince: _memberSinceLabel(dbUser?.createdAt),
                    onPreview: userId == null
                        ? null
                        : () => context.push('/friends/$userId?preview=true'),
                  )),
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0),
                          child: dbUser == null
                              ? const SizedBox.shrink()
                              : ProfileLibraryTotals(user: dbUser))),
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                  onPressed: () =>
                                      context.go('/social?tab=people'),
                                  icon: const Icon(Icons.people_outline,
                                      size: 19),
                                  label: const Text('Friends & following'))))),
                  SliverPersistentHeader(
                      pinned: true,
                      delegate: ProfileTabsDelegate(
                          height: 48 +
                              (MediaQuery.textScalerOf(context).scale(16) -
                                      16) *
                                  2,
                          child: ProfileTabSelector(
                              selected: _data.selectedTab,
                              onSelected: _data.selectTab))),
                  SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      sliver: _data.selectedTab == ProfileTab.activity
                          ? _activityTab()
                          : SliverToBoxAdapter(
                              child: _data.selectedTab == ProfileTab.stats
                                  ? ProfileStatsTab(
                                      wrapped: _data.wrapped,
                                      failed: _data.statsFailed,
                                      onRetry: _data.loadStats,
                                      ratings: _data.ratings,
                                      reviewCount: _data.reviewCount,
                                      directorPeople: _data.directorPeople,
                                      user: dbUser)
                                  : ProfileLibraryTab(
                                      userId: userId,
                                      favoriteMovies: favoriteMovies,
                                      favoritePeople: favoritePeople,
                                      favoriteShows: favoriteShows,
                                      activity: _data.recentActivity,
                                      continueWatching: _data.continueWatching,
                                      watchProviders: _data.watchProviders,
                                      loadingExtras: _data.profileExtrasLoading,
                                      failedExtras: _data.profileExtrasFailed,
                                      loadingActivity:
                                          _data.recentActivityLoading,
                                      onRemoveShow:
                                          _flow.removeContinueWatching,
                                      onManageProviders:
                                          _flow.openWatchProviders,
                                      onRatings: _flow.openRatings,
                                      onRetryExtras: _data.loadProfileExtras))),
                ],
              ),
            ),
    );
  }

  Widget _activityTab() => ProfileActivityTab(
      activity: _data.activity,
      filter: _data.activityFilter,
      loading: _data.activityLoading,
      failed: _data.activityFailed,
      paging: _data.activityRequestRunning,
      nextCursor: _data.activityCursor,
      onFilterSelected: _data.selectFilter,
      onRetry: _data.loadActivity,
      onLoadMore: () => _data.loadActivity(more: true));
  String? _memberSinceLabel(String? value) {
    final joined = DateTime.tryParse(value ?? '');
    if (joined == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return 'Member since ${months[joined.month - 1]} ${joined.year}';
  }
}
