import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class FlixieSectionHeader extends StatelessWidget {
  const FlixieSectionHeader({
    super.key,
    required this.title,
    this.padding = EdgeInsets.zero,
    this.uppercase = true,
    this.titleStyle,
    this.badge,
    this.trailingLabel,
    this.trailingColor,
    this.onTrailingTap,
    this.accentHeight = 22,
  });

  final String title;
  final EdgeInsetsGeometry padding;
  final bool uppercase;
  final TextStyle? titleStyle;
  final int? badge;
  final String? trailingLabel;
  final Color? trailingColor;
  final VoidCallback? onTrailingTap;
  final double accentHeight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trailingText = trailingLabel;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 4,
            height: accentHeight,
            decoration: BoxDecoration(
              color: FlixieColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              uppercase ? title.toUpperCase() : title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: titleStyle ??
                  textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
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
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          if (trailingText != null) ...[
            const Spacer(),
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(
                trailingText,
                style: textTheme.bodySmall?.copyWith(
                  color: trailingColor ?? FlixieColors.medium,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
