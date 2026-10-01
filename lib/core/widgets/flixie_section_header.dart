import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/app/theme/flixie_typography.dart';

/// Section headings share one visual role. Page and sheet titles are separate.
class FlixieSectionHeader extends StatelessWidget {
  const FlixieSectionHeader({
    super.key,
    required this.title,
    this.padding = EdgeInsets.zero,
    this.badge,
    this.trailingLabel,
    this.onTrailingTap,
  });

  final String title;
  final EdgeInsetsGeometry padding;
  final int? badge;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final heading = Semantics(
      header: true,
      child: Text(title,
          style: FlixieTypography.sectionTitle.copyWith(
            color: context.colors.textPrimary,
          )),
    );
    // Plain headings also appear as non-flex children of another Row (for
    // example, movie details). Let the text size itself in that unbounded width.
    if (badge == null && trailingLabel == null) {
      return Padding(padding: padding, child: heading);
    }
    final label = trailingLabel;
    final action = label == null
        ? null
        : onTrailingTap == null
            ? Text(label, style: Theme.of(context).textTheme.bodySmall)
            : TextButton(
                onPressed: onTrailingTap,
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.primaryText,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: FlixieTypography.supporting,
                ),
                child: Text(label),
              );
    final titleRow = Row(children: [
      Expanded(child: heading),
      if (badge != null) ...[
        const SizedBox(width: 8),
        Text('$badge', style: Theme.of(context).textTheme.bodySmall),
      ],
    ]);
    return Padding(
      padding: padding,
      child: LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(20) > 28;
        if (action == null) return titleRow;
        if (stacked) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleRow,
                Align(alignment: AlignmentDirectional.centerEnd, child: action),
              ]);
        }
        return Row(children: [
          Expanded(child: titleRow),
          const SizedBox(width: 12),
          Flexible(
              child: Align(
                  alignment: AlignmentDirectional.centerEnd, child: action)),
        ]);
      }),
    );
  }
}
