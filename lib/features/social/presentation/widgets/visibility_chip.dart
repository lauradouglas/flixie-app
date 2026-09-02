import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label${selected ? ', selected' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? FlixieColors.primary
                    : FlixieColors.tabBarBackground,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected
                      ? FlixieColors.primary
                      : FlixieColors.tabBarBorder,
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
          ),
        ),
      ),
    );
  }
}
