import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity_list_item.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import 'profile/activity_tile.dart';
import 'profile/profile_header.dart';
import 'profile/profile_stats_row.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().addListener(_onAuthChanged);
      _loadActivity();
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
    if (userId != null && (userId != _loadedForUserId || version != _lastActivityVersion)) {
      _loadActivity();
    }
  }

  Future<void> _loadActivity() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthProvider>();
    final firebaseUser = auth.firebaseUser;
    final dbUser = auth.dbUser;

    // Prefer database user info, fallback to Firebase
    final displayName = dbUser?.username ?? firebaseUser?.displayName ?? 'Guest User';
    final email = dbUser?.email ?? firebaseUser?.email ?? '';
    final bio = dbUser?.bio;
    final photoUrl = firebaseUser?.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar & name
            ProfileHeader(
              displayName: displayName,
              email: email,
              photoUrl: photoUrl,
            ),

            const SizedBox(height: 24),

            // Stats row
            ProfileStatsRow(
              watched: (dbUser?.watchedMovies?.length ?? 0) + (dbUser?.watchedShows?.length ?? 0),
              watchlist: (dbUser?.movieWatchlist?.length ?? 0) + (dbUser?.showWatchlist?.length ?? 0),
              favorites: (dbUser?.favoriteMovies?.length ?? 0) + (dbUser?.favoriteShows?.length ?? 0),
            ),

            const SizedBox(height: 24),

            // Bio section
            if (bio != null && bio.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FlixieColors.tabBarBackgroundFocused,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FlixieColors.medium.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bio',
                      style: textTheme.titleMedium?.copyWith(
                        color: FlixieColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const Divider(),
            const SizedBox(height: 8),

            // Activity section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Activity', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                  style: textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activity.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => ActivityTile(item: _activity[i]),
              ),

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
                onTap: () {},
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
  _MenuItem(icon: Icons.favorite_outline, label: 'Favourites'),
  _MenuItem(icon: Icons.history, label: 'Watch History'),
  _MenuItem(icon: Icons.star_outline, label: 'My Reviews'),
  _MenuItem(icon: Icons.notifications_outlined, label: 'Notifications'),
  _MenuItem(icon: Icons.help_outline, label: 'Help & Support'),
];

