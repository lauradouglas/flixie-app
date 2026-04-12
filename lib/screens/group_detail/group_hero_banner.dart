import 'package:flutter/material.dart';

import '../../models/group.dart';
import '../../theme/app_theme.dart';

class GroupHeroBanner extends StatelessWidget {
  const GroupHeroBanner({
    super.key,
    required this.group,
    required this.memberCount,
  });

  final Group group;
  final int memberCount;

  static const List<Color> _palette = [
    FlixieColors.primary,
    FlixieColors.secondary,
    FlixieColors.tertiary,
    FlixieColors.success,
    FlixieColors.warning,
  ];

  Color get _color {
    final hash = group.name.codeUnits.fold(0, (a, b) => a + b);
    return _palette[hash % _palette.length];
  }

  String _formatCount(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: group identity card
          Expanded(
            flex: 3,
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.35),
                    FlixieColors.tabBarBackgroundFocused,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                border: Border.all(color: FlixieColors.tabBarBorder),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: FlixieColors.tertiary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ACTIVE COMMUNITY',
                      style: TextStyle(
                        color: FlixieColors.tertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    group.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // Right: member count card
          Container(
            width: 90,
            height: 110,
            decoration: const BoxDecoration(
              color: FlixieColors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border(
                top: BorderSide(color: FlixieColors.tabBarBorder),
                right: BorderSide(color: FlixieColors.tabBarBorder),
                bottom: BorderSide(color: FlixieColors.tabBarBorder),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatCount(memberCount),
                  style: const TextStyle(
                    color: FlixieColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'MEMBERS',
                  style: TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
