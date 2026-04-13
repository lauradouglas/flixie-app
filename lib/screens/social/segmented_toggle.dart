import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SocialSegmentedToggle extends StatelessWidget {
  const SocialSegmentedToggle({
    super.key,
    required this.selectedIndex,
    required this.labels,
    required this.onChanged,
  });

  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: FlixieColors.tabBarBorder),
        ),
        child: Row(
          children: List.generate(labels.length, (i) {
            final selected = i == selectedIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: selected ? FlixieColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(27),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: selected ? Colors.black : FlixieColors.medium,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
