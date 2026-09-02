import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

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
    this.avatar,
    this.profileBadges = const [],
    this.requestCount = 0,
    required this.onSearch,
    required this.onWatchlist,
    required this.onInvite,
    required this.onRequests,
    this.featureCard,
  });

  final String? name;
  final ProfileAvatar? avatar;
  final List<String> profileBadges;
  final int requestCount;
  final VoidCallback onSearch;
  final VoidCallback onWatchlist;
  final VoidCallback onInvite;
  final VoidCallback onRequests;
  final Widget? featureCard;

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
              ProfileAvatarView(
                avatar: avatar,
                fallbackText: initial,
                fallbackColor: FlixieColors.surfaceElevated,
                size: 30,
                profileBadges: profileBadges,
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
          if (featureCard != null) ...[
            const SizedBox(height: 12),
            featureCard!,
          ],
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
                label: 'Invite friends',
                onTap: onInvite,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.local_activity_rounded,
                label: requestCount > 0 ? 'Plans' : 'Make plan',
                onTap: onRequests,
                badgeCount: requestCount,
                supportingLabel:
                    requestCount > 0 ? '$requestCount need(s) you' : null,
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
    this.badgeCount = 0,
    this.supportingLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;
  final String? supportingLabel;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: FlixieColors.surfaceElevated.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 96,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 30,
                      height: 27,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Icon(icon, color: FlixieColors.primary, size: 18),
                          if (badgeCount > 0)
                            Positioned(
                              top: -3,
                              right: -5,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: FlixieColors.tertiary,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  badgeCount > 99 ? '99+' : '$badgeCount',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 11,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 12,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: const TextStyle(
                            color: FlixieColors.light,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 9,
                      child: supportingLabel == null
                          ? null
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                supportingLabel!,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: FlixieColors.medium,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  height: 1,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
