import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class GenreBar extends StatelessWidget {
  const GenreBar({
    super.key,
    required this.rank,
    required this.name,
    required this.count,
    required this.maxCount,
  });

  final int rank;
  final String name;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final fraction = maxCount > 0 ? count / maxCount : 0.0;
    final accent = rank == 1
        ? FlixieColors.primary
        : FlixieColors.primary.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              style: const TextStyle(
                  color: FlixieColors.medium,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13)),
                    Text('$count',
                        style: const TextStyle(
                            color: FlixieColors.medium, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: FlixieColors.tabBarBackgroundFocused,
                    valueColor: AlwaysStoppedAnimation(accent),
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
