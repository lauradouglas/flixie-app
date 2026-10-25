import 'package:flixie_app/core/widgets/flixie_refresh.dart';
import 'package:flixie_app/features/guest/presentation/guest_home_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_library_totals.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/user.dart' as models;
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/favourite_limits.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_header.dart';

import '../controllers/profile_controller.dart';
import '../profile_action_flow.dart';
import '../widgets/profile_library_tab.dart';
import '../widgets/profile_stats_tab.dart';
import '../widgets/profile_activity_tab.dart';
import '../widgets/profile_tabs.dart';
import '../widgets/profile_notification_button.dart';
import 'profile_diary_screen.dart';
import '../controllers/featured_people_controller.dart';
import '../controllers/profile_diary_controller.dart';
import '../widgets/profile_diary_preview.dart';
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
  late final ProfileDiaryController _diary;
  late final FeaturedPeopleController _people;
  ProfileActionFlow get _flow =>
      ProfileActionFlow(context: context, data: _data);
  @override
  void initState() {
    super.initState();
    _data = ProfileController(auth: context.read<AuthProvider>())
      ..addListener(_changed);
    _people = FeaturedPeopleController(auth: context.read<AuthProvider>())
      ..addListener(_changed);
    _diary = ProfileDiaryController(auth: context.read<AuthProvider>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _data.loadAll();
        _diary.load();
      }
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _data.removeListener(_changed);
    _data.dispose();
    _diary.dispose();
    _people.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dbUser =
        context.select<AuthProvider, models.User?>((auth) => auth.dbUser);
    if (dbUser == null) return const GuestWelcomeScreen(you: true);

    // The guest route above guarantees a database user here.
    final displayName = dbUser.firstName?.trim().isNotEmpty == true
        ? dbUser.firstName!.trim()
        : dbUser.username;
    final username = dbUser.username;
    final bio = dbUser.bio;
    final userId = dbUser.id;

    final favoriteMovies = (dbUser.favoriteMovies ?? [])
        .where((favorite) => favorite.removed != true)
        .toList(growable: false);
    final favoriteShows = (dbUser.favoriteShows ?? const <dynamic>[])
        .where(isActiveFavouriteShow)
        .toList(growable: false);
    final favoritePeople = dbUser.favoritePeople ?? [];

    return FlixiePageScaffold(
      adaptiveContent: true,
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
      body: FlixieRefresh(
        color: FlixieColors.primary,
        onRefresh: () async {
          await Future.wait([_data.refresh(), _diary.load(refresh: true)]);
        },
        child: CustomScrollView(
          key: const PageStorageKey('profile-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
                child: ProfileHeader(
              displayName: displayName,
              username: username,
              bio: bio,
              iconColor: dbUser.iconColor,
              avatar: dbUser.avatar,
              profileBadges: dbUser.profileBadges,
              memberSince: _memberSinceLabel(dbUser.createdAt),
              onPreview: () => context.push('/friends/$userId?preview=true'),
              onPeople: () => context.push('/profile/people'),
            )),
            SliverPersistentHeader(
                pinned: true,
                delegate: ProfileTabsDelegate(
                    height: 48 +
                        (MediaQuery.textScalerOf(context).scale(16) - 16) * 2,
                    child: ProfileTabSelector(
                        selected: _data.selectedTab,
                        onSelected: _data.selectTab))),
            SliverPadding(
                padding: _data.selectedTab == ProfileTab.diary
                    ? const EdgeInsets.fromLTRB(0, 8, 0, 12)
                    : const EdgeInsets.fromLTRB(20, 16, 20, 24),
                sliver: _data.selectedTab == ProfileTab.diary
                    ? SliverToBoxAdapter(
                        child: ProfileDiaryScreen(
                            controller: _diary, embedded: true))
                    : _data.selectedTab == ProfileTab.activity
                    ? _activityTab()
                    : SliverToBoxAdapter(
                        child: _data.selectedTab == ProfileTab.stats
                                ? ProfileStatsTab(
                                    wrapped: _data.wrapped,
                                    milestones: _data.milestones,
                                    milestonesLoading: _data.milestonesLoading,
                                    milestonesFailed: _data.milestonesFailed,
                                    onRetryMilestones: () => _data
                                        .loadMilestones(forceRefresh: true),
                                    failed: _data.statsFailed,
                                    onRetry: _data.loadStats,
                                    ratings: _data.ratings,
                                    reviewCount: _data.reviewCount,
                                    directorPeople: _data.directorPeople,
                                    user: dbUser)
                                : ProfileLibraryTab(
                                    userId: userId,
                                    featuredPeople: dbUser.featuredPeople,
                                    onChoosePerson: _people.choose,
                                    savingPeople: _people.saving,
                                    diaryPreview: ProfileDiaryPreview(
                                        controller: _diary,
                                        onOpen: () =>
                                            _data.selectTab(ProfileTab.diary)),
                                    libraryTotals:
                                        ProfileLibraryTotals(user: dbUser),
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
                                    onRemoveShow: _flow.removeContinueWatching,
                                    onManageProviders: _flow.openWatchProviders,
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
