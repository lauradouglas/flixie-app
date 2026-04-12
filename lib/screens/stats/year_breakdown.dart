import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'stats_entry.dart';

class YearBreakdown extends StatelessWidget {
  const YearBreakdown({super.key, required this.entries, required this.years});
  final List<StatsEntry> entries;
  final List<int> years;

  @override
  Widget build(BuildContext context) {
    final maxCount = years.fold<int>(0, (m, y) {
      final c = entries.where((e) => e.watchedAt?.year == y).length;
      return c > m ? c : m;
    });

    return Column(
      children: years.map((y) {
        final count = entries.where((e) => e.watchedAt?.year == y).length;
        final fraction = maxCount > 0 ? count / maxCount : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text('$y',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 8,
                    backgroundColor: FlixieColors.tabBarBackgroundFocused,
                    valueColor: AlwaysStoppedAnimation(
                        FlixieColors.primary.withValues(alpha: 0.7)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$count',
                  style: const TextStyle(
                      color: FlixieColors.medium, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
