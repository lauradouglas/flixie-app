import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class FlixieSegment<T> {
  const FlixieSegment({required this.value, required this.child});

  final T value;
  final Widget child;
}

/// The shared Flixie joined selector used for small, mutually-exclusive views.
class FlixieSegmentedControl<T> extends StatelessWidget {
  const FlixieSegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final List<FlixieSegment<T>> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: FlixieColors.primary.withValues(alpha: .42),
        ),
      ),
      child: Row(
        children: segments.map((segment) {
          final selected = segment.value == value;
          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onChanged(segment.value),
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  constraints: const BoxConstraints(minHeight: 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? FlixieColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      color: selected ? Colors.white : FlixieColors.light,
                      fontWeight: FontWeight.w800,
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(
                        color: selected ? Colors.white : FlixieColors.medium,
                        size: 18,
                      ),
                      child: segment.child,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
