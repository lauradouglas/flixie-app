import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Shared movie/show provider label with the app's warm count badge.
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
                        ? FlixieColors.primaryText
                        : FlixieColors.light,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: count > 0
                      ? FlixieColors.tertiary
                      : FlixieColors.tabBarBorder,
                  shape: BoxShape.circle),
              child: Text('$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: count > 0 ? Colors.black : FlixieColors.light,
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}
