import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SocialSectionHeader extends StatelessWidget {
  const SocialSectionHeader({
    super.key,
    required this.title,
    this.badge,
    this.rightLabel,
  });

  final String title;
  final int? badge;
  final String? rightLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: FlixieColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: FlixieColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$badge',
              style: const TextStyle(
                  color: FlixieColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
        if (rightLabel != null) ...[
          const Spacer(),
          Text(
            rightLabel!,
            style: textTheme.bodySmall?.copyWith(
              color: FlixieColors.medium,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}
