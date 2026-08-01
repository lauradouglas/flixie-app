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
    this.maxTitleLines = 2,
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
  final int maxTitleLines;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trailingText = trailingLabel;
    final titleWidget = Text(
      uppercase ? title.toUpperCase() : title,
      maxLines: maxTitleLines,
      overflow: TextOverflow.ellipsis,
      style: titleStyle ??
          textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
    );

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
          if (trailingText != null)
            Expanded(child: titleWidget)
          else
            Flexible(child: titleWidget),
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
            const SizedBox(width: 12),
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
