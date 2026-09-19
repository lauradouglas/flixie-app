import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Shared movie/show provider label with a quiet inline count.
class ProviderTabLabel extends StatelessWidget {
  const ProviderTabLabel(
      {super.key,
      required this.label,
      required this.count,
      required this.selected});
  final String label;
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label, $count options',
        excludeSemantics: true,
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(label,
                style: TextStyle(
                    color: selected
                        ? context.colors.primaryText
                        : context.colors.light,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            Text('$count',
                style: TextStyle(
                    color: selected
                        ? context.colors.primaryText
                        : context.colors.medium,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
}
