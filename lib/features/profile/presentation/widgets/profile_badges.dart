import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class SpecialAvatarFrame extends StatelessWidget {
  const SpecialAvatarFrame({
    super.key,
    required this.badges,
    required this.child,
    this.frameWidth,
  });

  final List<String> badges;
  final Widget child;

  /// Optional consistent ring width for compact avatar rows.
  final double? frameWidth;

  @override
  Widget build(BuildContext context) {
    if (!badges.contains('FOUNDER') &&
        !badges.contains('OG_USER') &&
        !badges.contains('VERIFIED') &&
        !badges.contains('EARLY_ADOPTER') &&
        !badges.contains('FOUNDING_FILM_FRIEND')) {
      if (frameWidth == null) return child;
      return Container(
        padding: EdgeInsets.all(frameWidth!),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: FlixieColors.primary,
        ),
        child: child,
      );
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
                    ? [FlixieColors.primary, FlixieColors.secondary]
                    : const [Color(0xFF9B83CC), Color(0xFF6D5A96)];
    return Container(
      padding: EdgeInsets.all(frameWidth ?? (isFounder ? 4 : 3)),
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
    'OG_GINGER': (
      label: 'OG Ginger',
      description: 'First ginger on Flixie.',
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
    'PEACH_USER': (
      label: 'Peach',
      description: 'got cheeks',
      icon: Icons.circle,
      color: Color(0xFFFFA07A),
    ),
  };

  @override
  Widget build(BuildContext context) {
    const priority = [
      'FOUNDER',
      'OG_USER',
      'OG_GINGER',
      'VERIFIED',
      'EARLY_ADOPTER',
      'FOUNDING_FILM_FRIEND',
      'STAFF',
      'PARTNER',
      'PEACH_USER',
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
                      badge.id == 'FOUNDING_FILM_FRIEND' ||
                      badge.id == 'PEACH_USER' ||
                      badge.id == 'OG_GINGER'),
            ),
          ]
        : allVisible;
    if (visible.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final badge in visible)
          if (badge.id == 'EARLY_ADOPTER' ||
              badge.id == 'FOUNDING_FILM_FRIEND' ||
              badge.id == 'PEACH_USER')
            Tooltip(
              message: badge.label,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: badge.id == 'PEACH_USER'
                    ? null
                    : () => _showBadgeContext(context, badge),
                child: Container(
                  padding: EdgeInsets.all(compact ? 5 : 6),
                  decoration: BoxDecoration(
                    color: badge.color.withValues(alpha: .13),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: badge.color.withValues(alpha: .45)),
                  ),
                  child: _badgeIcon(
                    badge.icon,
                    badge.color,
                    compact ? 12 : 14,
                    peach: badge.id == 'PEACH_USER',
                  ),
                ),
              ),
            )
          else
            FlixiePill.action(
                label: Text(badge.label),
                avatar: _badgeIcon(badge.icon, badge.color, compact ? 12 : 14,
                    peach: badge.id == 'PEACH_USER'),
                onPressed: () => _showBadgeContext(context, badge)),
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
      backgroundColor: context.colors.surface,
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
                child: _badgeIcon(
                  badge.icon,
                  badge.color,
                  22,
                  peach: badge.id == 'PEACH_USER',
                ),
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
                            color: context.colors.light,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      badge.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.colors.medium,
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

  Widget _badgeIcon(
    IconData icon,
    Color color,
    double size, {
    bool peach = false,
  }) =>
      peach
          ? CustomPaint(
              size: Size.square(size),
              painter: _PeachIconPainter(),
            )
          : Icon(icon, color: color, size: size);
}

class _PeachIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fruit = Paint()..color = const Color(0xFFFFA07A);
    final highlight = Paint()..color = const Color(0xFFFFC1A8);
    final leaf = Paint()..color = const Color(0xFF73D7B4);
    final stem = Paint()
      ..color = const Color(0xFF9B5B42)
      ..strokeWidth = size.width * .1
      ..strokeCap = StrokeCap.round;
    final unit = size.width;

    canvas.drawCircle(Offset(unit * .38, unit * .62), unit * .29, fruit);
    canvas.drawCircle(Offset(unit * .62, unit * .62), unit * .29, fruit);
    canvas.drawCircle(Offset(unit * .5, unit * .38), unit * .23, fruit);
    canvas.drawCircle(Offset(unit * .37, unit * .53), unit * .08, highlight);
    canvas.drawLine(
      Offset(unit * .5, unit * .35),
      Offset(unit * .55, unit * .16),
      stem,
    );
    canvas.save();
    canvas.translate(unit * .55, unit * .2);
    canvas.rotate(-.45);
    canvas.translate(-unit * .55, -unit * .2);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(unit * .67, unit * .2),
        width: unit * .34,
        height: unit * .16,
      ),
      leaf,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PeachIconPainter oldDelegate) => false;
}
