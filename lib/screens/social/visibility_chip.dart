import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class VisibilityChip extends StatelessWidget {
  const VisibilityChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? FlixieColors.primary : FlixieColors.tabBarBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? FlixieColors.primary : FlixieColors.tabBarBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : FlixieColors.medium,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
