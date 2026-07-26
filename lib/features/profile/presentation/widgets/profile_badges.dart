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
        !badges.contains('EARLY_ADOPTER') &&
        !badges.contains('FOUNDING_FILM_FRIEND')) {
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
                : badges.contains('FOUNDING_FILM_FRIEND')
                    ? const [FlixieColors.primary, FlixieColors.secondary]
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

  static const _details = <String,
      ({String label, String description, IconData icon, Color color})>{
    'FOUNDER': (
      label: 'Founder',
      description: 'Created Flixie and helped start the community.',
      icon: Icons.bolt_rounded,
      color: Color(0xFFFFB45E),
    ),
    'EARLY_ADOPTER': (
      label: 'First 100',
      description: 'One of the first 100 people to join Flixie.',
      icon: Icons.rocket_launch_rounded,
      color: Color(0xFFB896FF),
    ),
    'FOUNDING_FILM_FRIEND': (
      label: 'Film Friend',
      description:
          'Unlocked by inviting a film friend who completed their taste profile.',
      icon: Icons.people_alt_rounded,
      color: FlixieColors.secondary,
    ),
    'OG_USER': (
      label: 'OG',
      description: 'An original member of the Flixie community.',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFFF8A66),
    ),
    'VERIFIED': (
      label: 'Verified',
      description: 'Flixie has verified this account.',
      icon: Icons.verified_rounded,
      color: Color(0xFF5CC8FF),
    ),
    'STAFF': (
      label: 'Flixie team',
      description: 'A member of the Flixie team.',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFFF7DAD),
    ),
    'PARTNER': (
      label: 'Partner',
      description: 'An official Flixie partner.',
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
      'FOUNDING_FILM_FRIEND',
      'STAFF',
      'PARTNER',
    ];
    final ordered = [
      ...priority.where(badges.contains),
      ...badges.where((badge) => !priority.contains(badge)),
    ];
    final allVisible = ordered
        .map((id) {
          final details = _details[id];
          return details == null
              ? null
              : (
                  id: id,
                  label: details.label,
                  description: details.description,
                  icon: details.icon,
                  color: details.color,
                );
        })
        .whereType<
            ({
              String id,
              String label,
              String description,
              IconData icon,
              Color color,
            })>()
        .toList();
    final visible = featuredOnly && allVisible.isNotEmpty
        ? [
            allVisible.first,
            ...allVisible.where(
              (badge) =>
                  badge.id != allVisible.first.id &&
                  (badge.id == 'EARLY_ADOPTER' ||
                      badge.id == 'FOUNDING_FILM_FRIEND'),
            ),
          ]
        : allVisible;
    if (visible.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final badge in visible)
          if (badge.id == 'EARLY_ADOPTER' || badge.id == 'FOUNDING_FILM_FRIEND')
            Tooltip(
              message: badge.label,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _showBadgeContext(context, badge),
                child: Container(
                  padding: EdgeInsets.all(compact ? 5 : 6),
                  decoration: BoxDecoration(
                    color: badge.color.withValues(alpha: .13),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: badge.color.withValues(alpha: .45)),
                  ),
                  child: Icon(
                    badge.icon,
                    size: compact ? 12 : 14,
                    color: badge.color,
                  ),
                ),
              ),
            )
          else
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => _showBadgeContext(context, badge),
              child: Container(
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
                    Icon(
                      badge.icon,
                      size: compact ? 12 : 14,
                      color: badge.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      badge.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: badge.color,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  void _showBadgeContext(
    BuildContext context,
    ({
      String id,
      String label,
      String description,
      IconData icon,
      Color color,
    }) badge,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlixieColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: .14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: badge.color.withValues(alpha: .45),
                  ),
                ),
                child: Icon(badge.icon, color: badge.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: FlixieColors.light,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      badge.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: FlixieColors.medium,
                            height: 1.4,
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
