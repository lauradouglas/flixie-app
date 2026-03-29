import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/activity_list_item.dart';
import '../models/friendship.dart';
import '../models/movie_rating.dart';
import '../providers/auth_provider.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import 'profile/activity_tile.dart';
import 'profile/favorite_movies_section.dart';
import 'profile/favorite_people_section.dart';
import 'profile/friends_row.dart';
import 'profile/profile_header.dart';
import 'profile/profile_stats_row.dart';
import 'profile/ratings_section.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().addListener(_onAuthChanged);
      _loadAll();
    });
  }

  @override
  void dispose() {
    context.read<AuthProvider>().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    final version = auth.activityVersion;
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
      final activity = await UserService.getUserActivity(userId);
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
      final data = await FriendService.getFriends(userId);
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
      logger.d('[ProfileScreen] Calling UserService.getUserMovieRatings...');
      final ratings = await UserService.getUserMovieRatings(userId);
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
    final displayName =
        dbUser?.username ?? firebaseUser?.displayName ?? 'Guest User';
    final email = dbUser?.email ?? firebaseUser?.email ?? '';
    final bio = dbUser?.bio;
    final photoUrl = firebaseUser?.photoURL;

    final favoriteMovies = dbUser?.favoriteMovies ?? [];
    final favoritePeople = dbUser?.favoritePeople ?? [];

    final visibleActivity = _showAllActivity
        ? _activity
        : _activity.take(_initialActivityCount).toList();

    return Scaffold(
      appBar: AppBar(
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
              await context.push('/notifications');
              if (mounted) {
                context.read<AuthProvider>().refreshNotificationCount();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar, name, bio & edit
            ProfileHeader(
              displayName: displayName,
              email: email,
              photoUrl: photoUrl,
              bio: bio,
            ),

            const SizedBox(height: 24),

            // Stats row
            ProfileStatsRow(
              watched: (dbUser?.watchedMovies?.length ?? 0) +
                  (dbUser?.watchedShows?.length ?? 0),
              watchlist: (dbUser?.movieWatchlist?.length ?? 0) +
                  (dbUser?.showWatchlist?.length ?? 0),
              favorites: (dbUser?.favoriteMovies?.length ?? 0) +
                  (dbUser?.favoriteShows?.length ?? 0),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Friends row
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

            const SizedBox(height: 24),

            // Favorite Movies
            if (favoriteMovies.isNotEmpty) ...[
              FavoriteMoviesSection(favoriteMovies: favoriteMovies),
              const SizedBox(height: 16),
            ],

            // Favorite People
            if (favoritePeople.isNotEmpty) ...[
              FavoritePeopleSection(favoritePeople: favoritePeople),
              const SizedBox(height: 16),
            ],

            // Ratings (always show for debugging)
            if (_ratingsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              RatingsSection(ratings: _ratings),
              const SizedBox(height: 16),
            ],

            const Divider(),
            const SizedBox(height: 8),

            // Activity section header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: FlixieColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'RECENT ACTIVITY',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            if (_activityLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_activity.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No activity yet.',
                  style:
                      textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
                ),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _showAllActivity ? 'SHOW LESS' : 'LOAD OLDER ACTIVITY',
                      style: const TextStyle(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Menu items
            ..._menuItems.map(
              (item) => ListTile(
                leading: Icon(item.icon, color: FlixieColors.primary),
                title: Text(item.label, style: textTheme.bodyLarge),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: FlixieColors.medium,
                ),
                onTap: () {
                  if (item.label == 'My Reviews') {
                    context.push('/my-reviews');
                  }
                },
              ),
            ),

            const SizedBox(height: 16),

            // Sign out button
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

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

const List<_MenuItem> _menuItems = [
  _MenuItem(icon: Icons.history, label: 'Watch History'),
  _MenuItem(icon: Icons.star_outline, label: 'My Reviews'),
  _MenuItem(icon: Icons.help_outline, label: 'Help & Support'),
  _MenuItem(icon: Icons.settings_outlined, label: 'Settings'),
];
