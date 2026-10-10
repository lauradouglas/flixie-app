import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class GroupInsightsPeriod extends StatelessWidget {
  const GroupInsightsPeriod(
      {super.key, required this.allTime, required this.onChanged});

  final bool allTime;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.tabBarBorder),
      ),
      child: Row(
        children: [
          _option(context, 'This month', false),
          _option(context, 'All time', true),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, String label, bool value) {
    final selected = allTime == value;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? FlixieColors.primary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: selected
                ? Border.all(
                    color: FlixieColors.primary.withValues(alpha: 0.48),
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? FlixieColors.primary : context.colors.medium,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
