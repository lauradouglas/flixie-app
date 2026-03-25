import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 48,
              backgroundColor: FlixieColors.primary.withValues(alpha: 0.3),
              backgroundImage:
                  photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? const Icon(
                      Icons.person,
                      size: 48,
                      color: FlixieColors.primary,
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(displayName, style: textTheme.headlineMedium),
            if (email.isNotEmpty)
              Text(email, style: textTheme.bodySmall),

            const SizedBox(height: 24),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(
                  value: '${(dbUser?.watchedMovies?.length ?? 0) + (dbUser?.watchedShows?.length ?? 0)}',
                  label: 'Watched',
                ),
                _StatItem(
                  value: '${(dbUser?.movieWatchlist?.length ?? 0) + (dbUser?.showWatchlist?.length ?? 0)}',
                  label: 'Watchlist',
                ),
                _StatItem(
                  value: '${(dbUser?.favoriteMovies?.length ?? 0) + (dbUser?.favoriteShows?.length ?? 0)}',
                  label: 'Favorites',
                ),
              ],
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

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: FlixieColors.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
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
