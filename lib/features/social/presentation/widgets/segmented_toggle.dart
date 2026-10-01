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
    if (labels.length > 4) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
            children: List.generate(
                labels.length,
                (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Semantics(
                          selected: selectedIndex == i,
                          child: TextButton(
                            style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                foregroundColor: selectedIndex == i
                                    ? context.colors.white
                                    : context.colors.medium,
                                backgroundColor: selectedIndex == i
                                    ? context.colors.surface
                                    : Colors.transparent),
                            onPressed: () => onChanged(i),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(labels[i]),
                              if ((counts[i] ?? 0) > 0) ...[
                                const SizedBox(width: 6),
                                Badge(label: Text('${counts[i]}'))
                              ],
                            ]),
                          )),
                    ))),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: context.colors.tabBarBorder)),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final widths = List.generate(labels.length, (i) {
            final painter = TextPainter(
              text: TextSpan(
                  text: labels[i],
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final width = painter.width +
                24 +
                ((counts[i] ?? 0) > 0
                    ? 48 * MediaQuery.textScalerOf(context).scale(1)
                    : 0);
            painter.dispose();
            return width < 48 ? 48.0 : width;
          });
          final total = widths.fold<double>(0, (sum, width) => sum + width);
          final extra = labels.isNotEmpty && constraints.maxWidth > total
              ? (constraints.maxWidth - total) / labels.length
              : 0.0;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(labels.length, (i) {
                final selected = i == selectedIndex;
                final count = counts[i] ?? 0;
                return SizedBox(
                  width: widths[i] + extra,
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
                                  maxLines: 1,
                                  softWrap: false,
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
                                  Badge(
                                    label: Text(count > 99 ? '99+' : '$count'),
                                    backgroundColor: FlixieColors.primaryShade,
                                    textColor: Colors.white,
                                    textStyle: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700),
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
          );
        }),
      ),
    );
  }
}
