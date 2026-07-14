import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

String greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    this.name,
    required this.onSearch,
    required this.onWatchlist,
    required this.onInvite,
    required this.onRequests,
  });

  final String? name;
  final VoidCallback onSearch;
  final VoidCallback onWatchlist;
  final VoidCallback onInvite;
  final VoidCallback onRequests;

  @override
  Widget build(BuildContext context) {
    final label = name != null
        ? '${greeting()}, $name \u{1F44B}'
        : '${greeting()} \u{1F44B}';
    final initial = (name != null && name!.trim().isNotEmpty)
        ? name!.trim().substring(0, 1).toUpperCase()
        : 'F';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: FlixieColors.surfaceElevated,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ActionButton(
                icon: Icons.search_rounded,
                label: 'Search',
                onTap: onSearch,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.bookmark_rounded,
                label: 'Watchlist',
                onTap: onWatchlist,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.group_add_rounded,
                label: 'Invite',
                onTap: onInvite,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.local_activity_rounded,
                label: 'Requests',
                onTap: onRequests,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: FlixieColors.surfaceElevated.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: FlixieColors.primary, size: 18),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlixieColors.light,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
