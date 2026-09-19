import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class SocialSegmentedToggle extends StatelessWidget {
  const SocialSegmentedToggle({
    super.key,
    required this.selectedIndex,
    required this.labels,
    required this.onChanged,
    this.counts = const {},
  });

  final Map<int, int> counts;
  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: context.colors.tabBarBorder)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(labels.length, (i) {
            final selected = i == selectedIndex;
            final count = counts[i] ?? 0;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: count > 0
                    ? '${labels[i]}, $count unread messages'
                    : labels[i],
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                          vertical: 13, horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selected
                                ? context.colors.primaryTint
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: ExcludeSemantics(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            Text(
                              labels[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected
                                    ? context.colors.textPrimary
                                    : context.colors.light,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            if (count > 0)
                              Text(
                                count > 99 ? '99+' : '$count',
                                style: TextStyle(
                                  color: context.colors.primaryTint,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
