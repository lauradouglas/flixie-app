import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ScoreTile extends StatelessWidget {
  const ScoreTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor = FlixieColors.white,
    this.onInfoTap,
  });

  final String value;
  final String label;
  final Color valueColor;
  final VoidCallback? onInfoTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onInfoTap != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onInfoTap,
                child: const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: FlixieColors.medium,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
