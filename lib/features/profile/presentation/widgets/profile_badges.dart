import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class SpecialAvatarFrame extends StatelessWidget {
  const SpecialAvatarFrame({
    super.key,
    required this.badges,
    required this.child,
  });

  final List<String> badges;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!badges.contains('FOUNDER') &&
        !badges.contains('OG_USER') &&
        !badges.contains('VERIFIED') &&
        !badges.contains('EARLY_ADOPTER')) {
      return child;
    }

    final isFounder = badges.contains('FOUNDER');
    final isOgUser = badges.contains('OG_USER');
    final isVerified = badges.contains('VERIFIED');
    final colors = isFounder
        ? const [Color(0xFFFFB45E), FlixieColors.primary, Color(0xFFFFD979)]
        : isOgUser
            ? const [Color(0xFFFF8A66), Color(0xFFD561A8)]
            : isVerified
                ? const [Color(0xFF5CC8FF), FlixieColors.primary]
                : const [Color(0xFF9B83CC), Color(0xFF6D5A96)];
    return Container(
      padding: EdgeInsets.all(isFounder ? 3 : 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [...colors, colors.first]),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: isFounder ? .28 : .12),
            blurRadius: isFounder ? 12 : 5,
          ),
        ],
      ),
      child: child,
    );
  }
}

class ProfileBadgePills extends StatelessWidget {
  const ProfileBadgePills({
    super.key,
    required this.badges,
    this.compact = false,
    this.featuredOnly = false,
  });

  final List<String> badges;
  final bool compact;
  final bool featuredOnly;

  static const _details =
      <String, ({String label, IconData icon, Color color})>{
    'FOUNDER': (
      label: 'Founder',
      icon: Icons.bolt_rounded,
      color: Color(0xFFFFB45E),
    ),
    'EARLY_ADOPTER': (
      label: 'First 100',
      icon: Icons.rocket_launch_rounded,
      color: Color(0xFFB896FF),
    ),
    'OG_USER': (
      label: 'OG',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFFF8A66),
    ),
    'VERIFIED': (
      label: 'Verified',
      icon: Icons.verified_rounded,
      color: Color(0xFF5CC8FF),
    ),
    'STAFF': (
      label: 'Flixie team',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFFF7DAD),
    ),
    'PARTNER': (
      label: 'Partner',
      icon: Icons.handshake_rounded,
      color: Color(0xFF73D7B4),
    ),
  };

  @override
  Widget build(BuildContext context) {
    const priority = [
      'FOUNDER',
      'OG_USER',
      'VERIFIED',
      'EARLY_ADOPTER',
      'STAFF',
      'PARTNER',
    ];
    final ordered = [
      ...priority.where(badges.contains),
      ...badges.where((badge) => !priority.contains(badge)),
    ];
    final visible = ordered
        .map((badge) => _details[badge])
        .whereType<({String label, IconData icon, Color color})>()
        .take(featuredOnly ? 1 : badges.length);
    if (visible.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final badge in visible)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 4 : 5,
            ),
            decoration: BoxDecoration(
              color: badge.color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: badge.color.withValues(alpha: .45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badge.icon, size: compact ? 12 : 14, color: badge.color),
                const SizedBox(width: 4),
                Text(
                  badge.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: badge.color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
