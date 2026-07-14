import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';
import 'package:flixie_app/features/profile/presentation/controllers/profile_lookup_controller.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favorite_movies_section.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favorite_people_section.dart';
import 'package:flixie_app/features/profile/presentation/widgets/friends_row.dart';
import 'package:flixie_app/features/profile/presentation/widgets/movie_taste_badge.dart';
import 'package:flixie_app/features/profile/presentation/widgets/lists_preview_section.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:flixie_app/features/profile/presentation/widgets/ratings_section.dart';

enum _ProfileTab { library, activity, social, stats }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<ActivityListItem> _activity = [];
  bool _activityLoading = true;
  String? _loadedForUserId;
  int _lastActivityVersion = -1;

  FriendsData? _friendsData;
  bool _friendsLoading = true;

  List<MovieRating> _ratings = [];
  bool _ratingsLoading = true;

  static const int _initialActivityCount = 5;
  bool _showAllActivity = false;
  _ProfileTab _selectedTab = _ProfileTab.library;
  AuthProvider? _authProvider;
  final FriendActionsController _friendActions =
      FriendActionsController.instance;
  final ProfileLookupController _profileLookup =
      ProfileLookupController.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authProvider ??= context.read<AuthProvider>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authProvider?.addListener(_onAuthChanged);
      _loadAll();
    });
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = _authProvider;
    final userId = auth?.dbUser?.id;
    final version = auth?.activityVersion ?? -1;
    if (userId != null &&
        (userId != _loadedForUserId || version != _lastActivityVersion)) {
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    logger.d('[ProfileScreen] _loadAll called');
    try {
      await Future.wait([_loadActivity(), _loadFriends(), _loadRatings()]);
      logger.d('[ProfileScreen] All data loaded successfully');
    } catch (e, stackTrace) {
      logger.e('[ProfileScreen] Error in _loadAll: $e');
      logger.e('[ProfileScreen] Stack trace: $stackTrace');
    }
  }

  Future<void> _loadActivity() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;

    // Use prefetched cache if ready — no spinner needed
    if (auth.cachedActivity != null) {
      if (mounted) {
        setState(() {
          _activity = auth.cachedActivity!.take(12).toList();
          _loadedForUserId = userId;
          _lastActivityVersion = auth.activityVersion;
          _activityLoading = false;
        });
      }
      return;
    }

    try {
      final activity = await _profileLookup.getUserActivity(userId);
      if (mounted) {
        setState(() {
          _activity = activity.take(12).toList();
          _loadedForUserId = userId;
          _lastActivityVersion = context.read<AuthProvider>().activityVersion;
          _activityLoading = false;
        });
      }
    } catch (e) {
      logger.e('[ProfileScreen] activity load error: $e');
      if (mounted) setState(() => _activityLoading = false);
    }
  }

  Future<void> _loadFriends() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;

    // Use prefetched cache if ready
    if (auth.cachedFriends != null) {
      if (mounted) {
        setState(() {
          _friendsData = auth.cachedFriends;
          _friendsLoading = false;
        });
      }
      return;
    }

    try {
      final data = await _friendActions.getFriends(userId);
      if (mounted) {
        setState(() {
          _friendsData = data;
          _friendsLoading = false;
        });
      }
    } catch (e) {
      logger.e('[ProfileScreen] friends load error: $e');
      if (mounted) {
        setState(() {
          _friendsData = const FriendsData(
            friendships: [],
            pendingFriends: [],
            requestedFriends: [],
          );
          _friendsLoading = false;
        });
      }
    }
  }

  Future<void> _loadRatings() async {
    logger.d('[ProfileScreen] _loadRatings called');
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    logger.d('[ProfileScreen] userId for ratings: $userId');
    if (userId == null) {
      logger.w('[ProfileScreen] Cannot load ratings - userId is null');
      return;
    }

    // Use prefetched cache if ready
    if (auth.cachedRatings != null) {
      logger.i(
          '[ProfileScreen] Using cached ratings (${auth.cachedRatings!.length})');
      if (mounted) {
        setState(() {
          _ratings = auth.cachedRatings!;
          _ratingsLoading = false;
        });
      }
      return;
    }

    try {
      logger.d(
          '[ProfileScreen] Calling ProfileLookupController.getUserMovieRatings...');
      final ratings = await _profileLookup.getUserMovieRatings(userId);
      logger.i('[ProfileScreen] Loaded ${ratings.length} ratings');
      if (mounted) {
        setState(() {
          _ratings = ratings;
          _ratingsLoading = false;
        });
      }
    } catch (e, stackTrace) {
      logger.e('[ProfileScreen] ratings load error: $e');
      logger.e('[ProfileScreen] Stack trace: $stackTrace');
      if (mounted) setState(() => _ratingsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthProvider>();
    final firebaseUser = auth.firebaseUser;
    final dbUser = auth.dbUser;

    // Prefer database user info, fallback to Firebase
    final displayName = dbUser?.firstName?.trim().isNotEmpty == true
        ? dbUser!.firstName!.trim()
        : dbUser?.username ?? firebaseUser?.displayName ?? 'Guest User';
    final username = dbUser?.username ?? firebaseUser?.displayName ?? '';
    final email = dbUser?.email ?? firebaseUser?.email ?? '';
    final bio = dbUser?.bio;
    final photoUrl = firebaseUser?.photoURL;
    final userId = dbUser?.id;

    final favoriteMovies = dbUser?.favoriteMovies ?? [];
    final favoritePeople = dbUser?.favoritePeople ?? [];
    final watchedCount = (dbUser?.watchedMovies?.length ?? 0) +
        (dbUser?.watchedShows?.length ?? 0);
    final watchlistCount = (dbUser?.movieWatchlist?.length ?? 0) +
        (dbUser?.showWatchlist?.length ?? 0);
    final favoritesCount = favoriteMovies.length +
        (dbUser?.favoriteShows?.length ?? 0) +
        favoritePeople.length;
    final averageRating = _averageRatingLabel(_ratings);

    final visibleActivity = _showAllActivity
        ? _activity
        : _activity.take(_initialActivityCount).toList();

    return FlixiePageScaffold(
      appBar: FlixieTitleAppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: auth.unreadNotificationCount > 0,
              label: auth.unreadNotificationCount < 100
                  ? Text('${auth.unreadNotificationCount}')
                  : const Text('99+'),
              backgroundColor: FlixieColors.tertiary,
              textColor: Colors.black,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              await context.push('/notifications');
              if (mounted) {
                authProvider.refreshNotificationCount();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: FlixieColors.primary,
        onRefresh: () async {
          await context.read<AuthProvider>().refreshUserData();
          await _loadAll();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Avatar, name, bio & edit (full-width, no side padding)
              ProfileHeader(
                displayName: displayName,
                username: username,
                email: email,
                photoUrl: photoUrl,
                bio: bio,
                iconColor: dbUser?.iconColor,
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileDashboard(
                      watched: watchedCount,
                      watchlist: watchlistCount,
                      favorites: favoritesCount,
                      averageRating: averageRating,
                      recentActivity: _activity.length,
                      onWatchHistory: () => context.push('/watch-history'),
                      onWatchlist: () => context.push('/watchlist'),
                      onFavourites: () =>
                          setState(() => _selectedTab = _ProfileTab.library),
                      onRecap: () => context.push('/stats'),
                    ),
                    const SizedBox(height: 18),
                    _ProfileTabSelector(
                      selected: _selectedTab,
                      onSelected: (tab) => setState(() => _selectedTab = tab),
                    ),
                    const SizedBox(height: 16),
                    _buildSelectedTabContent(
                      context: context,
                      textTheme: textTheme,
                      auth: auth,
                      userId: userId,
                      favoriteMovies: favoriteMovies,
                      favoritePeople: favoritePeople,
                      favoriteGenres: dbUser?.favoriteGenres ?? const [],
                      visibleActivity: visibleActivity,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent({
    required BuildContext context,
    required TextTheme textTheme,
    required AuthProvider auth,
    required String? userId,
    required List<dynamic> favoriteMovies,
    required List<dynamic> favoritePeople,
    required List<dynamic> favoriteGenres,
    required List<ActivityListItem> visibleActivity,
  }) {
    switch (_selectedTab) {
      case _ProfileTab.library:
        return _buildLibraryTab(
          context: context,
          userId: userId,
          favoriteMovies: favoriteMovies,
          favoritePeople: favoritePeople,
        );
      case _ProfileTab.activity:
        return _buildActivityTab(context, textTheme, visibleActivity);
      case _ProfileTab.social:
        return _buildSocialTab(context);
      case _ProfileTab.stats:
        return _buildStatsTab(context, auth, favoriteGenres);
    }
  }

  Widget _buildLibraryTab({
    required BuildContext context,
    required String? userId,
    required List<dynamic> favoriteMovies,
    required List<dynamic> favoritePeople,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (userId != null) ...[
          ListsPreviewSection(
            userId: userId,
            title: 'Your Lists',
            emptyMessage: "You haven't created any lists yet.",
            allowManage: true,
            embedded: true,
          ),
          const SizedBox(height: 16),
        ],
        if (favoriteMovies.isNotEmpty) ...[
          FavoriteMoviesSection(
            favoriteMovies: favoriteMovies.cast(),
          ),
          const SizedBox(height: 16),
        ] else
          _ProfileEmptyAction(
            icon: Icons.favorite_outline_rounded,
            title: 'No favourite movies yet',
            body: 'Favourite a few movies so your profile feels like you.',
            label: 'Find movies',
            onPressed: () => context.push('/search'),
          ),
        if (favoritePeople.isNotEmpty) ...[
          FavoritePeopleSection(favoritePeople: favoritePeople),
          const SizedBox(height: 16),
        ],
        if (_ratingsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          RatingsSection(ratings: _ratings),
          const SizedBox(height: 16),
        ],
        _ProfileActionGrid(
          actions: [
            _ProfileAction(
              icon: Icons.bookmarks_outlined,
              label: 'Lists',
              onTap: () => context.push('/movie-lists'),
            ),
            _ProfileAction(
              icon: Icons.star_outline,
              label: 'Reviews',
              onTap: () => context.push('/my-reviews'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityTab(
    BuildContext context,
    TextTheme textTheme,
    List<ActivityListItem> visibleActivity,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Your activity',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: FlixieColors.light,
              ),
            ),
            const Spacer(),
            if (_activity.isNotEmpty)
              Text(
                '${_activity.length}',
                style: const TextStyle(
                  color: FlixieColors.medium,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_activityLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_activity.isEmpty)
          _ProfileEmptyAction(
            icon: Icons.timeline_rounded,
            title: 'No activity yet',
            body: 'Watch, rate, list, or review something to start your feed.',
            label: 'Find movies',
            onPressed: () => context.push('/search'),
          )
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleActivity.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => ActivityTile(item: visibleActivity[i]),
          ),
          if (_activity.length > _initialActivityCount) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    setState(() => _showAllActivity = !_showAllActivity),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FlixieColors.light,
                  side: const BorderSide(color: FlixieColors.tabBarBorder),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _showAllActivity ? 'Show less' : 'View all activity',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 16),
        _ProfileActionGrid(
          actions: [
            _ProfileAction(
              icon: Icons.history,
              label: 'History',
              onTap: () => context.push('/watch-history'),
            ),
            _ProfileAction(
              icon: Icons.swap_horiz_outlined,
              label: 'Requests',
              onTap: () => context.push('/watch-requests'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FriendsRow(
          data: _friendsData ??
              const FriendsData(
                friendships: [],
                pendingFriends: [],
                requestedFriends: [],
              ),
          isLoading: _friendsLoading,
          onFriendsChanged: (updated) {
            setState(() => _friendsData = updated);
            context.read<AuthProvider>().updateCachedFriends(updated);
          },
        ),
        const SizedBox(height: 16),
        _ProfileActionGrid(
          actions: [
            _ProfileAction(
              icon: Icons.swap_horiz_outlined,
              label: 'Watch requests',
              onTap: () => context.push('/watch-requests'),
            ),
            _ProfileAction(
              icon: Icons.help_outline,
              label: 'Help',
              onTap: () => context.push('/help-support'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsTab(
    BuildContext context,
    AuthProvider auth,
    List<dynamic> favoriteGenres,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (favoriteGenres.isNotEmpty) ...[
          MovieTasteBadge(favoriteGenres: favoriteGenres),
          const SizedBox(height: 16),
        ] else
          _ProfileEmptyAction(
            icon: Icons.auto_awesome_rounded,
            title: 'Build your taste profile',
            body:
                'Pick favourites and rate movies to unlock a clearer taste snapshot.',
            label: 'Find movies',
            onPressed: () => context.push('/search'),
          ),
        if (_ratingsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          RatingsSection(ratings: _ratings),
          const SizedBox(height: 16),
        ],
        _ProfileActionGrid(
          actions: [
            _ProfileAction(
              icon: Icons.auto_graph_outlined,
              label: 'Recap',
              onTap: () => context.push('/stats'),
            ),
            _ProfileAction(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: auth.isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
          label: const Text('Sign Out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: FlixieColors.danger,
            side: const BorderSide(color: FlixieColors.danger),
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: auth.isLoading ? null : () => auth.signOut(),
        ),
      ],
    );
  }

  String _averageRatingLabel(List<MovieRating> ratings) {
    if (ratings.isEmpty) return '--';
    final total = ratings.fold<int>(0, (sum, rating) => sum + rating.rating);
    return (total / ratings.length).toStringAsFixed(1);
  }
}

class _ProfileDashboard extends StatelessWidget {
  const _ProfileDashboard({
    required this.watched,
    required this.watchlist,
    required this.favorites,
    required this.averageRating,
    required this.recentActivity,
    required this.onWatchHistory,
    required this.onWatchlist,
    required this.onFavourites,
    required this.onRecap,
  });

  final int watched;
  final int watchlist;
  final int favorites;
  final String averageRating;
  final int recentActivity;
  final VoidCallback onWatchHistory;
  final VoidCallback onWatchlist;
  final VoidCallback onFavourites;
  final VoidCallback onRecap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlixieColors.tabBarBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.dashboard_customize_outlined,
                color: FlixieColors.primary,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                'Taste snapshot',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: FlixieColors.light,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Recap',
                onPressed: onRecap,
                icon: const Icon(Icons.auto_graph_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.3,
            children: [
              _DashboardMetric(
                icon: Icons.visibility_outlined,
                label: 'Watched',
                value: '$watched',
                onTap: onWatchHistory,
              ),
              _DashboardMetric(
                icon: Icons.bookmark_border_rounded,
                label: 'Watchlist',
                value: '$watchlist',
                onTap: onWatchlist,
              ),
              _DashboardMetric(
                icon: Icons.favorite_border_rounded,
                label: 'Favourites',
                value: '$favorites',
                onTap: onFavourites,
              ),
              _DashboardMetric(
                icon: Icons.star_border_rounded,
                label: 'Avg rating',
                value: averageRating,
              ),
            ],
          ),
          if (recentActivity > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: FlixieColors.tertiary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '$recentActivity recent profile ${recentActivity == 1 ? 'update' : 'updates'}',
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FlixieColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: FlixieColors.primary, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FlixieColors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTabSelector extends StatelessWidget {
  const _ProfileTabSelector({
    required this.selected,
    required this.onSelected,
  });

  final _ProfileTab selected;
  final ValueChanged<_ProfileTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _ProfileTab.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = _ProfileTab.values[index];
          final isSelected = tab == selected;
          return ChoiceChip(
            selected: isSelected,
            avatar: Icon(
              _tabIcon(tab),
              size: 16,
              color: isSelected ? Colors.black : FlixieColors.medium,
            ),
            label: Text(_tabLabel(tab)),
            selectedColor: FlixieColors.primary,
            backgroundColor: FlixieColors.tabBarBackgroundFocused,
            labelStyle: TextStyle(
              color: isSelected ? Colors.black : FlixieColors.light,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            side: BorderSide(
              color: isSelected
                  ? FlixieColors.primary
                  : Colors.white.withValues(alpha: 0.08),
            ),
            onSelected: (_) => onSelected(tab),
          );
        },
      ),
    );
  }

  IconData _tabIcon(_ProfileTab tab) {
    return switch (tab) {
      _ProfileTab.library => Icons.video_library_outlined,
      _ProfileTab.activity => Icons.timeline_rounded,
      _ProfileTab.social => Icons.group_outlined,
      _ProfileTab.stats => Icons.insights_outlined,
    };
  }

  String _tabLabel(_ProfileTab tab) {
    return switch (tab) {
      _ProfileTab.library => 'Library',
      _ProfileTab.activity => 'Activity',
      _ProfileTab.social => 'Social',
      _ProfileTab.stats => 'Stats',
    };
  }
}

class _ProfileEmptyAction extends StatelessWidget {
  const _ProfileEmptyAction({
    required this.icon,
    required this.title,
    required this.body,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlixieColors.tabBarBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FlixieColors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: FlixieColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: FlixieColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: label,
            onPressed: onPressed,
            style: IconButton.styleFrom(
              backgroundColor: FlixieColors.primary,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }
}

class _ProfileAction {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _ProfileActionGrid extends StatelessWidget {
  const _ProfileActionGrid({required this.actions});

  final List<_ProfileAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 3.6,
      children: actions
          .map(
            (action) => Material(
              color: FlixieColors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: action.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(action.icon, color: FlixieColors.primary, size: 19),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          action.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.light,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: FlixieColors.medium,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
