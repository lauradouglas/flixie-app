import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class ReviewCountLabel extends StatelessWidget {
  const ReviewCountLabel({super.key, required this.count, this.style});
  final int? count;
  final TextStyle? style;
  static String format(int count) => count >= 1000 ? '1k+' : '$count';

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 5,
    runSpacing: 3,
    children: [
      Text('Reviews', textAlign: TextAlign.center, style: style),
      if (count != null)
        Semantics(
          label: '$count reviews',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: FlixieColors.primary.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(format(count!), style: TextStyle(
              color: context.colors.primaryText,
              fontSize: 10, fontWeight: FontWeight.w700),
              maxLines: 1),
          ),
        ),
    ],
  );
}
