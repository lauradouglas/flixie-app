import 'package:flutter/material.dart';

import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, required this.group, this.radius = 24});

  final Group group;
  final double radius;

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

  String get _abbr {
    if (group.abbreviation != null && group.abbreviation!.isNotEmpty) {
      return group.abbreviation!.toUpperCase();
    }
    final words = group.name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return group.name.isEmpty
        ? '?'
        : group.name.substring(0, group.name.length.clamp(1, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _color.withValues(alpha: 0.3),
      child: SizedBox(
        width: radius * 1.55,
        height: radius * 1.55,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _abbr,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: _color,
              fontWeight: FontWeight.bold,
              fontSize: radius * (_abbr.length > 3 ? 0.56 : 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
