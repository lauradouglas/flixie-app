import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class GenreChip extends StatelessWidget {
  const GenreChip({
    super.key,
    required this.label,
    this.color,
    this.compact = false,
  });

  final String label;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? FlixieColors.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        border: Border.all(color: chipColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: chipColor,
          fontSize: compact ? 9 : 11,
          fontWeight: FontWeight.w600,
          letterSpacing: compact ? 0.3 : 0.5,
        ),
      ),
    );
  }
}
