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
    this.showShortcuts = true,
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
  final bool showShortcuts;

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
                fallbackColor: context.colors.surfaceElevated,
                size: 30,
                profileBadges: profileBadges,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: context.colors.white,
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
          if (showShortcuts)
            LayoutBuilder(builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(12) > 15;
              final columns = constraints.maxWidth < 360 || largeText ? 2 : 4;
              final width =
                  (constraints.maxWidth - 8 * (columns - 1)) / columns;
              final actions = [
                _ActionButton(
                    icon: Icons.search_rounded,
                    label: 'Search',
                    onTap: onSearch),
                _ActionButton(
                    icon: Icons.bookmark_rounded,
                    label: 'Watchlist',
                    onTap: onWatchlist),
                _ActionButton(
                    icon: Icons.group_add_rounded,
                    label: 'Invite friends',
                    onTap: onInvite),
                _ActionButton(
                    icon: Icons.local_activity_rounded,
                    label: 'Plans',
                    onTap: onRequests,
                    badgeCount: requestCount),
              ];
              // Reserve the tallest wrapped label for every shortcut.
              // Text scaling remains enabled; none of the labels are clipped.
              var height = 64.0;
              for (final action in actions) {
                final painter = TextPainter(
                  text: TextSpan(
                      text: action.label,
                      style: DefaultTextStyle.of(context).style.merge(
                          const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700))),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: width - 12);
                final measured = 46 + painter.height;
                if (measured > height) height = measured;
                painter.dispose();
              }
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final action in actions)
                  SizedBox(
                      width: width,
                      height: height.ceilToDouble(),
                      child: action)
              ]);
            }),
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: badgeCount > 0
          ? '$label, $badgeCount plans need your attention'
          : label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Badge(
                  isLabelVisible: badgeCount > 0,
                  label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
                  backgroundColor: FlixieColors.notificationBadge,
                  textColor: FlixieColors.onNotificationBadge,
                  child: Icon(icon, color: FlixieColors.primary, size: 20),
                ),
                const SizedBox(height: 6),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: context.colors.light,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
