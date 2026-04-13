import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

const List<String> _kMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({
    super.key,
    required this.buckets,
    required this.maxValue,
    required this.mostActiveIndex,
  });

  final List<int> buckets;
  final int maxValue;
  final int mostActiveIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(12, (i) {
          final count = buckets[i];
          final isActive = i == mostActiveIndex;
          final fraction = maxValue > 0 ? count / maxValue : 0.0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (count > 0)
                    Text(
                      '$count',
                      style: TextStyle(
                        color: isActive
                            ? FlixieColors.primary
                            : FlixieColors.medium,
                        fontSize: 9,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    height: 80 * fraction,
                    decoration: BoxDecoration(
                      color: isActive
                          ? FlixieColors.primary
                          : FlixieColors.primary.withValues(alpha: 0.35),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _kMonthNames[i],
                    style: TextStyle(
                      color: isActive ? Colors.white : FlixieColors.medium,
                      fontSize: 9,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
